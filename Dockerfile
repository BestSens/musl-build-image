FROM docker.bestsens.de/bone/docker-build-image:2.0.3

RUN apt-get update -y && apt-get install -y --no-install-recommends --no-install-suggests \
	automake \
	texinfo \
	help2man \
	gawk \
	bison \
	flex \
	file \
	libtool-bin
RUN rm -Rf /var/lib/apt/lists/*

RUN mkdir -p /root/Temp

RUN wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz -P /root/Temp && \
	tar xzf /root/Temp/autoconf-2.71.tar.gz -C /root/Temp && \
	cd /root/Temp/autoconf-2.71 && \
	./configure && \
	make && \
	make install

RUN cd /root/Temp && git clone -n https://github.com/crosstool-ng/crosstool-ng.git && \
	cd crosstool-ng && git checkout 66ac9e649a5dcbb4ea9969e071c71db2e9fa2165 && \
	./bootstrap && \
	./configure && \
	make && \
	make install

RUN mkdir -p /root/Temp/ct-ng
COPY ct-ng.config /root/Temp/ct-ng/.config
RUN cd /root/Temp/ct-ng && ct-ng build

ENV PATH=${PATH}:/opt/x-tools/arm-unknown-linux-musleabihf/bin

ARG OPENSSL_VERSION=3.0.7
SHELL ["/bin/bash", "-c"]
RUN wget https://github.com/openssl/openssl/archive/refs/tags/openssl-${OPENSSL_VERSION}.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/openssl-${OPENSSL_VERSION}.tar.gz -C /root/Temp && \
	cd /root/Temp/openssl-openssl-${OPENSSL_VERSION} && \
	CC=gcc perl ./Configure linux-armv4 \
		--cross-compile-prefix=arm-unknown-linux-musleabihf- \
		--prefix=/opt/x-tools/arm-unknown-linux-musleabihf/arm-unknown-linux-musleabihf/opt \
		no-shared && \
	make -j 12 && \
	make install
	
RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.81.0/source/boost_1_81_0.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/boost_1_81_0.tar.gz -C /root/Temp && \
	cd /root/Temp/boost_1_81_0 && \
	./bootstrap.sh && \
	sed -i 's/using gcc/using gcc : arm : arm-unknown-linux-musleabihf-g++/g' project-config.jam && \
	./b2 install toolset=gcc-arm --without-python \
		--prefix=/opt/x-tools/arm-unknown-linux-musleabihf/arm-unknown-linux-musleabihf

RUN rm -Rf /root/Temp