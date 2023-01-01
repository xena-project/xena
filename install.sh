#!/system/bin/sh
mkdir folder
# Download proot-static
curl https://github.com/ZhymabekRoman/proot-static/archive/refs/tags/1.0.tar.gz > ./folder/file.tar.gz
cd folder
# Untar
tar -xvf file.tar.gz

