#!/bin/sh

ACCOUNT=$1
S3BUCKETNAME=dyno.$ACCOUNT.sftp.com
S3BUCKETREGION=$2
USERS=$3


########## Install Packages ##########
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


########## Install S3FS Fuse ##########
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse/

./autogen.sh
./configure

make
sudo make install


########## CREATE SFTP GROUP ##########
sudo groupadd sftp


########## CREATE DATA DIRECTORY ##########
# /data
sudo mkdir /data
sudo chown root:root /data
sudo chmod 755 /data




########## CREATE USER ACCOUNTS ##########
IFS=';' read -ra CREDENTIALS <<< "$USERS"
for i in "${CREDENTIALS[@]}"; do
    IFS=':' read -ra CREDENTIAL <<< "$i"
    USERNAME=${CREDENTIAL[0]}
    PASSWORD=${CREDENTIAL[1]}

    sudo adduser $USERNAME
    sudo sh -c "usermod -a -G sftp $USERNAME"
    echo "$USERNAME:$PASSWORD" | sudo chpasswd

    # /data/$USERNAME
    sudo mkdir /data/$USERNAME
    sudo chown $USERNAME:sftp /data/$USERNAME
    sudo chmod 700 /data/$USERNAME

    ########## ADD S3FS TO CRONTAB ##########
    line="@reboot /usr/local/bin/s3fs $S3BUCKETNAME:/$USERNAME -o iam_role=S3FS-Role -o use_path_request_style /data/$USERNAME -o url='https://s3.$S3BUCKETREGION.amazonaws.com' -o nonempty -o umask=077 \ "
    # * * * * * cd /home/$ACCOUNT/reports && d=$(date +'\%Y-\%m-\%d') find . -type f -name 'FTP_Call_Report.csv*' -exec sh -c 'x=\"{}\"; mv \"$x\" \"FTP_Call_Report_$(echo $d).csv\"' \; \
    # * * * * * cd /home/$ACCOUNT/reports && d=$(date +'\%Y-\%m-\%d') find . -type f -name 'FTP_Agent_State_Details.csv*' -exec sh -c 'x=\"{}\"; mv \"$x\" \"FTP_Agent_State_Details_$(echo $d).csv\"' \; " 
    (echo $line ) | sudo crontab -u $USERNAME -
done


########## MOUNT S3FS ##########
sudo /usr/local/bin/s3fs $S3BUCKETNAME -o iam_role=S3FS-Role -o use_path_request_style /data -o url="https://s3.${S3BUCKETREGION}.amazonaws.com" -o nonempty -o umask=022

IFS=';' read -ra CREDENTIALS <<< "$USERS"
for i in "${CREDENTIALS[@]}"; do
    IFS=':' read -ra CREDENTIAL <<< "$i"
    USERNAME=${CREDENTIAL[0]}
    PASSWORD=${CREDENTIAL[1]}

    sudo mkdir /data/$USERNAME
    sudo chown $USERNAME:sftp /data/$USERNAME
    sudo chmod 700 /data/$USERNAME
done


########## CONFIGURE SSHD ##########
sudo sh -c 'cp /tmp/sshd_config.txt /etc/ssh/sshd_config'


########## DEBUG COMMAND ##########
# S3BUCKETREGION=us-east-1 S3BUCKETNAME=dyno.fluenthome.sftp.com ACCOUNT=fluenthome /usr/local/bin/s3fs dyno.fluenthome.sftp.com -o iam_role=S3FS-Role,allow_other -o use_path_request_style -o dbglevel=info -f -o curldbg /home/fluenthome -o url='https://s3.us-east-1.amazonaws.com' -o nonempty
# sudo /usr/local/bin/s3fs dyno.demo.sftp.com:/demo -o iam_role=S3FS-Role -o use_path_request_style /data/demo -o url='https://s3.us-east-1.amazonaws.com' -o nonempty 
# ps -ef | grep  s3fs

# ssh -i "S3FS" ec2-user@$(terraform output public_ip)
