#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket qw(AF_INET AF_UNIX SOCK_STREAM SHUT_WR);

my ($host, $port) = (@ARGV);
open(LOG, ">>/home/vmail/sock.log") || die "cannot open log";
print LOG $$."\n".`date`;

my $old_fh = select(STDOUT);
$| = 1;
select($old_fh);

my $client = IO::Socket->new(
    Domain => AF_INET,
    Type => SOCK_STREAM,
    proto => 'tcp',
    PeerPort => $port,
    PeerHost => $host,
) || die "Can't open socket: $IO::Socket::errstr";


my $buffer;
$client->recv($buffer, 1024);
print LOG "client recv $buffer";
print $buffer;

while (my $line = <STDIN> )
{
	print LOG "server $line";
	$client->send($line);
}

$client->shutdown(SHUT_WR);


$client->close();
close(LOG);
