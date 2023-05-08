docker build -t docker.bestsens.de/bone/musl-build-image .
docker run -v ${PWD}:/data -t docker.bestsens.de/bone/musl-build-image \
		/bin/tar -czf /data/arm-bemos-linux-musleabihf.tar.gz /opt/x-tools/arm-bemos-linux-musleabihf/