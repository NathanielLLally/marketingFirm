#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature 'isa';

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

use Mail::DKIM::Signer;
use Mail::DKIM::TextWrap;  #recommended

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($dirname, '..','etc','obiseo.conf');
our $CFG = Config::Tiny->read( $cfgFile );

  #  my $smtpserver   = 'smtp-relay.gmail.com';
  #  my $smtpuser     = 'sales@grandstreet.group';
  #  my $smtppassword = 'xmno vbhe bwkx ptgz';

my $logfile = "sendMail.log";

=head2 dont remember easy way to tee

open(LOG, ">$logfile") || die "cannot open log";
open(STDOUT, ">&LOG");
open(STDERR, ">&LOG");
select STDOUT;

=cut

print `date`;

#close(STDOUT);
#close(STDERR);
#open(STDOUT, ">>$logfile");
#open(STDERR,">>$logfile");

# create a signer object
my $dkim = Mail::DKIM::Signer->new(
                Algorithm => 'rsa-sha1',
                Method => 'relaxed',
                Domain => 'grandstreet.group',
                Selector => 'perl',
                KeyFile => '/home/nathaniel/src/git/marketingFirm/etc/dkim_private.pem',
                Headers => 'x-header:x-header2',
           );


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

my $sth = $dbh->prepare ("select count(track_email.uuid) from track_email where pending is not null");
$sth->execute;
my $res = $sth->fetchall_arrayref();
my $pending = $res->[0]->[0];
my $limit = 30 - $pending;

$sth = $dbh->prepare ("update track_email set pending = now() where track_email.uuid in (select track_email.uuid from track_email where sent is null and pending is null limit $limit)");
$sth->execute;
$sth = $dbh->prepare ("select email,uuid,name from track_email where pending is not null");
$sth->execute;
my $batch = $sth->fetchall_arrayref({});


my $threads = ($#{$batch} > 30) ? 30 : $#{$batch};
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
    $html =~ s/%WEBSITE%/$website/g;
    $html =~ s/%NAME%/$name/g;
    print "pid $pid sending $email uuid $uuid\n";
  
    my $subject = "Do you want more money?"; 
    if (defined $name and length($name) > 0) {
      $subject = "$name, do you want more money?"; 
    }
    if (defined $website and length($website) > 0) {
    }
    my $status = send_my_mail($email, $subject, $html, $uuid);

    if (defined $status) {
      if ($status isa "Email::Sender::Success") {
        print "\nstatus: ".Dumper(\$status);
        my $isth = $dbh->prepare ("update track_email set sent = now(),subject = ?, content_url = ? where uuid = ?");
        $isth->execute($subject, $file, $uuid);
        $isth->finish;

        my ($user,$domain) = split(/\@/, $email);
        try {
          $isth = $dbh->prepare ("insert into mx_domain (domain) values (?)");
          $isth->execute($domain);
          $isth->finish;
        } catch {
        };
        try {
          $isth = $dbh->prepare ("insert into mx_email (name,did) select ? as name, did from mx_domain where domain = ?");
          $isth->execute($user,$domain);
          $isth->finish;
        } catch {
        };
      }
      if ($status isa 'Email::Sender::Failure') {
        if ($status isa "Email::Sender::Role::HasMessage") {
          print $status->{message};
        } else {
          print "failed no message\n";
        }
      }
    } else {
      print "\n\n***No status!\n\n";

    }
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

  my $transport = Email::Sender::Transport::SMTPS->new({
    host          => $CFG->{smtp}->{server},
    ssl           => 'starttls',
    port          => $CFG->{smtp}->{port},
    sasl_username => $CFG->{smtp}->{user},
    sasl_password => $CFG->{smtp}->{pass},
    helo => $CFG->{smtp}->{helo},
    debug => 0,
  });

  my $email = Email::MIME->create(
    header_str => [
        To      => $to_mail_address,
        From    => $CFG->{smtp}->{from},
        Subject => $subject,
      'Content-Type' => 'text/html',
      'Message-ID' => "<$uuid\@".$CFG->{smtp}->{helo}.">",
      'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click',
    ],
    attributes => {
      #      encoding => '7bit',
      #      encoding => 'quoted-printable',
      #      charset  => 'US-ASCII',
      encoding => 'base64',
      charset  => 'UTF-8',
    },
    body_str => $body_text,
  );
  $email->header_str_set('List-Unsubscribe' => sprintf("%s%s",$CFG->{smtp}->{unsubscribe},$uuid));
  $email->content_type_set( 'text/html' );
  #  $email->encoding_set( 'base64' ) for $email->parts;
  #  $email->encoding_set( 'base64' ) for $email->body_str;
  #open my $fh, '<', \$email or die "open(): $!";

=head2 attempt DKIM signing.. using google workspace now 

  my $raw = $email->as_string;
  $raw =~ s/\n/\015\012/gs;
  $dkim->PRINT($raw);
$dkim->CLOSE;
my $sig = $dkim->signature;

#$email->header_str_set( 'DKIM-Signature' => $dkim->signature->as_string );
my ($header_name, $header_content) = split /:\s*/, $sig->as_string, 2;
$email->header_str_set( $header_name => $header_content );
unshift @{$email->{Header}}, [ 'List-Unsubscribe', "https://obiseo.net/index.html?unsubscribe=$uuid"];
unshift @{$email->{Header}}, [ $header_name, $header_content ];
print $sig->as_string."\n";

=cut
  #print $email->as_string;

my $status = try_to_sendmail($email, { transport => $transport });
  return $status;
}

