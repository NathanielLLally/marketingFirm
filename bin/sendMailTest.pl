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
use lib '/home/nathaniel/src/git/marketingFirm/lib';
use ParsePURI;

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

my $file = shift @ARGV;
open(HTML, "<$file") || die "cannot open html [$file]!\n";
local $/;
my $HTML = <HTML>;
close HTML;


	   my $Pemail = shift @ARGV || 'nate.lally@gmail.com';

    my ($email, $uuid, $name, $website) = ($Pemail, '123455', 'Nate', 'http://OBIseo.net');


    my $html = $HTML;
    $html =~ s/%UUID%/$uuid/g;

    my $p = ParsePURI->new();
    $p->parse($website);
    $website = $p->first->{fqdn};

    $html =~ s/%WEBSITE%/$website/g;
    $html =~ s/%NAME%/$name/g;
    $html =~ s/%EMAIL%/$email/g;
    print "sending $email uuid $uuid\n";
  
    my $subject = "Do you want to advertise for $website?"; 
    #    if (defined $name and length($name) > 0) {
    #      $subject = "$name, do you want more money?"; 
    #    }
    my $status = send_my_mail($email, $subject, $html, $uuid);

    if (defined $status) {
      if ($status isa "Email::Sender::Success") {
        print "\nstatus: ".Dumper(\$status);

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
  $email->header_str_set('List-Unsubscribe' => "https://obiseo.net/index.html?unsubscribe=$uuid");
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

