#!/system/bin/sh
mkdir rootfs
# Download proot-static and debian rootfs.
#curl -L https://github.com/ZhymabekRoman/proot-static/archive/refs/tags/1.0.tar.gz > $TMPDIR/proot.tar.gz
#curl -L https://github.com/termux/proot-distro/releases/download/v3.3.0/debian-arm-pd-v3.3.0.tar.xz > $TMPDIR/rootfs.tar.xz
# Untar
tar -xvf $TMPDIR/proot.tar.gz 
tar -xvf $TMPDIR/rootfs.tar.xz -C rootfs/
# Nameserver fix
echo "nameserver 8.8.8.8" > rootfs/etc/resolv.conf
# Write in ~/.bashrc that installs packages update stuff, in future might just add cronjob where it automatically does it every week.
cat > rootfs/root/.bashrc <<- EOM
#!/bin/sh
apt update
apt upgrade -y
apt install gnupg gnupg2 -y
wget https://itai-nelken.github.io/weekly-box86-debs/debian/box86.list -O /etc/apt/sources.list.d/box86.list
wget -qO- https://itai-nelken.github.io/weekly-box86-debs/debian/KEY.gpg | apt-key add -
apt update && apt install box86 tigervnc-standalone-server -y

EOM
bash run.sh
