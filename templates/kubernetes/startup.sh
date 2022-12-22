#!/bin/bash

# home folder can be empty, so copying default bash settings
if [ ! -f ~/.profile ]; then
    cp /etc/skel/.profile $HOME
fi
if [ ! -f ~/.bashrc ]; then
    cp /etc/skel/.bashrc $HOME/.bashrc
fi

# update certificates
sudo update-ca-certificates

# install and start code-server
curl -fsSL https://code-server.dev/install.sh | sh  | tee code-server-install.log
code-server --auth none --port 13337 | tee code-server-install.log &

echo "${repository}"
echo "${branch}"
touch /home/coder/.ssh/id_rsa
echo "${private_key}" > /home/coder/.ssh/id_rsa
chmod go-rwx ~/.ssh/id_rsa
echo "${node_1_ip} node-1" | sudo tee -a /etc/hosts
echo "export NAMESPACE=${namespace}" | sudo tee -a $HOME/.bashrc

# pip3 install projector-installer --user
# /home/coder/.local/bin/projector --accept-license 

# /home/coder/.local/bin/projector config add pycharm1 /opt/pycharm-community-2022.3/ --force --use-separate-config --port 9001  --hostname localhost
# /home/coder/.local/bin/projector run pycharm1 &