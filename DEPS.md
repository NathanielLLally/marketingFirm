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

#Redhat Based
sudo dnf install libzstd-devel

#perl modules
#  Tatsuhiko Miyagawa
#wget Miwigawa's CPAN minus

cpanm DBI Text::CSV_XS DBD::CSV IPC::Run LWP URI::Encode URI::Encod JSON URI::Find URI::Simple Tie::IxHash Net::SSLeay IO::Socket::SSL LWP::Parallel Data::Serializer
