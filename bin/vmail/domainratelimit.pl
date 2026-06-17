#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';
use IO::Socket qw(AF_INET AF_UNIX SOCK_STREAM SHUT_WR);

my ($host, $port) = (@ARGV);
open(LOG, ">>/home/vmail/sock.log") || die "cannot open log";
print LOG $$."\n".`date`;

my $server = IO::Socket->new(
	Domain => AF_INET,
	Type => SOCK_STREAM,
	Proto => 'tcp',
	LocalHost => '127.0.0.1',
	LocalPort => 10025,
	ReusePort => 1,
	Listen => 5,
) || die "Can't open socket: $IO::Socket::errstr";

while (1) {
    say "server waiting on 127.0.0.1:10025";
    # waiting for a new client connection
    my $client = $server->accept();

    # get information about a newly connected client
    my $client_address = $client->peerhost();
    my $client_port = $client->peerport();
    say "server: connection from $client_address:$client_port";

    # read up to 1024 characters from the connected client
    my $data = "";
my $relay;

$relay = IO::Socket->new(
    Domain => AF_INET,
    Type => SOCK_STREAM,
    proto => 'tcp',
    PeerPort => $port,
    PeerHost => $host,
) || die "Can't open socket: $IO::Socket::errstr";

   say "relay: connected to $host:$port";

do {
   $relay->recv($data, 1024);
    say "relay: received data: $data";

    $client->send($data);
    $client->recv($data, 1024);
    say "client: received data: $data";
    $relay->send($data);

} until (not defined $relay);
    # notify client that response has been sent
    $client->shutdown(SHUT_WR);
}

$server->close();

close(LOG);
