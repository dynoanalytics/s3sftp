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
# sudo mkdir /home/$ACCOUNT
sudo chown root:root /home
sudo chown $ACCOUNT:$ACCOUNT /home/$ACCOUNT
sudo chmod 755 /home/$ACCOUNT

echo "done5"

# EC2METALATEST=http://169.254.169.254/latest && \
# EC2METAURL=$EC2METALATEST/meta-data/iam/security-credentials/ && \
# EC2ROLE=`curl -s $EC2METAURL`
# echo "EC2ROLE: $EC2ROLE"

echo "done6"

ps -ef | grep  s3fs

echo "done7"

### ADD this to crontab

line="@reboot /usr/local/bin/s3fs $S3BUCKETNAME -o iam_role=S3FS-Role -o use_path_request_style /home/$ACCOUNT -o url='https://s3.$S3BUCKETREGION.amazonaws.com' -o nonempty \ "
# * * * * * cd /home/$ACCOUNT/reports && d=$(date +'\%Y-\%m-\%d') find . -type f -name 'FTP_Call_Report.csv*' -exec sh -c 'x=\"{}\"; mv \"$x\" \"FTP_Call_Report_$(echo $d).csv\"' \; \
# * * * * * cd /home/$ACCOUNT/reports && d=$(date +'\%Y-\%m-\%d') find . -type f -name 'FTP_Agent_State_Details.csv*' -exec sh -c 'x=\"{}\"; mv \"$x\" \"FTP_Agent_State_Details_$(echo $d).csv\"' \; " 
(echo $line ) | sudo crontab -u $ACCOUNT -

# ADD this to sudo nano /etc/ssh/sshd_config 
# Users in group "sftp" can use sftp but cannot ssh like normal

echo "done8"

sudo groupadd sftp
sudo sh -c "usermod -a -G sftp $ACCOUNT"

sudo sh -c 'cp /tmp/sshd_config.txt /etc/ssh/sshd_config'

echo "done9"

# S3BUCKETREGION=us-east-1 S3BUCKETNAME=dyno.fluenthome.sftp.com ACCOUNT=fluenthome /usr/local/bin/s3fs dyno.fluenthome.sftp.com -o iam_role=S3FS-Role,allow_other -o use_path_request_style -o dbglevel=info -f -o curldbg /home/fluenthome -o url='https://s3.us-east-1.amazonaws.com' -o nonempty
# ps -ef | grep  s3fs

echo "done!"

# ssh -i "S3FS" ec2-user@$(terraform output public_ip)
