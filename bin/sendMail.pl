#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature 'isa';

use Mail::Builder::Simple;
use Email::Sender::Simple qw(sendmail try_to_sendmail);
use Email::Sender::Transport::SMTPS;
use Email::Simple ();
use Email::Simple::Creator ();
use Email::MIME;
use Parallel::ForkManager;
use DBI;
use Data::Dumper;
use List::Util qw(shuffle);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Try::Tiny;
use lib '/home/nathaniel/src/git/marketingFirm/lib';
use ParsePURI;
use Sys::Hostname;

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
if (not -e $cfgFile) {
	$cfgFile = $ENV{HOME}."/.obiseo.conf";
}
our $CFG = Config::Tiny->read( $cfgFile );

  #  my $smtpserver   = 'smtp-relay.gmail.com';
  #  my $smtpuser     = 'sales@grandstreet.group';
  #  my $smtppassword = 'xmno vbhe bwkx ptgz';

my $logfile = "sendMail.log";

open(LOG, ">>/home/nathaniel/$logfile") || die "cannot open log";
open(STDOUT, ">&LOG");
open(STDERR, ">&LOG");
select STDOUT;

print `date`;

#close(STDOUT);
#close(STDERR);
#open(STDOUT, ">>$logfile");
#open(STDERR,">>$logfile");

# create a signer object

my $file = shift @ARGV;
open(HTML, "<$file") || die "cannot open html [$file]!\n";
local $/;
my $HTML = <HTML>;
close HTML;


my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $hostname = hostname();
my $sth = $dbh->prepare ("select count(track_email.uuid) from track_email where pending = ? and sent is null and defer is null");
$sth->execute($hostname);
my $res = $sth->fetchall_arrayref();
my $pending = $res->[0]->[0];
my $limit = 5 - $pending;

$sth = $dbh->prepare ("update track_email set pending = ? where track_email.uuid in (select track_email.uuid from track_email where sent is null and pending is null and email not like '%gmail.com' and random() < 0.001 limit $limit)");
$sth->execute($hostname);
$sth = $dbh->prepare ("select email,uuid,name,website from track_email where pending = ? and sent is null and defer is null");
$sth->execute($hostname);
my $batch = $sth->fetchall_arrayref({});


#my $threads = ($#{$batch} > 30) ? 30 : $#{$batch};
my $threads = 0;
if ($threads < 0) {
  print "no pending emails\n";
  exit;
}
print "using $threads threads\n";
my $pm = Parallel::ForkManager->new($threads);

do {

  print "pending emails: ".$#{$batch}."\n";
  my @random = shuffle @$batch;

  LOOP:
  foreach (@random) {
    my ($email, $uuid, $name, $website) = ($_->{email}, $_->{uuid}, $_->{name}, $_->{website});

    my $pid = $pm->start and next LOOP; #do the fork

    if ($#{$batch} >= 0) {

    my $html = $HTML;
    $html =~ s/%UUID%/$uuid/g;

    my $p = ParsePURI->new();
    $p->parse($website);
    $website = $p->first->{fqdn};

    $html =~ s/%WEBSITE%/$website/g;
    $html =~ s/%NAME%/$name/g;
    print "pid $pid sending $email uuid $uuid\n";
  
    my $subject = "Do you want to advertise for $website?"; 
    #    if (defined $name and length($name) > 0) {
    #      $subject = "$name, do you want more money?"; 
    #    }
    if (defined $website and length($website) > 0) {
    }
    try {
	send_my_mail($email, $subject, $html, $uuid);
        my $isth = $dbh->prepare ("update track_email set sent = now(),subject = ?, content_url = ? where uuid = ?");
        $isth->execute($subject, $file, $uuid);
        $isth->finish;
    } catch {
	print "failed to send to [$email], defering\n";
        my $isth = $dbh->prepare ("update track_email set defer = now() where uuid = ?");
        $isth->execute($uuid);
        $isth->finish;
    };

  }

    $pm->finish; #exit in child process
  }

  $sth->execute;
  $batch = $sth->fetchall_arrayref({});
} while ($#{$batch} > -1);

$pm->wait_all_children;

$dbh->disconnect;

exit;

sub send_my_mail {
  my ($to_mail_address, $subject, $body_text, $uuid) = @_;

  my $to = Email::Valid->address($to_mail_address);
  if (not defined $to) {
	  print "invalid email [$to_mail_address]\n";
	  die "invalid email";
  }

  my $email = Mail::Builder::Simple->new({
		  subject => $subject,
		  from => $CFG->{smtp}->{from},
		  to => $to,
		  htmltext => $body_text,
		  image => [
	  ["/home/nathaniel/src/git/marketingFirm/www/img/obiseo_header_logo_transparent.png", 'logo'],
	  ["/home/nathaniel/src/git/marketingFirm/www/img/obiseo_letterhead_tag_transparent.png", 'tag'],
	  ["/home/nathaniel/src/git/marketingFirm/www/img/lineshadow.png", 'lineshadow'],
		  ],
		  mail_client => {
			  mailer => 'SMTPS',
			  mailer_args => {
    host          => $CFG->{smtp}->{server},
    ssl           => 'starttls',
    port          => $CFG->{smtp}->{port},
    sasl_username => $CFG->{smtp}->{user},
    sasl_password => $CFG->{smtp}->{pass},
    debug => 0
		  }
	  }
	  });
  $email->send(
	'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click',
  	'List-Unsubscribe' => "https://obiseo.net/index.html?unsubscribe=$uuid"
  );
}

