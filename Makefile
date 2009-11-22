.PHONY: force

PKGS = libevent boost lzo thrift hadoop

all: $(PKGS)

libevent:
	cd libevent-1.4.11-stable && ./configure && make && cd ..

boost:
	cd boost_1_41_0 && ./bootstrap.sh && ./bjam

lzo:
	cd lzo-2.03 && ./configure && make

thrift:
	cd thrift && /bootstrap.sh && ./configure --with-foo && make

hadoop:
	cd hadoop-0.20.1+152/src/c++/libhdfs && sh configure && make

clean: