FROM debian:11
RUN apt-get update -y && apt-get install -y --no-install-recommends --no-install-suggests \
	wget \
	build-essential \
	python3 \
	python3-jinja2 \
	curl \
	automake \
	texinfo \
	help2man \
	gawk \
	bison \
	flex \
	file \
	libtool-bin \
	gperf \
	git \
	libreadline8 \
	libreadline-dev \
	make \
	ninja-build \
	autopoint \
	meson \
	ccache \
	pkg-config \
	ca-certificates \
	cmake \
	libssl-dev \
	unzip
RUN rm -Rf /var/lib/apt/lists/*

RUN mkdir -p /root/Temp

RUN wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz -P /root/Temp && \
	tar xzf /root/Temp/autoconf-2.71.tar.gz -C /root/Temp && \
	cd /root/Temp/autoconf-2.71 && \
	./configure && \
	make && \
	make install

RUN cd /root/Temp && git clone -n https://github.com/crosstool-ng/crosstool-ng.git && \
	cd crosstool-ng && git checkout 190b8392da5f0e51d3a116d14bf3391231c93798 && \
	./bootstrap && \
	./configure && \
	make && \
	make install

RUN mkdir -p /root/Temp/ct-ng
COPY ct-ng.config /root/Temp/ct-ng/.config
RUN cd /root/Temp/ct-ng && ct-ng build

ENV PATH=${PATH}:/opt/x-tools/arm-bemos-linux-musleabihf/bin

ARG TOOLCHAIN_PREFIX=/opt/x-tools/arm-bemos-linux-musleabihf/arm-bemos-linux-musleabihf

ENV PKG_CONFIG_LIBDIR=${TOOLCHAIN_PREFIX}/lib

ARG LIBCAP_VERSION=2.66
RUN wget https://mirrors.edge.kernel.org/debian/pool/main/libc/libcap2/libcap2_${LIBCAP_VERSION}.orig.tar.xz -P /root/Temp && \
	tar xf /root/Temp/libcap2_${LIBCAP_VERSION}.orig.tar.xz -C /root/Temp && \
	cd /root/Temp/libcap-${LIBCAP_VERSION} && \
	make prefix=${TOOLCHAIN_PREFIX} \
		BUILD_CC=gcc \
		CC=arm-bemos-linux-musleabihf-gcc \
		AR=arm-bemos-linux-musleabihf-ar \
		RANLIB=arm-bemos-linux-musleabihf-ranlib \
		OBJCOPY=arm-bemos-linux-musleabihf-objcopy \
		lib=lib install

ARG LINUX_PAM_VERSION=1.5.2
RUN wget https://github.com/linux-pam/linux-pam/releases/download/v${LINUX_PAM_VERSION}/Linux-PAM-${LINUX_PAM_VERSION}.tar.xz -P /root/Temp && \
	tar xf /root/Temp/Linux-PAM-${LINUX_PAM_VERSION}.tar.xz -C /root/Temp && \
	cd /root/Temp/Linux-PAM-${LINUX_PAM_VERSION} && \
	./configure	--prefix=${TOOLCHAIN_PREFIX} \
		--host=arm-bemos-linux-musleabihf && \
	make && make install

ARG LIBCAP_NG_VERSION=0.8.3
RUN wget https://github.com/stevegrubb/libcap-ng/archive/refs/tags/v${LIBCAP_NG_VERSION}.tar.gz -P /root/Temp && \
	tar xf /root/Temp/v${LIBCAP_NG_VERSION}.tar.gz -C /root/Temp && \
	cd /root/Temp/libcap-ng-${LIBCAP_NG_VERSION} && \
	./autogen.sh && \
 	./configure CC=arm-bemos-linux-musleabihf-gcc --prefix=${TOOLCHAIN_PREFIX} \
		--host=arm-bemos-linux-musleabihf && \
	make && make install

ARG UTIL_LINUX_VERSION=2.38.1
RUN wget https://github.com/util-linux/util-linux/archive/refs/tags/v${UTIL_LINUX_VERSION}.tar.gz -P /root/Temp && \
	tar xf /root/Temp/v${UTIL_LINUX_VERSION}.tar.gz -C /root/Temp && \
	cd /root/Temp/util-linux-${UTIL_LINUX_VERSION} && \
	./autogen.sh && \
	CC=arm-bemos-linux-musleabihf-gcc ./configure \
		--prefix=${TOOLCHAIN_PREFIX} \
		--host=arm-bemos-linux-musleabihf --disable-all-programs --enable-libmount --enable-libblkid && \
	make && make install

COPY arm-gcc.txt /root/arm-gcc.txt

ARG SYSTEMD_VERSION=251
COPY systemd /root/Temp/systemd_patches/
RUN wget https://github.com/systemd/systemd/archive/refs/tags/v${SYSTEMD_VERSION}.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/v${SYSTEMD_VERSION}.tar.gz -C /root/Temp
RUN cd /root/Temp/systemd-${SYSTEMD_VERSION} && \
	for i in /root/Temp/systemd_patches/*.patch; do patch -p1 < $i; done
RUN cd /root/Temp/systemd-${SYSTEMD_VERSION} && mkdir build && \
	CFLAGS="-D__UAPI_DEF_ETHHDR=0 -I${TOOLCHAIN_PREFIX}/include" meson setup \
		--prefix=${TOOLCHAIN_PREFIX} \
		--buildtype=release \
		--cross-file=/root/arm-gcc.txt \
		-Dgshadow=false \
		-Didn=false \
		-Dlocaled=false \
		-Dnss-systemd=false \
		-Dnss-mymachines=false \
		-Dnss-resolve=false \
		-Dnss-myhostname=false \
		-Dsysusers=false \
		-Duserdb=false \
		-Dutmp=false \
		-Dtests=false \
		-Dstatic-libsystemd=pic \
		build && \
	ninja -C build libsystemd.a src/libsystemd/libsystemd.pc && \
	cp build/libsystemd.a ${TOOLCHAIN_PREFIX}/lib && \
	cp build/src/libsystemd/libsystemd.pc ${TOOLCHAIN_PREFIX}/lib/pkgconfig && \
	mkdir ${TOOLCHAIN_PREFIX}/include/systemd && \
	cp src/systemd/*.h ${TOOLCHAIN_PREFIX}/include/systemd

ARG OPENSSL_VERSION=3.0.8
SHELL ["/bin/bash", "-c"]
RUN wget https://github.com/openssl/openssl/archive/refs/tags/openssl-${OPENSSL_VERSION}.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/openssl-${OPENSSL_VERSION}.tar.gz -C /root/Temp && \
	cd /root/Temp/openssl-openssl-${OPENSSL_VERSION} && \
	CC=gcc perl ./Configure linux-armv4 \
		--cross-compile-prefix=arm-bemos-linux-musleabihf- \
		--prefix=${TOOLCHAIN_PREFIX} \
		no-shared && \
	make -j 6 && \
	make install
	
RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.81.0/source/boost_1_81_0.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/boost_1_81_0.tar.gz -C /root/Temp && \
	cd /root/Temp/boost_1_81_0 && \
	./bootstrap.sh && \
	sed -i 's/using gcc/using gcc : arm : arm-bemos-linux-musleabihf-g++/g' project-config.jam && \
	./b2 install toolset=gcc-arm --without-python \
		--prefix=${TOOLCHAIN_PREFIX}

ARG MODBUS_VERSION=3.1.10
RUN wget https://github.com/stephane/libmodbus/releases/download/v${MODBUS_VERSION}/libmodbus-${MODBUS_VERSION}.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/libmodbus-${MODBUS_VERSION}.tar.gz -C /root/Temp && \
	cd /root/Temp/libmodbus-${MODBUS_VERSION} && \
	./configure CC=arm-bemos-linux-musleabihf-gcc --prefix=${TOOLCHAIN_PREFIX} \
		--host=arm-bemos-linux-musleabihf \
		--with-pic --enable-static --enable-shared=no && \
	make && make install

ARG LUA_VERSION=5.4.4
RUN wget https://github.com/lua/lua/archive/refs/tags/v${LUA_VERSION}.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/v${LUA_VERSION}.tar.gz -C /root/Temp && \
	cd /root/Temp/lua-${LUA_VERSION} && \
	sed -i 's/-march=native/-march=armv7-a -mtune=cortex-a9 -mfpu=neon/g' makefile && \
	make CC=arm-bemos-linux-musleabihf-gcc \
		AR="arm-bemos-linux-musleabihf-ar rc"  \
		RANLIB=arm-bemos-linux-musleabihf-ranlib \
		MYCFLAGS="-std=c99 -DLUA_USE_LINUX" \
		liblua.a && \
	mkdir -p ${TOOLCHAIN_PREFIX}/include/lua5.4 && \
	cp *.h ${TOOLCHAIN_PREFIX}/include/lua5.4 && \
	cp liblua.a ${TOOLCHAIN_PREFIX}/lib
COPY lua.pc.in /root/Temp/lua-${LUA_VERSION}
RUN cd /root/Temp/lua-${LUA_VERSION} && \
	sed -e s/@VERSION@/${LUA_VERSION}/ -e s#@LIBDIR@#${TOOLCHAIN_PREFIX}/lib# \
		-e s#@INCLUDEDIR@#${TOOLCHAIN_PREFIX}/include/lua5.4# lua.pc.in > lua5.4.pc && \
	cp lua5.4.pc ${TOOLCHAIN_PREFIX}/lib/pkgconfig

ARG CMAKE_VERSION=3.25.1
RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz -P /root/Temp && \
	tar -xzf /root/Temp/cmake-${CMAKE_VERSION}.tar.gz -C /root/Temp && \
	/root/Temp/cmake-${CMAKE_VERSION}/bootstrap && \
	make -j 6 /root/Temp/cmake-${CMAKE_VERSION} && \
	make install /root/Temp/cmake-${CMAKE_VERSION}

RUN rm -Rf /root/Temp