#!/bin/sh

set -ex

ALPINE_VER="${RELEASE}"
PACKAGES="apk-tools ca-certificates ssl_client"
MS_TOKEN="OWJjZTQwMjczMDk3"

MKROOTFS="/tmp/alpine-make-rootfs"
BUILD_TAR="/tmp/docker/alpine-rootfs-${ALPINE_VER}.tar.gz"

DOCKER_ROOT=$(dirname $BUILD_TAR)
[[ -d ${DOCKER_ROOT}  ]] || mkdir $DOCKER_ROOT

MS_ROOT="${DOCKER_ROOT}/../microscanner"
[[ -d ${MS_ROOT} ]] || mkdir $MS_ROOT

POST_INSTALL="./post-install.sh"

# Download rootfs builder and verify it.
wget https://raw.githubusercontent.com/alpinelinux/alpine-make-rootfs/v0.5.1/alpine-make-rootfs -O "$MKROOTFS" \
    && echo "a7159f17b01ad5a06419b83ea3ca9bbe7d3f8c03  $MKROOTFS" | sha1sum -c \
    || exit 1

chmod +x "${MKROOTFS}"

sudo ${MKROOTFS} --mirror-uri http://dl-2.alpinelinux.org/alpine \
	--branch "v${ALPINE_VER}" \
	--packages "$PACKAGES" \
	--script-chroot \
	"$BUILD_TAR" \
	"$POST_INSTALL"

cat <<DOCKERFILE > "${DOCKER_ROOT}/Dockerfile"
FROM scratch
USER worker
ADD $(basename $BUILD_TAR) /
CMD ["/bin/sh"]
DOCKERFILE

cd $DOCKER_ROOT
docker build --no-cache -t reveller/alpine:${RELEASE} .
cd -

docker build --build-arg MS_TOKEN="${MS_TOKEN}" - <<DOCKERFILE
FROM reveller/alpine:${RELEASE}
ARG MS_TOKEN
RUN wget https://get.aquasec.com/microscanner -O /home/worker/microscanner \
  && echo "8e01415d364a4173c9917832c2e64485d93ac712a18611ed5099b75b6f44e3a5  /home/worker/microscanner" | sha256sum -c - \
  && chmod +x /home/worker/microscanner \
  && /home/worker/microscanner $MS_TOKEN
DOCKERFILE
