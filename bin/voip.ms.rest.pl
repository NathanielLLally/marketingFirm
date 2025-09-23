#!/usr/bin/perl -w
use strict;
use warnings;
use REST::Client;
use URI::Encode;
use Data::Dumper;
use JSON;
use FindBin;
use File::Spec;
use Time::Piece;

my $URI = URI::Encode->new( { encode_reserved => 0 } );
my $json = JSON->new->allow_nonref;

my $client = REST::Client->new({
        host => 'https://voip.ms'
    });

my %data = (
    api_username => '',
    api_password => '',
);

{
    local $/;
    undef $/;
    my $file = $FindBin::Bin.'/../etc/voip.creds';
    open(FH, $file) || die "cannot open credentials file [$file]";
    my $creds = $json->decode(<FH>);
    close(FH);
    %data = %$creds;
}

my %call = %data;
$call{method} = 'getSMS';
$call{all_messages} = 1;
$call{did} = '7025515025';

%call = %data;
$call{method} = 'getBalance';
$call{advanced} = 1;

%call = %data;
$call{method} = 'getDIDsInfo';


my %call = %data;
$call{method} = 'getSMS';
#$call{all_messages} = 1;
#$call{to} = 'date';
#$call{from} = 'date';
$call{contact} = '6464507917';
#response
$call{type} = 1;
#send
$call{type} = 0;
$call{did} = '7025515025';
my $q = '?'.join ('&', map { sprintf("$_=%s", $URI->encode($call{$_})); } keys %call);

print "query=[$q]\n";
$client->GET("/api/v1/rest.php$q");

my $res = $json->decode($client->responseContent());
if ($res->{status} eq 'success') {
    my @sms = sort {
        Time::Piece->strptime($a->{date}, "%Y-%m-%d %H:%M:%S") <=> Time::Piece->strptime($b->{date}, "%Y-%m-%d %H:%M:%S")
    } @{$res->{sms}};
    print Dumper(\@sms);
}

