#!/bin/sh

set -ex

ALPINE_VER="3.11"
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
#wget https://raw.githubusercontent.com/alpinelinux/alpine-make-rootfs/v0.3.1/alpine-make-rootfs -O "$MKROOTFS" \
#    && echo "832987f3c138c67b1f1a01f7ab961a029ebcac8b  $MKROOTFS" | sha1sum -c \
#    || exit 1
wget https://raw.githubusercontent.com/alpinelinux/alpine-make-rootfs/v0.5.0/alpine-make-rootfs -O "$MKROOTFS" \
    && echo "bb4869675fd4309755cab0ef4c4a25a9d37349fa3f5753d160bb1a80170a7f70  $MKROOTFS" | sha256sum -c \
    || exit 1

chmod +x ${MKROOTFS}

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
docker build --no-cache -t reveller/alpine:3.11 .
cd -

docker build --build-arg MS_TOKEN="${MS_TOKEN}" - <<'DOCKERFILE'
FROM reveller/alpine:3.11
ARG MS_TOKEN
RUN wget https://get.aquasec.com/microscanner -O /home/worker/microscanner \
  && echo "8e01415d364a4173c9917832c2e64485d93ac712a18611ed5099b75b6f44e3a5  /home/worker/microscanner" | sha256sum -c - \
  && chmod +x /home/worker/microscanner \
  && /home/worker/microscanner $MS_TOKEN
DOCKERFILE
