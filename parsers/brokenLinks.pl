#!/usr/bin/perl -w
package iRun;
use strict;
use Modern::Perl;

use Try::Tiny;
use IPC::Run qw( run );

sub runCmd($$;$) {
  my ($cmd, $in, $key) = @_;
  if (not defined $key) {
    $key = "key";
  }

  my ($out, $err);
  my @cmd = split(/ /,$cmd);

  try {
    run \@cmd, $in, \$out, \$err, IPC::Run::timeout( 10 ) or die "$cmd: $?";
  } catch {
    warn "[$cmd]: $_"; # not $@
  };

  die "$in need be a ref, no [$out]" unless (defined $out and length($out));
  return $out;
}

package chattyPUA;
use strict;
use Modern::Perl;

use Exporter();
use LWP::Parallel::UserAgent qw(:CALLBACK);
our @ISA = qw(LWP::Parallel::UserAgent Exporter);
our @EXPORT = @LWP::Parallel::UserAgent::EXPORT_OK;

use HTTP::Request;
use HTML::Parser ();
use HTML::Tagset ();
use HTML::Element;
use HTML::TreeBuilder;
use HTML::TreeBuilder::Select;
use Carp qw/croak longmess/;
use Moose;
use Try::Tiny;
use DBI;
use DBD::CSV;
use Data::Dumper;

# col_names
# skip_first_row
#

has '_level' => (is => 'rw', isa => 'Num', default => 0);

has '_sites' => (
  traits  => ['Hash'],
  is      => 'ro',
  isa     => 'HashRef[Str]',
  #  default => sub { {} },
  handles => {
    wsrefcount => 'values',
    websites => 'keys',
    total_websites => 'count',
    get_website => 'get',
    add_website => 'set',
  },  
);

has '_sites_out' => (
  traits  => ['Hash'],
  is      => 'ro',
  isa     => 'HashRef[Str]',
  #  default => sub { {} },
  handles => {
    outbound_links => 'keys',
    outbound_total => 'count',
    siteFromLink => 'get',
    setLink => 'set',
    siteExists => 'exists'
  },  
);

=head2 LWP::RobotUA, LWP::Parallel utilize 3 callbacks on_connect, on_failure, on_return

=cut


sub on_connect {
  my ($self, $request, $response, $entry) = @_;

  #  print "Connecting to ",$request->url,"\n";

}

sub on_failure {
  my ($self, $request, $response, $entry) = @_;
  print "Failed to connect to ",$request->url,"\n\t",
  $response->code, ", ", $response->message,"\n"
  if $response;
}

# on_return gets called whenever a connection (or its callback)
# returns EOF (or any other terminating status code available for
# callback functions). Please note that on_return gets called for
# any successfully terminated HTTP connection! This does not imply
# that the response sent from the server is a success! 

#our $parser = new HTML::TreeBuilder::Select; 

{
  our $parser = new HTML::TreeBuilder::Select; 
  my $dbh = DBI->connect("dbi:CSV:", undef, undef, {
    f_ext => ".csv/r",
    f_dir => 'data',
    RaiseError => 1,
    #    AutoCommit => 1,
  }) or die "cannot connect: $DBI::errstr";

  try {
    $dbh->do ("CREATE TABLE email (email VARCHAR (1000), website VARCHAR (1000))");
  } catch {
  };

  sub on_return {
    my ($self, $request, $response, $entry) = @_;
    if ($response->is_success) {
      #print "Woa! Request to ",$request->url," returned code ", $response->code, ": ", $response->message, "\n";

#      my $website = $self->runCmd("parseURL.pl --output=scheme --output=fqdn --output=path --output=query", $request->url);
#    chomp $website;
      
      #  using fqdn/path only to match with chattyPUA::register
      #    this handles errant formatting and redirects
      #

      my $website;
      try {
        $website= iRun::runCmd("parseURL.pl --output=fqdn --output=path", $request->url);
        chomp $website;
      } catch {
        print "ERROR: ".$request->url."\n";
        return;
      };

      print "=>".$request->url."\n";
      print "=>[$website]\n";
      foreach my $ol ($self->outbound_links) {
        print "$ol\n";
      }

      #
      #  parse for email
      #######################

      # mailto:
      #      my $email = $self->runCmd("parseURL.pl --output=email", $response->decoded_content());
      #if (defined $email) {
      #  print "\n\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\nWholly mailto: link batman!:: $email\n";
      #}

      #  re-entrance logic
      #
      $parser->parse_content($response->decoded_content()) || croak;
      my @a = $parser->look_down(_tag => 'a');
      foreach my $el (@a) {
        #print $el->tag."\n";
        if ($el->attr('href') =~ /^https?/) {

          $self->setLink($request->url() => $website);
          print "register ".$el->attr('href')."\n";

          # if ($self->outbound_total => 'count',

          if ( my $res = $self->register (HTTP::Request->new(GET=>
                $el->attr('href')
              )) ) { 
            #print STDERR $res->error_as_HTML; 
          }
        } elsif ($el->attr('href') =~ /^((mailto:)?\s?(.*?\@.*?\.\w+))/) {
          my $email = "mailto:$3";
          print "\n\nwholly email batman, [$email]\n";

          my $sth = $dbh->prepare ("select email from email where website = ?");
          $sth->execute($website);
          my $array = $sth->fetchall_arrayref({});
          print Dumper(\$array);
          if ($#{$array} > -1) {
            my $sth = $dbh->prepare ("UPDATE email SET email = ? WHERE website = ?");
            if ($array->[0]->{email} !~ /$email/) {
              $sth->execute (join("|",$array->[0]->{email},$email), $website);
            }
            $sth->finish;
          } else {
            my $sth = $dbh->prepare ("INSERT into email (email,website) values (?,?)");
            $sth->execute ($email, $website);
            $sth->finish;
          }
        }
      }

    } else {
      print "! Request to ",$request->url," returned code ", $response->code, ": ", $response->message, "\n";
      # print $response->error_as_HTML;
    }
    return;
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

package main;
use warnings;
use strict;
use Modern::Perl;
use Try::Tiny;
use DBI;
use DBD::CSV;
use LWP;
use LWP::Parallel;
#use LWP::Debug qw(+);
use Data::Dumper;

my $pua = chattyPUA->new();
$pua->in_order  (0);  # handle requests in order of registration
$pua->duplicates(1);  # ignore duplicates
$pua->timeout   (10);  # in seconds
$pua->redirect  (1);  # follow redirects

my $filename = shift @ARGV;
my ($dbh, @headers);
$filename =~ s/\.csv//;

#my $DSN = 'driver={};server=$server_name;database=$database_name;uid=$database_user;pwd=$database_pass;';
$dbh = DBI->connect("dbi:CSV:", undef, undef, {
    f_ext => ".csv/r",
    f_dir => 'data',
    RaiseError => 1,
  }) or die "cannot connect: $DBI::errstr";

#        # Simple statements
#        $dbh->do ("CREATE TABLE foo (id INTEGER, name CHAR (10))");
#
my $sth = $dbh->prepare ("select website from $filename as csv where char_length(csv.website) > 0");
$sth->execute;
#     $sth->bind_columns (\my ($a, $b, $c, $d));
my $array = $sth->fetchall_arrayref({});


my $count = 0;
foreach my $el (@$array) {
  #print $el->{website}."\n";
  $count += 1;
}

print "websites in csv $count\n";

my @batch;
  while (@batch = splice(@$array,0,1000)) {
  foreach my $el (@$array) {
    my ($csvData,$website) = ($el->{website}, undef);

    #  using fqdn/path only to match with chattyPUA::on_return
    #
    try {
      $website = iRun::runCmd("parseURL.pl --output=fqdn --output=path", \$csvData);
      chomp $website;
    } catch {
      print "ERROR: register: main ".$csvData."\n";
      next;
    };

    #print "FIXME finish parsePURI.p[ml] [$csvData] => [$website]\n";

    #print "-->$csvData\n";
    print ".";
    $pua->setLink($csvData => $csvData);

    if ( my $res = $pua->register (HTTP::Request->new(GET=>$csvData)) ) { 
      #print STDERR $res->error_as_HTML; 
    }  
  }

  my $entries = $pua->wait();
};
#
#
#
#do {
#  print "wait()\n";
#  my $entries = $pua->wait();
#  sleep 1;
#} while (1==1);

