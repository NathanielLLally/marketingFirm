#!/usr/bin/sh

#aws ec2 aws distro %V rpm/dnf based 
USER="ec2-user"

#  configure provisioned server
#
echo "%wheel	ALL=(ALL)	NOPASSWD: ALL" >> /etc/sudoers

sudo useradd nathaniel
sudo passwd nathaniel 

mkdir /home/nathaniel/.ssh
sudo cp /home/$USER/.ssh/authorized_keys /home/nathaniel/.ssh/
chown nathaniel:nathaniel /home/nathaniel/.ssh/authorized_keys 
chmod 600 /home/nathaniel/.ssh/authorized_keys 
sudo groupmod -U nathaniel -a wheel

sudo groupadd -U nathaniel devel

dnf install certbot
dnf install nginx

#
NUID=`grep devel /etc/passwd | perl -e '<STDIN> =~ /.*?:(\d+):/ && print "$1\n";'`

sudo useradd devel


systemctl enable nginx

#obtain path from
WWWPATH=`rpm -ql nginx | grep index.html | perl -e 'my $l = <STDIN>; $l =~ /(\/.*)index.html/ && print "$1\n"'`


