#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo '%sudo ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers

set -x &&
  dpkg --add-architecture i386 &&
  apt-get update &&
  apt-get install -y perl-modules \
    curl \
    lsof \
    libc6:i386 \
    lib32gcc-s1 \
    bzip2 \
    gosu \
    sudo \
    nano \
    cron &&
  apt-get -qq autoclean && apt-get -qq autoremove && apt-get -qq clean &&
  rm -rf /tmp/* /var/cache/*
