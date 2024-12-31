#!/usr/bin/sh

#aws ec2 aws distro %V rpm/dnf based 
USER="ec2-user"

#  configure provisioned server
#
echo "%wheel	ALL=(ALL)	NOPASSWD: ALL" >> /etc/sudoers

sudo -i

sudo useradd nathaniel
sudo useradd devel
sudo passwd nathaniel 

sudo -iu nathaniel
ssh -no StrictHostKeyChecking=no localhost echo "hello"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9GwRp2LEtwJZ3yi7fo9hBO1QxJiOKwngYL4jkm5ObL awsFreeTier" > ~/.ssh/authorized_keys 

#chown nathaniel:nathaniel /home/nathaniel/.ssh/authorized_keys 
chmod 600 /home/nathaniel/.ssh/authorized_keys 

sudo groupmod -U nathaniel -a wheel
sudo groupadd -U nathaniel devel

dnf -y install certbot
dnf -y install nginx
dnf -y install git
dnf -y install cronie

chown -R devel:devel /usr/share/nginx/*

#
NUID=`grep devel /etc/passwd | perl -e '<STDIN> =~ /.*?:(\d+):/ && print "$1\n";'`

sudo -iu devel

git config --global user.email "nathaniel.lally@gmail.com"
git config --global user.name "NathanielLLally"
#resolve conflict -> merge
git config pull.rebase false


#establish known_hosts entry & create ~/.ssh dir
ssh -no StrictHostKeyChecking=no localhost echo "hello"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9GwRp2LEtwJZ3yi7fo9hBO1QxJiOKwngYL4jkm5ObL awsFreeTier" > ~/.ssh/authorized_keys 

chmod 600 ~/.ssh/authorized_keys 

#obtain path from
WWWPATH=`rpm -ql nginx | grep index.html | perl -e 'my $l = <STDIN>; $l =~ /(\/.*)index.html/ && print "$1\n"'`

cp /usr/share/nginx/

#  yeeeaaaahhh 'git comment'
#cp -R src/marketingFirm/www/* /usr/share/nginx/
ln -s src/marketingFirm/www/ .
ln -s src/marketingFirm/bin/ .
ln -s src/marketingFirm/etc/ .
ln -s `pwd`/src/ src/git

#chmod -R g+w www/*

#exit to superuser from devel
exit

#git clone
cp /home/devel/etc/nginx.conf /etc/nginx/
cp /home/devel/etc/http.site.conf /etc/nginx/conf.d/
systemctl enable nginx
systemctl start nginx

