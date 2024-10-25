#!/bin/bash
set -x

SCRIPTPATH="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

echo "Setting up chroot environment in $SCRIPTPATH"

# set user and group to the current user
USER=$(whoami)
GROUP=$(id -gn)

sudo chown -R $USER:$GROUP "$SCRIPTPATH/bin"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/chroot"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/etc"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/lib"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/lib32"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/lib64"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/libx32"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/sbin"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/usr"
sudo chown -R $USER:$GROUP "$SCRIPTPATH/var"

mkdir "$SCRIPTPATH/sys"
mkdir "$SCRIPTPATH/dev"
mkdir "$SCRIPTPATH/dev/pts"
mkdir "$SCRIPTPATH/proc"
mkdir "$SCRIPTPATH/tmp"

sudo mount -t proc proc $SCRIPTPATH/proc/
sudo mount -t sysfs sysfs $SCRIPTPATH/sys/
sudo mount -t devtmpfs udev $SCRIPTPATH/dev/
sudo mount -t devpts devpts $SCRIPTPATH/dev/pts/
sudo mount --rbind /tmp $SCRIPTPATH/tmp

mkdir $SCRIPTPATH/lib/aarch64-linux-gnu
touch $SCRIPTPATH/lib/ld-linux-aarch64.so.1
sudo mount --rbind /lib/ld-linux-aarch64.so.1 $SCRIPTPATH/lib/ld-linux-aarch64.so.1
sudo mount --rbind /lib/aarch64-linux-gnu $SCRIPTPATH/lib/aarch64-linux-gnu

# fix hostname dns resolution
echo 'nameserver 8.8.4.4' | sudo tee -a $SCRIPTPATH/etc/resolv.conf

rm $SCRIPTPATH/var/lib/dpkg/statoverride

export FEX_SERVERSOCKETPATH="$(id -u)-$(basename $SCRIPTPATH).chroot"

mkdir -p $SCRIPTPATH/usr/share/fex-emu/Config/
echo "{\"Config\": {\"ServerSocketPath\":\"$FEX_SERVERSOCKETPATH\"}}" >$SCRIPTPATH/usr/share/fex-emu/Config.json
echo "FEX_SERVERSOCKETPATH=${FEX_SERVERSOCKETPATH}" >>$SCRIPTPATH/etc/environment
sudo --preserve-env=FEX_ROOTFS,FEX_SERVERSOCKETPATH FEXServer -p 30
cp /usr/bin/FEXInterpreter $SCRIPTPATH/usr/bin/FEXInterpreter
sudo --preserve-env=FEX_ROOTFS,FEX_SERVERSOCKETPATH chroot . /usr/bin/FEXInterpreter /bin/bash $@
