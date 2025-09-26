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
use DBI;

our $DEBUG = 0;

my $dbh = DBI->connect('dbi:Pg:dbname=postgres;host=127.0.0.1', 'postgres', undef, {
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 1,
  }) or die "cannot connect: $DBI::errstr";


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


%call = %data;
$call{method} = 'getSMS';
$call{all_messages} = 1;
#$call{to} = 'date';
#$call{from} = 'date';
#$call{contact} = '6464507917';
#$call{did} = '7025515025';
#response
#$call{type} = 1;
#send
#$call{type} = 0;

sub restCall {
    my %data = @_;
    my $q = '?'.join ('&', map { sprintf("$_=%s", $URI->encode($data{$_})); } keys %data);
    print "query=[$q]\n" if ($DEBUG);
    $client->GET("/api/v1/rest.php$q");
    my $res = $json->decode($client->responseContent());
    $res;
}

my $res = restCall(%call);
if ($res->{status} eq 'success') {
    my @sms = sort {
        Time::Piece->strptime($a->{date}, "%Y-%m-%d %H:%M:%S") <=> Time::Piece->strptime($b->{date}, "%Y-%m-%d %H:%M:%S")
    } @{$res->{sms}};

    if ($#sms > -1) {
=head2 ascii table output.. dont do it just use dB

        my @keys = sort keys %{$sms[0]};
        my @rows = map { my @row; foreach my $k (@keys) { push @row, $_->{$k}}; @row } @sms;
        print Dumper(\@rows);
        my $tb = Text::Table->new(@keys);
        $tb->load(@rows);
        print $tb;
=cut

        foreach my $sms (@sms) {
            print Dumper($sms)."\n";
            #            $dbh->prepare('insert into voip.
            if ($#{$sms->{media}} > -1) {
                my $count = 1;
                foreach my $url (@{$sms->{media}}) {
                    print "$url\n";
                    my $extension = "unknown";
                    if (reverse($url) =~ /(.*?)\./) {
                        $extension = reverse($1);
                    }
                    print "$extension\n";
                    $client->GET("/$url");
                    my $res = $client->responseContent();
                    my $id = $sms->{id};
                    open(FH, ">sms.$id.$count.$extension") || die "cannot open media file for output";
                    binmode FH;
                    print FH $res;
                    close(FH);
                    $count+=1;
                }
                #%call = %data;
                #$call{method} = 'getMediaMMS';
                #$call{id} = $sms->{id};
            }
        }
    }
} elsif ($res->{status} eq 'no_sms') {
    #    print "none";
} else {
    print Dumper(\$res);
}

