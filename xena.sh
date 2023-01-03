
#set -e -u

#########
# Global environments
WINE_VERSION="7.1"
ROOTFS_PATH="$HOME/.xena"
#PROOT_BIN=""
#########

if [ ! -f "$ROOTFS_PATH/.installed" ]; #Im sure this is a bad way of doing this, there must be a better way implementing this.
then
	mkdir $ROOTFS_PATH

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
	mkdir $ROOTFS_PATH/bin
	curl https://busybox.net/downloads/binaries/1.21.1/busybox-armv7l > $ROOTFS_PATH/bin/busybox
	chmod 777 $ROOTFS_PATH/bin/busybox

	# Untar
	tar -xf $TMPDIR/proot.tar.gz 
	# Using this method to avoid symlink errors.
	proot-static-1.0/proot_static -0 -l -w / -r $ROOTFS_PATH -b $TMPDIR/:/tmp /bin/busybox tar -xf /tmp/rootfs.tar.xz
	# DNS fix
	echo "nameserver 8.8.8.8" > $ROOTFS_PATH/etc/resolv.conf
	# TODO: Add MOTD, i have no idea what to write something friendly
	echo "A" > $ROOTFS_PATH/etc/motd

	# Create VNC server start script
	# TODO: Make connection only accesable to localhost
	# TODO: Add customizable resolution in config file
	cat > $ROOTFS_PATH/bin/startvnc <<- EOM
	Xvnc -SecurityTypes none -listen tcp -ZlibLevel=0 -ImprovedHextile=0 -CompareFB=0 -geometry 1024x600 :1 > /dev/null & 
	EOM
	chmod 777 $ROOTFS_PATH/bin/startvnc

	# Write in ~/.bashrc that installs packages update stuff, in future might just add cronjob where it automatically does it every week.
	cat > $ROOTFS_PATH/root/.bashrc <<- EOM
	#!/bin/sh
	if [ ! -f /root/.FirstRunDone ];
	then
		apt update
		apt upgrade -y
		apt install wget gnupg2 tigervnc-standalone-server -y
		wget https://itai-nelken.github.io/weekly-box86-debs/debian/box86.list -O /etc/apt/sources.list.d/box86.list
		wget -qO- https://itai-nelken.github.io/weekly-box86-debs/debian/KEY
		apt install box86
		touch /root/.FirstRunDone
	fi
	apt install box86
	cat /etc/motd
	startvnc
	EOM

	# Self Explanatory
	printf "#!/bin/sh\nbox86 /opt/wine-devel/bin/wine $@" > $ROOTFS_PATH/bin/wine
	printf "#!/bin/sh\nbox86 /opt/wine-devel/bin/wineserver $@" > $ROOTFS_PATH/bin/wineserver
	touch $ROOTFS_PATH/.installed # Wow best way to check if its installed

fi

# Its prooting time
# TODO: Optional `--proot-command` flag or similar.
proot_flags=(
"./proot-static-1.0/proot_static"
"--kill-on-exit"
"--link2symlink"
"-0"
"-r $ROOTFS_PATH"
"-b /dev"
"-b /proc"
"-b /sys"
"-b /data/data/com.termux"
"-b /sdcard"
"-b /storage"
"-b /mnt"
"-b $TMPDIR/:/tmp"
#TODO: Automatically find XXXX-XXXX in /storage and mount it in /external for ease
"-b /storage/9A03-171A/Android/data/com.termux/files/:/external"
"-w /root"
"/usr/bin/env"
"-i"
"HOME=/root"
"PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
"TERM=xterm-256color"
"LANG=C.UTF-8"
"/bin/bash" 
"--login"
)

exec "${proot_flags[@]}"
