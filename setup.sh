#!/bin/sh

USERNAME=ftpuser1
PASSWORD=ftpuser1
S3BUCKETNAME=ca-s3fs-bucket

### STEP 4
# Install Packages
sudo yum -y update && \
sudo yum -y install \
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

# Install S3FS Fuse
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse/

./autogen.sh
./configure

make
sudo make install

# which s3fs
# s3fs --help

### STEP 5
sudo adduser $USERNAME
sudo passwd $PASSWORD

sudo groupadd sftp
usermod -a -G sftp $USERNAME

sudo mkdir /home/$USERNAME/ftp
sudo chown $USERNAME:$USERNAME /home/$USERNAME/ftp
sudo chmod a-w /home/$USERNAME/ftp
sudo mkdir /home/$USERNAME/ftp/files
sudo chown $USERNAME:$USERNAME /home/$USERNAME/ftp/files

### STEP 6
sudo yum -y install vsftpd

sudo mv /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak

sudo -s
EC2_PUBLIC_IP=`curl -s ifconfig.co`
cat > /etc/vsftpd/vsftpd.conf << EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
chroot_local_user=YES
listen=YES
pam_service_name=vsftpd
tcp_wrappers=YES
user_sub_token=\$USER
local_root=/home/\$USER/ftp
pasv_min_port=40000
pasv_max_port=50000
pasv_address=$EC2_PUBLIC_IP
userlist_file=/etc/vsftpd.userlist
userlist_enable=YES
userlist_deny=NO
EOF
exit

echo $USERNAME | sudo tee -a /etc/vsftpd.userlist
sudo systemctl start vsftpd
sudo systemctl status vsftpd

### STEP 8
# EC2METALATEST=http://169.254.169.254/latest
# EC2METAURL=$EC2METALATEST/meta-data/iam/security-credentials/
# EC2ROLE=`curl -s $EC2METAURL`
# DOC=`curl -s $EC2METALATEST/dynamic/instance-identity/document`
# REGION=`jq -r .region <<< $DOC`
# echo "EC2ROLE: $EC2ROLE"
# echo "REGION: $REGION"
# sudo /usr/local/bin/s3fs $S3BUCKETNAME \
# -o use_cache=/tmp,iam_role="$EC2ROLE",allow_other /home/$USERNAME/ftp/files \
# -o url="https://s3.$REGION.amazonaws.com" \
# -o nonempty

### ADD this to crontab

line=@reboot /usr/local/bin/s3fs $S3BUCKETNAME -o use_cache=/tmp,iam_role=S3FS-Role,allow_other /home/$USERNAME/ftp/files -o url='https://s3.$REGION.amazonaws.com' -o nonempty
(crontab -u $USERNAME -l; echo "$line" ) | crontab -u $USERNAME -

### ADD this to /etc/ssh/sshd_config
# Users in group "sftp" can use sftp but cannot ssh like normal
Match group sftp
ChrootDirectory /home
X11Forwarding no
AllowTcpForwarding no
ForceCommand internal-sftp

# Turn on Passwords
PasswordAuthentication yes

### to run

echo "done"