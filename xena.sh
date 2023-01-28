# vim: fileencoding=utf8:filetype=bash:nu:ts=2:shiftwidth=2:softtabstop=2:noexpandtab

########
# Checks
if [ "$(id -u)" = "0" ]; then
        echo "Cannot run this script as root! Refusing to work"
        exit 1
fi

if [ ! -f "/system/build.prop" ]; then
	echo "Script is only written to run in Android. Refusing to work."
	exit 1
fi

if [ $# -eq 0 ]; then
    echo "No option or file is present. Run xena.sh -h for options."
		exit 1
else
	EXE_FILE=$1
	COMMAND_EXEC=/bin/wine 
fi

########
# Functions

function check_var {
  if [ ! -z "${!1}" ]; then
		echo "Note: Detected $1 altered values to ${!1}. "
	else
		eval "$1=\$DEFAULT_$1"
  fi
}

function _help {
	echo "
	 Xena a front-end wrapper for proot, box86 and wine.
	 Usage: xena.sh [options]

	 -s | Shell mode. useful
	 "
	exit 1
}

#######


# Constant Variables
########
HASH="?" # Somethingl like `1ea2922`? i dunno whats that will find out later.
XENA_VERSION="1.0"
#########
#########

########
# Default variables
DEFAULT_WINE_VERSION="7.1"
DEFAULT_ROOTFS_PATH="$HOME/.xena"
DEFAULT_PROOT_PATH="$HOME/.proot"
#DEFAULT_WINE_PREFIX="~/wine"
########

##########
# User Modifiable Variables
check_var "WINE_VERSION"
check_var "ROOTFS_PATH"
check_var "PROOT_PATH"
#########



# Option Parsing
while getopts "hsv" opt; do
  case $opt in
    h)
      _help
      ;;
    s)
      COMMAND_EXEC="--login"
      ;;
		v)
			echo "$XENA_VERSION+$HASH"
			exit 0
			;;
    \?)
      # Invalid option
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
  esac
done

shift $((OPTIND - 1))

#

# Installation
if [ ! -f "$ROOTFS_PATH/.installed" ]; then
	echo "Installing required stuff... Please don't panic if you cant understand anything."
	sleep 3
	mkdir $ROOTFS_PATH
	mkdir $PROOT_PATH

	# Download proot-static and debian rootfs.                                  # TODO: Add --clean switch incase user encounters corrupted download.
	if [ ! -f $TMPDIR/proot.tar.gz ];
	then
		echo "Downloading proot..."
		curl -L https://github.com/ZhymabekRoman/proot-static/archive/refs/tags/1.0.tar.gz -o $TMPDIR/proot.tar.gz >> /dev/null
		echo "Done."
	fi

	if [ ! -f $TMPDIR/rootfs.tar.xz ];
	then
		echo "Downloading Debian Rootfs..."
		curl -L https://github.com/termux/proot-distro/releases/download/v3.3.0/debian-arm-pd-v3.3.0.tar.xz -o $TMPDIR/rootfs.tar.xz >> /dev/null
		echo "Done."
fi
	# Download static busybox
	echo "Downloading busybox..."
	mkdir $ROOTFS_PATH/bin
	curl https://busybox.net/downloads/binaries/1.21.1/busybox-armv7l -o $ROOTFS_PATH/bin/busybox >> /dev/null
	chmod 777 $ROOTFS_PATH/bin/busybox
	echo "Done"

	# Untar
	echo "Extracting files..."
	tar -xf $TMPDIR/proot.tar.gz --strip-components=1 -C $PROOT_PATH
	# Using this method to avoid symlink errors.
	$PROOT_PATH/proot_static -0 -l -w / -r $ROOTFS_PATH -b $TMPDIR/:/tmp /bin/busybox tar -xf /tmp/rootfs.tar.xz

	# DNS fix
	echo "Adding resolv.conf"
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
		wget -qO- https://itai-nelken.github.io/weekly-box86-debs/debian/KEY.gpg | apt-key add -
		apt update
		apt install box86
		wget https://twisteros.com/wine.tgz -O ~/wine.tgz
		mkdir /opt/wine
		busybox tar -xzvf ~/wine.tgz -C /opt/
		touch /root/.FirstRunDone
	fi
	startvnc
	EOM

	# Self Explanatory
	printf "#!/bin/sh\nbox86 /opt/wine/bin/wine \$@" > $ROOTFS_PATH/bin/wine
	printf "#!/bin/sh\nbox86 /opt/wine/bin/wineserver \$@" > $ROOTFS_PATH/bin/wineserver
	chmod 777 $ROOTFS_PATH/bin/wine
	chmod 777 $ROOTFS_PATH/bin/wineserver
	touch $ROOTFS_PATH/.installed # Wow best way to check if its installed

fi

# Its prooting time
# TODO: Optional `--proot-command` flag or similar.
proot_flags=(
"$PROOT_PATH/proot_static"
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
"DISPLAY=:1"
"PULSE_SERVER=127.0.0.1"
"/bin/bash" 
"--login"
"$COMMAND_EXEC"
"$EXE_FILE"
)
exec "${proot_flags[@]}"
