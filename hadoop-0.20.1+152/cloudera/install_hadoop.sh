#!/bin/sh -x
# Copyright 2009 Cloudera, inc.

set -e

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --cloudera-source-dir=DIR   path to cloudera distribution files
     --build-dir=DIR             path to hive/build/dist
     --prefix=PREFIX             path to install into

  Optional options:
     --native-build-string       eg Linux-amd-64 (optional - no native installed if not set)
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'cloudera-source-dir:' \
  -l 'prefix:' \
  -l 'build-dir:' \
  -l 'native-build-string:' \
  -l 'installed-lib-dir:' \
  -l 'lib-dir:' \
  -l 'src-dir:' \
  -l 'etc-dir:' \
  -l 'doc-dir:' \
  -l 'man-dir:' \
  -l 'example-dir:' \
  -l 'apache-branch:' \
  -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --cloudera-source-dir)
        CLOUDERA_SOURCE_DIR=$2 ; shift 2
        ;;
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --native-build-string)
        NATIVE_BUILD_STRING=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --etc-dir)
        ETC_DIR=$2 ; shift 2
        ;;
        --installed-lib-dir)
        INSTALLED_LIB_DIR=$2 ; shift 2
        ;;
        --man-dir)
        MAN_DIR=$2 ; shift 2
        ;;
        --example-dir)
        EXAMPLE_DIR=$2 ; shift 2
        ;;
        --apache-branch)
        APACHE_BRANCH=$2 ; shift 2
        ;;
        --src-dir)
        SRC_DIR=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in CLOUDERA_SOURCE_DIR PREFIX BUILD_DIR APACHE_BRANCH; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

LIB_DIR=${LIB_DIR:-$PREFIX/usr/lib/hadoop-$APACHE_BRANCH}
BIN_DIR=${BIN_DIR:-$PREFIX/usr/bin}
DOC_DIR=${DOC_DIR:-$PREFIX/usr/share/doc/hadoop-$APACHE_BRANCH}
MAN_DIR=${MAN_DIR:-$PREFIX/usr/man}
EXAMPLE_DIR=${EXAMPLE_DIR:-$DOC_DIR/examples}
SRC_DIR=${SRC_DIR:-$PREFIX/usr/src/hadoop-$APACHE_BRANCH}
ETC_DIR=${ETC_DIR:-$PREFIX/etc/hadoop-$APACHE_BRANCH}

INSTALLED_LIB_DIR=${INSTALLED_LIB_DIR:-/usr/lib/hadoop-$APACHE_BRANCH}

# TODO(todd) right now we're using bin-package, so we don't copy
# src/ into the dist. otherwise this would be BUILD_DIR/src
HADOOP_SRC_DIR=$BUILD_DIR/../../src

mkdir -p $LIB_DIR
(cd ${BUILD_DIR} && tar cf - .) | (cd $LIB_DIR && tar xf - )
# Take out things we've installed elsewhere

for x in docs lib/native c++ src conf ; do
  rm -rf $LIB_DIR/$x
done

# Make bin wrappers
mkdir -p $BIN_DIR

for bin_wrapper in hadoop sqoop ; do
  wrapper=$BIN_DIR/$bin_wrapper-$APACHE_BRANCH
  cat > $wrapper <<EOF
#!/bin/sh

export HADOOP_HOME=$INSTALLED_LIB_DIR
exec $INSTALLED_LIB_DIR/bin/$bin_wrapper "\$@"
EOF
  chmod 755 $wrapper
done

# Fix some bad permissions in HOD
chmod 755 $LIB_DIR/contrib/hod/support/checklimits.sh
chmod 644 $LIB_DIR/contrib/hod/bin/VERSION

# Link examples to /usr/share
mkdir -p $EXAMPLE_DIR
for x in $LIB_DIR/*examples*jar ; do
  INSTALL_LOC=`echo $x | sed -e "s,$LIB_DIR,$INSTALLED_LIB_DIR,"`
  ln -sf $INSTALL_LOC $EXAMPLE_DIR/
done
# And copy the source
mkdir -p $EXAMPLE_DIR/src
cp -a $HADOOP_SRC_DIR/examples/* $EXAMPLE_DIR/src

# Install docs
mkdir -p $DOC_DIR
cp -r ${BUILD_DIR}/../../docs/* $DOC_DIR

# Install source
mkdir -p $SRC_DIR
cp -a ${HADOOP_SRC_DIR}/* $SRC_DIR/

# Make the empty config
install -d -m 0755 $ETC_DIR/conf.empty
(cd ${BUILD_DIR}/conf && tar cf - .) | (cd $ETC_DIR/conf.empty && tar xf -)

# Link the HADOOP_HOME conf dir and log dir to installed locations
rm -rf $LIB_DIR/conf
ln -s ${ETC_DIR#$PREFIX}/conf $LIB_DIR/conf
rm -rf $LIB_DIR/logs
ln -s /var/log/hadoop-$APACHE_BRANCH $LIB_DIR/logs


# Make the pseudo-distributed config
for conf in conf.pseudo ; do
  install -d -m 0755 $ETC_DIR/$conf
  # Install the default configurations
  (cd ${BUILD_DIR}/conf && tar -cf - .) | (cd $ETC_DIR/$conf && tar -xf -)
  # Overlay the -site files
  (cd ${BUILD_DIR}/../../example-confs/$conf && tar -cf - .) | (cd $ETC_DIR/$conf && tar -xf -)
done

# man pages
mkdir -p $MAN_DIR/man1
cp ${CLOUDERA_SOURCE_DIR}/hadoop-$APACHE_BRANCH.1.gz $MAN_DIR/man1/
cp ${BUILD_DIR}/../../docs/sqoop/sqoop.1.gz $MAN_DIR/man1/sqoop-$APACHE_BRANCH.1.gz

############################################################
# ARCH DEPENDENT STUFF
############################################################

if [ ! -z "$NATIVE_BUILD_STRING" ]; then
  # Native compression libs
  mkdir -p $LIB_DIR/lib/native/
  cp -r ${BUILD_DIR}/lib/native/${NATIVE_BUILD_STRING} $LIB_DIR/lib/native/

  # Pipes
  mkdir -p $PREFIX/usr/lib $PREFIX/usr/include
  cp ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/lib/libhadooppipes.a \
      ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/lib/libhadooputils.a \
      $PREFIX/usr/lib
  cp -r ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/include/hadoop $PREFIX/usr/include/

  # libhdfs
  cp ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/lib/libhdfs.so.0.0.0 $PREFIX/usr/lib
  ln -sf libhdfs.so.0.0.0 $PREFIX/usr/lib/libhdfs.so.0

  # libhdfs-dev - hadoop doesn't realy install these things in nice places :(
  mkdir -p $PREFIX/usr/share/doc/libhdfs0-dev/examples

  cp ${HADOOP_SRC_DIR}/c++/libhdfs/hdfs.h $PREFIX/usr/include/
  cp ${HADOOP_SRC_DIR}/c++/libhdfs/hdfs_*.c $PREFIX/usr/share/doc/libhdfs0-dev/examples

  #    This is somewhat unintuitive, but the -dev package has this symlink (see Debian Library Packaging Guide)
  ln -sf libhdfs.so.0.0.0 $PREFIX/usr/lib/libhdfs.so
  sed -e "s|^libdir='.*'|libdir='/usr/lib'|" \
      ${BUILD_DIR}/c++/${NATIVE_BUILD_STRING}/lib/libhdfs.la > $PREFIX/usr/lib/libhdfs.la
fi
