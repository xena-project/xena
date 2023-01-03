#!/system/bin/sh

if [ ! -f rootfs/.installed ]; #Im sure this is a bad way of doing this, there must be a better way implementing this.
then
mkdir rootfs

# Download proot-static and debian rootfs.                                  # TODO: Add --clean switch incase user encounters corrupted download.
if [ ! -f $TMPDIR/proot.tar.gz ];
then
	curl -L https://github.com/ZhymabekRoman/proot-static/archive/refs/tags/1.0.tar.gz > $TMPDIR/proot.tar.gz
fi

if [ ! -f $TMPDIR/rootfs.tar.xz ];
then
	curl -L https://github.com/termux/proot-distro/releases/download/v3.3.0/debian-arm-pd-v3.3.0.tar.xz > $TMPDIR/rootfs.tar.xz
fi

# Download static busybox
curl https://busybox.net/downloads/binaries/1.21.1/busybox-armv7l > rootfs/busybox
chmod 777 rootfs/busybox

# Untar
tar -xf $TMPDIR/proot.tar.gz 
# Using this method to avoid symlink errors.
proot-static-1.0/proot_static -0 -l -w / -r rootfs -b $TMPDIR/:/tmp /busybox tar -xf /tmp/rootfs.tar.xz

# DNS fix
echo "nameserver 8.8.8.8" > rootfs/etc/resolv.conf

#
echo "Message here" > rootfs/etc/motd

# Create VNC server start script
# TODO: Make connection only accesable to localhost
# TODO: Add customizable resolution in config file
cat > rootfs/bin/startvnc <<- EOM
Xvnc -SecurityTypes none -listen tcp -ZlibLevel=0 -ImprovedHextile=0 -CompareFB=0 -geometry 1024x600 :1 > /dev/null & 
EOM
chmod 777 rootfs/bin/startvnc

# Write in ~/.bashrc that installs packages update stuff, in future might just add cronjob where it automatically does it every week.
cat > rootfs/root/.bashrc <<- EOM
#!/bin/sh
if [ ! -f /root/.FirstRunDone ];
then
	apt update
	apt upgrade -y
	apt install wget gnupg2 -y
	wget https://itai-nelken.github.io/weekly-box86-debs/debian/box86.list -O /etc/apt/sources.list.d/box86.list
	wget -qO- https://itai-nelken.github.io/weekly-box86-debs/debian/KEY.gpg | apt-key add -
	apt update && apt install box86 tigervnc-standalone-server -y
	touch /root/.FirstRunDone
fi

cat /etx/motd
startvnc
EOM

# Self Explanatory
printf "#!/bin/sh\nbox86 /opt/wine-devel/bin/wine $@" > /bin/wine
printf "#!/bin/sh\nbox86 /opt/wine-devel/bin/wineserver $@" > /bin/wineserver

touch rootfs/.installed # Wow best way to check if its installed


fi

command="./proot-static-1.0/proot_static"
command+=" --kill-on-exit"
command+=" --link2symlink"
command+=" -0"
command+=" -r rootfs/"
command+=" -b /dev"
command+=" -b /proc"
command+=" -b /sys"
command+=" -b /data/data/com.termux"
command+=" -b /:/host-rootfs"
command+=" -b /sdcard"
command+=" -b /storage"
command+=" -b /mnt"
command+=" -b $TMPDIR/:/tmp"
command+=" -b /storage/9A03-171A/Android/data/com.termux/files/:/external"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=xterm-256color"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"

exec $command
