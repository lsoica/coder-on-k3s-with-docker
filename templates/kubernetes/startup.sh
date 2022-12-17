#!/bin/bash

# home folder can be empty, so copying default bash settings
if [ ! -f ~/.profile ]; then
    cp /etc/skel/.profile $HOME
fi
if [ ! -f ~/.bashrc ]; then
    cp /etc/skel/.bashrc $HOME
fi

# update certificates
sudo update-ca-certificates

# install and start code-server
curl -fsSL https://code-server.dev/install.sh | sh  | tee code-server-install.log
code-server --auth none --port 13337 | tee code-server-install.log &

echo ${repository}
echo ${branch}