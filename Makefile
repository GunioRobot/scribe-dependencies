.PHONY: force

PKGS = libevent boost lzo thrift fb303

all: $(PKGS)

with-hdfs: all hadoop

libevent:
	[ -f /usr/include/event.h ] || (cd libevent-1.4.11-stable && ./configure && make && cd ..)

boost:
	cd boost_1_41_0 && ./bootstrap.sh && ./bjam -j4 filesystem

lzo:
	cd lzo-2.03 && ./configure && make

thrift: boost
	cd thrift-0.2.0-rc0 && BOOST_ROOT=$(shell pwd)/boost_1_41_0 ./configure && make

fb303: thrift
	cd thrift-0.2.0-rc0/contrib/fb303 && BOOST_ROOT=$(shell pwd)/boost_1_41_0 CPPFLAGS=-I$(shell pwd)/thrift-0.2.0-rc0/contrib/fb303/../../lib/cpp/src ./bootstrap.sh --with-thriftpath=$(shell pwd)/thrift-0.2.0-rc0/compiler/cpp && find . -name Makefile | xargs perl -pi -e 's/\$\(thrift_home\)\/bin/\$\(thrift_home\)/' && make

hadoop:
	cd hadoop-0.20.1+152/src/c++/libhdfs && sh configure --with-java=$(shell dirname $(shell which java)) && make

clean: