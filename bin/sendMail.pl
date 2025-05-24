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

my $cid = shift @ARGV;
my $sendPerMinute = shift @ARGV || 4;


my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $sth = $dbh->prepare("select basename,content from email_content where id = ?");
$sth->execute($cid);
my $res = $sth->fetchall_arrayref({});
if ($#{$res} < 0) {
  die "no cid [$cid]!!";
}
my $HTML = $res->[0]->{content};

my $hostname = hostname();

# existing pending emails for this host
#
$sth = $dbh->prepare ("select count(track_email.uuid) from track_email where pending = ? and sent is null and defer is null and cid = ?");
$sth->execute($hostname, $cid);
$res = $sth->fetchall_arrayref();
my $pending = $res->[0]->[0];
my $limit = $sendPerMinute - $pending;

#  mark new emails as pending for this host
#
my $sql = "update track_email set pending = ? where track_email.uuid in (select track_email.uuid from track_email where sent is null and pending is null and defer is null and cid = ? and email not like '%gmail.com' order by random() limit $limit)";

$sth = $dbh->prepare($sql);
$sth->execute($hostname, $cid);

# select all emails pending for this host
#
$sth = $dbh->prepare ("select email,uuid,name,website from track_email where pending = ? and sent is null and defer is null and cid = ?");
$sth->execute($hostname, $cid);
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
    $website = $p->first->{fqdn} || $website;

    $html =~ s/%WEBSITE%/$website/g;
    $html =~ s/%NAME%/$name/g;
    print "pid $pid sending $email cid $cid uuid $uuid\n";
  
    #    if (defined $name and length($name) > 0) {
    #      $subject = "$name, do you want more money?"; 
    #    }
    if (defined $website and length($website) > 0) {
    }
    try {
	my $s = send_my_mail($_, $html);
        my $isth = $dbh->prepare ("update track_email set sent = now(),subject = ? where uuid = ?");
        $isth->execute($s, $uuid);
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
  my ($ctx, $body_text) = @_;
  my ($to_mail_address, $name, $website, $uuid) = ($ctx->{email}, $ctx->{uuid}, $ctx->{name}, $ctx->{website});

  my $to = Email::Valid->address($to_mail_address);
  if (not defined $to) {
	  print "invalid email [$to_mail_address]\n";
	  die "invalid email";
  }

  my $ke = sprintf("cid%s",$cid);
  if (not exists $CFG->{$ke}) {
    die "no config for cid $cid!";
  }
  my $unsub = $CFG->{$ke}->{unsubscribe};
  $unsub =~ s/%UUID%/$uuid/;

    my $subject;
    #= "Do you want to advertise for $website?"; 
    $subject = $CFG->{$ke}->{subject} || 'Hello there, how are you today?';
    $subject =~ s/%UUID%/$uuid/g;
    $subject =~ s/%WEBSITE%/$website/g;
    $subject =~ s/%NAME%/$name/g;

    my $email;
    if ($body_text =~ /\<html\>/i) {
  $email = Mail::Builder::Simple->new({
		  subject => $subject,
		  from => $CFG->{$ke}->{from},
		  to => $to,
		  htmltext => $body_text,
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
      } else {
  $email = Mail::Builder::Simple->new({
		  subject => $subject,
		  from => $CFG->{$ke}->{from},
		  to => $to,
		  plaintext => $body_text,
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
      }


  $email->send(
	'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click',
  	'List-Unsubscribe' => $unsub,
  );
  return $subject;
}

