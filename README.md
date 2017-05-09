## docker-debian

This is a build script for creating Debian docker images, I use it for my armhf boards.

Usage:

    ## Simple usage
    bash mkimage-debian.sh
    
    ## Extended usage
    SUITE=jessie ARCH=armhf PUSH_TO_HUB=1 DOCKER_TAG="misc/debian:jessie-armhf" bash mkimage-debian.sh

Normally, it should be run on a Docker host running Debian/Ubuntu.
