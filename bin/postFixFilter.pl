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
use DBI;
use Data::Dumper;
use List::Util qw(shuffle);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Try::Tiny;
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

open(LOG, ">>".$ENV{HOME}."/$logfile") || die "cannot open log";
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
my $sendPerMinute = shift @ARGV || 4;
open(HTML, "<$file") || die "cannot open html [$file]!\n";
local $/;
my $HTML = <HTML>;
close HTML;

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      InactiveDestroy => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";


sub main {
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

