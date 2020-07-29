#!/bin/sh

ACCOUNT=$1
S3BUCKETNAME=dyno.$ACCOUNT.sftp.com
S3BUCKETREGION=$2
FTPPASSWORD="$ACCOUNT-4321"

echo "done1"

### STEP 4
# Install Packages
sudo yum -y update && \
sudo yum -y install \
htop \
jq \
automake \
openssl-devel \
git \
gcc \
libstdc++-devel \
gcc-c++ \
fuse \
fuse-devel \
curl-devel \
libxml2-devel

echo "done2"

# Install S3FS Fuse
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse/

./autogen.sh
./configure

make
sudo make install

echo "done3"

# which s3fs
# s3fs --help

### STEP 5
sudo adduser $ACCOUNT
echo "$ACCOUNT:$FTPPASSWORD" | sudo chpasswd

echo "done4"

# sudo mkdir /home/$ACCOUNT
# sudo chown nfsnobody:nfsnobody /home/$ACCOUNT
sudo chmod a-w /home/$ACCOUNT
# sudo mkdir /home/$ACCOUNT
sudo chown $ACCOUNT:$ACCOUNT /home/$ACCOUNT

echo "done5"

EC2METALATEST=http://169.254.169.254/latest && \
EC2METAURL=$EC2METALATEST/meta-data/iam/security-credentials/ && \
EC2ROLE=`curl -s $EC2METAURL`
echo "EC2ROLE: $EC2ROLE"

echo "done6"

ps -ef | grep  s3fs

echo "done7"

### ADD this to crontab

line="@reboot /usr/local/bin/s3fs $S3BUCKETNAME -o iam_role=$EC2ROLE,allow_other /home/$ACCOUNT -o url='https://s3.$S3BUCKETREGION.amazonaws.com' -o nonempty" 
(sudo crontab -u $ACCOUNT -l; echo $line ) | sudo crontab -u $ACCOUNT -

# ADD this to sudo nano /etc/ssh/sshd_config 
# Users in group "sftp" can use sftp but cannot ssh like normal

echo "done8"

sudo groupadd sftp
sudo sh -c 'usermod -a -G sftp $ACCOUNT'

sudo sh -c 'cat /tmp/sshd_config.txt >> /etc/ssh/sshd_config'

echo "done!"

# ssh -i "S3FS" ec2-user@$(terraform output public_ip)
