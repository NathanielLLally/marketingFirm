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
use Quotes;
use ParsePURI;
use Sys::Hostname;
use IO::Tee;

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($ENV{HOME}, '.sendmail.conf');
if (not -e $cfgFile) {
	$cfgFile = $ENV{HOME}."/.obiseo.conf";
}
our $CFG = Config::Tiny->read( $cfgFile );

  #  my $smtpserver   = 'smtp-relay.gmail.com';
  #  my $smtpuser     = 'sales@grandstreet.group';
  #  my $smtppassword = 'xmno vbhe bwkx ptgz';

my $logfile = "/home/nathaniel/sendMail.log";
open my $LOG, ">>", $logfile or die "open $logfile failed\n";
my $tee = IO::Tee->new(\*STDOUT, $LOG);
open STDERR, ">&STDOUT";
select $tee;
print `date`;

# create a signer object
sub printUsage
{
  print "$0 cid\n\n";
  exit;
}

my $cid = shift @ARGV || printUsage;
my $sendPerMinute = shift @ARGV || 4;


my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $sth = $dbh->prepare("select basename,content,subject,\"from\",unsubscribe from email_content where id = ?");
$sth->execute($cid);
my $res = $sth->fetchall_arrayref({});
if ($#{$res} < 0) {
  die "no cid [$cid]!!";
}
my $HTML = $res->[0]->{content};
my ($from,$subject,$unsubscribe) = map { $res->[0]->{$_} } qw/from subject unsubscribe/;

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
my $quotes = new Quotes();

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

    if (defined $website and length($website) > 0) {
      my $p = ParsePURI->new();
      $p->parse($website);
      $website = $p->first->{fqdn} || $website;
      $html =~ s/%WEBSITE%/$website/g;
    }

    $html =~ s/%NAME%/$name/g;

    my $quote = $quotes->randomQuote();
    $html =~ s/%QUOTE%/$quote/g;
    print "pid $pid sending $email cid $cid uuid $uuid\t";
  
    #    if (defined $name and length($name) > 0) {
    #      $subject = "$name, do you want more money?"; 
    #    }
    try {
	my ($s,$r) = send_mail($_, $html);
  my $status = $r->{message};
  chomp $status;
  $status =~ s/\s+$//;
  print "$status\n";
  my $qid;
  if ($status =~ /queued as (.*?)$/) {
    $qid = $1;
  }
        my $isth = $dbh->prepare ("update track_email set sent = now(),subject = ?,status = ? where uuid = ?");
        $isth->execute($s, $status, $uuid);
        $isth->finish;

        if (defined $qid) {
          my $isth = $dbh->prepare ("update track_email set qid = ? where uuid = ?");
          $isth->execute($qid, $uuid);
          $isth->finish;
        }
        
    } catch {
	print "failed to send to [$email] $_, defering\n";
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

sub send_mail {
  my ($ctx, $body_text) = @_;
  my ($uuid, $name, $website) = ($ctx->{uuid}, $ctx->{name}, $ctx->{website});


  my $to = Email::Valid->address($ctx->{email});
  if (not defined $to) {
	  printf "invalid email [%s]\n", $ctx->{email};
	  die "invalid email";
  }

  my $ke = sprintf("cid%s",$cid);
  my $unsub = $CFG->{$ke}->{unsubscribe} || $unsubscribe;
  $unsub =~ s/%UUID%/$uuid/;

    my $subj;
    #= "Do you want to advertise for $website?"; 
    $subj = $CFG->{$ke}->{subject} || $subject;
    $subj =~ s/%UUID%/$uuid/g;
    $subj =~ s/%WEBSITE%/$website/g;
    $subj =~ s/%NAME%/$name/g;


    $from = $CFG->{$ke}->{from} || $from;

    if (not defined $from or not defined $subj) {
      die "email missing fields:\nfrom [$from]\nsubject:$subj\nunsubscribe header:$unsub\n"; 
    }

    my $email;
    if ($body_text =~ /<html.*?>/i) {
      $email = Mail::Builder::Simple->new({
          subject => $subj,
          from => $from,
          to => $to,
          htmltext => $body_text,
        });
    } else {
      $email = Mail::Builder::Simple->new({
          subject => $subj,
          from => $from,
          to => $to,
          plaintext => $body_text,
        });
    }
    #printf "smtp config: %s:%s %s %s\n", $CFG->{smtp}->{server}, $CFG->{smtp}->{port}, $CFG->{smtp}->{user}, $CFG->{smtp}->{pass};

    my %opts = (
      mail_client => {
        mailer => 'SMTPS',
        mailer_args => {
          host          => $CFG->{smtp}->{server},
          port          => $CFG->{smtp}->{port},
          ssl           => 1,
          sasl_username => $CFG->{smtp}->{user},
          sasl_password => $CFG->{smtp}->{pass},
          debug => 0
        }
      }
    );
    if (defined $unsub) {
      $opts{'List-Unsubscribe-Post'} = 'List-Unsubscribe=One-Click';
      $opts{'List-Unsubscribe'} = $unsub;
    }

    # get rid of X-Mailer header
    my $res = $email->send( %opts);
    return ($subj,$res);
}

