#!/bin/bash -x

## Build a minimal Docker image for Debian
## Using jessie/armhf by default

prepare_tmp_dirs () {
	CHROOT_DIR=$(mktemp -d ${TMPDIR:-/var/tmp}/debian-${SUITE}-${ARCH}-XXXXXXXXXX)
	trap "rm -rf $CHROOT_DIR" EXIT TERM INT
}

debootstrap_native () {	
	export DEBIAN_FRONTEND="noninteractive"
	debootstrap --arch $ARCH $SUITE $CHROOT_DIR $APT_MIRROR
}

debootstrap_foreign () {	
	export DEBIAN_FRONTEND="noninteractive"
	# First stage, host 
	debootstrap --foreign --arch $ARCH $SUITE $CHROOT_DIR $APT_MIRROR

	cp /usr/bin/qemu-arm-static "${CHROOT_DIR}/usr/bin"
	# Second stage, inside chroot
	LC_ALL=C LANGUAGE=C LANG=C chroot $CHROOT_DIR /debootstrap/debootstrap --second-stage
	LC_ALL=C LANGUAGE=C LANG=C chroot $CHROOT_DIR dpkg --configure -a

}

configure_repos () {
	printf 'deb http://httpredir.debian.org/debian %s main\n' "$SUITE" > "${CHROOT_DIR}/etc/apt/sources.list"
	printf 'deb http://httpredir.debian.org/debian %s-updates main\n' "$SUITE" >> "${CHROOT_DIR}/etc/apt/sources.list"
	printf 'deb http://security.debian.org/ %s/updates main\n' "$SUITE" >> "${CHROOT_DIR}/etc/apt/sources.list"

	chroot $CHROOT_DIR apt-get update
	chroot $CHROOT_DIR apt-get -y upgrade  
}

chroot_cleanup () {
	chroot $CHROOT_DIR apt-get autoclean
	chroot $CHROOT_DIR apt-get clean
	chroot $CHROOT_DIR apt-get autoremove
}

import_to_docker () {
	local id
	id=$(tar --numeric-owner -C $CHROOT_DIR -c . | docker import - $DOCKER_TAG)

	docker run -i -t --rm $DOCKER_TAG printf '%s with id=%s created!\n' $DOCKER_TAG $id
}

push_to_hub () {
	[ $PUSH_TO_HUB -eq 1 ] || return
	docker push $DOCKER_TAG
}

## Configuration
SUITE=${SUITE:-jessie}
APT_MIRROR=${APT_MIRROR:-http://ftp.de.debian.org/debian/}
ARCH=${ARCH:-armhf}
PUSH_TO_HUB=${PUSH_TO_HUB:-0}
DOCKER_TAG="rustamt/debian:$SUITE-$ARCH"

CHROOT_DIR=${CHROOT_DIR:-/tmp/chroot/debian-${SUITE}-${ARCH}}

## Exit if not root
[ $(id -u) -eq 0 ] || {
	printf >&2 '%s requires root\n' "$0"
	exit 1
}

prepare_tmp_dirs

NATIVE="true"
[ "$(dpkg --print-architecture)" == "${ARCH}" ] || NATIVE="false"

if [ "${NATIVE}" == "true" ] ; then
	debootstrap_native
else
	debootstrap_foreign
fi

configure_repos
chroot_cleanup
import_to_docker
push_to_hub
