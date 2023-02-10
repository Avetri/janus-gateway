FROM ubuntu:20.04

# ENV TZ=Europe/Riga
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get -y update && \
	apt-get install -y \
		libmicrohttpd-dev \
		libjansson-dev \
		libssl-dev \
		libsofia-sip-ua-dev \
		libglib2.0-dev \
		libopus-dev \
		libogg-dev \
		libcurl4-openssl-dev \
		liblua5.3-dev \
		libconfig-dev \
		python3-pip \
		gengetopt \
		libtool \
		automake \
		cmake \
		pkg-config \
		wget \
		git && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN pip3 install meson ninja

RUN cd /tmp && \
	git clone https://gitlab.freedesktop.org/libnice/libnice && \
	cd libnice && \
	meson --prefix=/usr build && \
	ninja -C build && \
	ninja -C build install

RUN cd /tmp && \
	wget https://github.com/cisco/libsrtp/archive/v2.2.0.tar.gz && \
	tar xfv v2.2.0.tar.gz && \
	cd libsrtp-2.2.0 && \
	./configure --prefix=/usr --enable-openssl && \
	make shared_library && \
	make install

RUN cd /tmp && \
	git clone https://github.com/sctplab/usrsctp && \
	cd usrsctp && \
	./bootstrap && \
	./configure --prefix=/usr --disable-programs --disable-inet --disable-inet6 && \
	make && \
	make install

RUN cd /tmp && \
	git clone https://libwebsockets.org/repo/libwebsockets && \
	cd libwebsockets && \
	git checkout v4.3-stable && \
	mkdir build && \
	cd build && \
	cmake -DLWS_MAX_SMP=1 -DLWS_WITHOUT_EXTENSIONS=0 -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" .. && \
	make && \
	make install

COPY . /usr/local/src/janus-gateway

RUN cd /usr/local/src/janus-gateway && \
	sh autogen.sh && \
	./configure --prefix=/usr/local --disable-plugin-audiobridge --disable-plugin-echotest --disable-plugin-recordplay --disable-plugin-sip --disable-plugin-nosip --disable-plugin-textroom --disable-plugin-videocall --disable-plugin-videoroom --disable-plugin-voicemail && \
	make && \
	make install && \
	make configs

FROM ubuntu:20.04

ARG BUILD_DATE=$(shell date)
ARG GIT_BRANCH=$(shell git branch)
ARG GIT_COMMIT=$(shell git rev-parse HEAD)
ARG VERSION=$(shell git describe --abbrev=0 --dirty --always)

LABEL build_date=${BUILD_DATE}
LABEL git_branch=${GIT_BRANCH}
LABEL git_commit=${GIT_COMMIT}
LABEL version=${VERSION}

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get -y update && \
	apt-get install -y \
	lighttpd \
	libmicrohttpd12 \
	libjansson4 \
	libssl1.1 \
	libsofia-sip-ua0 \
	libglib2.0-0 \
	libopus0 \
	libogg0 \
	libcurl4 \
	liblua5.3-0 \
	libconfig9 && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

COPY --from=0 /usr/lib/libsrtp2.so.1 /usr/lib/libsrtp2.so.1
RUN ln -s /usr/lib/libsrtp2.so.1 /usr/lib/libsrtp2.so

COPY --from=0 /usr/lib/x86_64-linux-gnu/libnice.so.10.13.1 /usr/lib/libnice.so.10.13.1
RUN ln -s /usr/lib/libnice.so.10.13.1 /usr/lib/libnice.so.10
RUN ln -s /usr/lib/libnice.so.10.13.1 /usr/lib/libnice.so

COPY --from=0 /usr/lib/libusrsctp.so.2.0.0 /usr/lib/libusrsctp.so.2.0.0
RUN ln -s /usr/lib/libusrsctp.so.2.0.0 /usr/lib/libusrsctp.so.2
RUN ln -s /usr/lib/libusrsctp.so.2 /usr/lib/libusrsctp.so

COPY --from=0 /usr/lib/libwebsockets.so.19 /usr/lib/libwebsockets.so.19
RUN ln -s /usr/lib/libwebsockets.so.19 /usr/lib/libwebsockets.so

COPY --from=0 /usr/local/bin/janus /usr/local/bin/janus
COPY --from=0 /usr/local/bin/janus-cfgconv /usr/local/bin/janus-cfgconv
COPY --from=0 /usr/local/etc/janus /usr/local/etc/janus
COPY --from=0 /usr/local/lib/janus /usr/local/lib/janus
COPY --from=0 /usr/local/share/janus /usr/local/share/janus

ENV BUILD_DATE=${BUILD_DATE}
ENV GIT_BRANCH=${GIT_BRANCH}
ENV GIT_COMMIT=${GIT_COMMIT}
ENV VERSION=${VERSION}

EXPOSE 5000-5100/udp
EXPOSE 80
EXPOSE 8080
EXPOSE 8188
EXPOSE 8088
EXPOSE 8089
EXPOSE 8889
EXPOSE 8000
EXPOSE 7088
EXPOSE 7089

CMD ["/usr/local/bin/janus"]

# RUN cd /tmp && \
# 	git clone https://github.com/Avetri/FFmpeg.git ffmpeg.my.git && \
# 	cd ffmpeg.my.git && \
# 	git checkout -b n5.1.1.em origin/n5.1.1.em && \
# 	./configure --prefix=/usr --enable-gpl --enable-libfdk-aac --enable-libx264 --enable-libx265 --enable-nonfree --enable-libopus --enable-libvpx --enable-libsrt && \
# 	make && \
# 	make install

