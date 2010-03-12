.PHONY: force

PREFIX=$(HOME)/.installs
PKGS = libevent boost lzo thrift fb303

all: $(PKGS)

with-hdfs: all hadoop

libevent:
	cd libevent-1.4.11-stable && ./configure --prefix=$(PREFIX) && make && make install && cd ..

boost:
	cd boost_1_41_0 && ./bootstrap.sh --prefix=$(PREFIX) --without-libraries=python && ./bjam -sNO_BZIP2=1 -j4 install && cd ..

lzo:
	cd lzo-2.03 && ./configure --enable-shared --prefix=$(PREFIX) && make && make install && cd ..

thrift: boost libevent
	cd thrift-0.2.0 && JAVA_PREFIX=$(PREFIX) ./configure --prefix=$(PREFIX) --with-boost=$(PREFIX) --without-ruby --without-perl --without-py --with-libevent=$(PREFIX) && JAVA_PREFIX=$(PREFIX) make && make install && cd ..

fb303: thrift
	cd thrift-0.2.0/contrib/fb303 && ./bootstrap.sh ;  PY_PREFIX=$(PREFIX) ./configure --prefix=$(PREFIX) --with-boost=$(PREFIX) --with-thriftpath=$(PREFIX) && PY_PREFIX=$(PREFIX) make && PY_PREFIX=$(PREFIX) make install && cd ..

hadoop:
	cd hadoop-0.20.1+152/src/c++/libhdfs && JVM_ARCH=64 ac_cv_func_malloc_0_nonnull=yes sh configure --prefix=$(PREFIX) --with-java=$(shell dirname $(shell readlink -f $(shell which java)))/.. && make && make install && cd ..

clean:
