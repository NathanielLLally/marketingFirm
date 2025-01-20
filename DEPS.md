#/bin/sh

USER=devel
TOP=/home/$USER/src/git/marketingFirm
PWD=$TOP

mkdir /home/$USER/bin
cd /home/$USER/bin
ln -s $TOP/parsers/*.pl .

#Debian Based
sudo apt install libcrypt-ssleay-perl
sudo apt install libssl-dev
sudo apt install libz-dev

#perl modules

DBD::CSV
Data::Serializer
IPC::Run
LWP
Net::SSLeay
IO::Socket::SSL
LWP::Parallel
URI::Encode
JSON
URI::Find
URI::Simple
Tie::IxHash
