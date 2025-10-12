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
use Getopt::Long::Descriptive;
use Text::ANSITable;
use LWP::ConsoleLogger::Easy qw( debug_ua );

our $DEBUG = 0;

my ($mode, $did, $contact, $message, @media) = ('check', '7025515025', '6464507917', undef);
my ($opt, $usage) = describe_options(
    'voip.ms %o <some-arg>',
        [ 'mode' => hidden => { one_of => [
                    ["send|s" => 'send a sms message' ],
                    ["test|t" => 'send a test sms message', { implies => {'contact' => '6464507917', 'message' => 'test message' }} ],
                    ['poll|p' => 'check for sms messages'],
                    ['info|i' => 'list out various account info'],
                ] } ],
        [ 'message|m=s',  "message to send", { implies => {'mode' => 'send'}  } ],
        [ 'media=s',  "media file to attach", { implies => {'mode' => 'send'}  } ],
        [ 'did=s',   "did # to use",   { default  => '7025515025' } ],
        [ 'contact|c=s',   "contact # to use",   { default  => '6464507917' } ],
        [],
        [ 'verbose|v',  "print extra stuff"            ],
        [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
);

#my ($opt, $usage) = describe_options(
#    'my-program %o <some-arg>',
#["send|s" => 'send a sms message' => { implies => [qw(contact message)]}],


print($usage->text), exit if ($opt->help or not exists $opt->{mode});

if (exists $opt->{verbose}) {
  $DEBUG = 1; 
}
if ($opt->{mode} eq 'send') {
    if (not exists $opt->{message}) {
        print ($usage->text);
        print "message required for send mode\n";
        exit;
    }
}

my $dbh = DBI->connect('dbi:Pg:dbname=postgres;host=127.0.0.1', 'postgres', undef, {
    RaiseError => 1, PrintError => 0, AutoCommit => 1, }
    ) or die "cannot connect: $DBI::errstr";


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
#$call{to} = 'date';
#$call{from} = 'date';
#$call{contact} = '6464507917';
#$call{did} = '7025515025';
#response
#$call{type} = 1;
#send
#$call{type} = 0;


if ($opt->{mode} eq 'poll') {
    $call{method} = 'getSMS';
    $call{all_messages} = 1;
} elsif ($opt->{mode} eq 'send' or $opt->{mode} eq 'test') {
    #  voip.ms character length on SMS is 160
    #  2048 for MMS
    #
    if (exists $opt->{media} or length($opt->{message}) > 160) {
        $call{method} = 'sendMMS';
        $call{media1} = $opt->{media};
        $call{media2} = 'sendMMS';
        $call{media3} = 'sendMMS';
    } else {
        $call{method} = 'sendSMS';
    }
    $call{did} = $opt->{did};
    $call{dst} = $opt->{contact};
    $call{message} = $opt->{message};
} elsif ($opt->{mode} eq 'info') {
  %call = %data;
  $call{method} = 'getBalance';
  $call{advanced} = 1;
  my $res = restCall(%call);
  print parseResponse($res, 'balance');

  %call = %data;
  $call{method} = 'getDIDsInfo';
  $res = restCall(%call);
  #billing_type ┃ callerid_prefix ┃ cnam ┃  description   ┃ dialmode ┃ dialtime ┃    did     ┃ e911 ┃ failover_busy ┃ failover_noanswer ┃ failover_unreachable ┃ inbound_dialing_mode ┃ mms_available ┃ next_billing ┃ note ┃     order_date      ┃ pop ┃ port_out_pin ┃ record_calls ┃ reseller_account ┃ reseller_minute ┃ reseller_monthly ┃ reseller_next_billing ┃ reseller_setup ┃  routing  ┃ smpp_enabled ┃ smpp_pass ┃ smpp_url ┃ smpp_user ┃ sms_available ┃   sms_email    ┃ sms_email_enabled ┃ sms_enabled ┃ sms_forward ┃ sms_forward_enabled ┃ sms_sipaccount ┃ sms_sipaccount_enabled ┃ sms_url_callback ┃ sms_url_callback_enabled ┃ sms_url_callback_retry ┃ transcribe ┃ transcription_email ┃ transcription_locale ┃ transcription_redaction ┃ transcription_sentiment ┃ transcription_start_delay ┃ transcription_summary ┃ voicemail ┃ voicemail_threshold ┃ webhook ┃ webhook_enabled ┃
  #
  my $keys = [qw/callerid_prefix description did/];
  print parseResponse($res, 'dids', $keys);

}

sub prettyDump
{
  my $el = shift;
  my $keys = shift;
  my $t = Text::ANSITable->new;
  $t->border_style('UTF8::SingleLineBold');  # if not, a nice default is picked
  $t->color_theme('Data::Dump::Color::Light');  # if not, a nice default is picked
  $t->{header_bgcolor} = '000000';
  $t->{header_fgcolor} = 'ffffff';
  $t->{header_align} = 'middle';

  if (ref($el) eq 'HASH') {
    my @keys = sort keys %$el;
    if (defined $keys) {
      @keys = @{$keys};
    }
    $t->columns([@keys]);
    my @vals = map {$el->{$_};}@keys;
    $t->add_row([@vals]);
  }
  if (ref($el) eq 'ARRAY') {
    my @keys = sort keys %{$el->[0]};
    if (defined $keys) {
      @keys = @{$keys};
    }
    $t->columns([@keys]);
    foreach my $ele (@{$el}) {
      my @vals = map {$ele->{$_};}@keys;
      $t->add_row([@vals]);
    }
  }
  return $t->draw;
}

sub parseResponse
{
  my ($res,$key,$keys) = @_;
  if ($res->{status} eq 'success') {
    my $el = $res->{$key};
    return prettyDump($el,$keys);
  } else {
    return Dumper(\$res);
  }

}

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
    if ($opt->{mode} eq 'poll') {
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
    } elsif ($opt->{mode} eq 'send') {
    }
} else {
    print Dumper(\$res);
}

