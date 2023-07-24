docker build -t docker.bestsens.local/bone/musl-build-image . || exit 1
docker run -v ${PWD}:/data -t docker.bestsens.local/bone/musl-build-image \
		/bin/tar -czvf /data/arm-bemos-linux-musleabihf.tar.gz /opt/x-tools/arm-bemos-linux-musleabihf/