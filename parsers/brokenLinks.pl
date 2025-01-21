#!/usr/bin/perl -w
package chattyUA;

use Exporter();
use LWP::Parallel::UserAgent qw(:CALLBACK);
@ISA = qw(LWP::Parallel::UserAgent Exporter);
@EXPORT = @LWP::Parallel::UserAgent::EXPORT_OK;

#use IPC::Run qw( run timeout );
use HTTP::Request;
use HTML::Parser ();
use HTML::Tagset ();
use HTML::Element;
use HTML::TreeBuilder;
use HTML::TreeBuilder::Select;
use Carp qw/croak longmess/;

sub runCmd($$;$) {
  my $self = shift;
  die "wtf";
  my ($cmd, $in, $key) = @_;
  if (not defined $key) {
    $key = "key";
  }

  my ($out, $err);
  my @cmd = split(/ /,$cmd);

  #run \@cmd, $in, \$out, \$err, timeout( 10 ) or croak "$cmd: $?";

  #  return join(@$out);

  return $out;
}


=head2 LWP::RobotUA, LWP::Parallel utilize 3 callbacks on_connect, on_failure, on_return
  my ($self, $request, $response, $entry) = @_;
  print "Connecting to ",$request->url,"\n";
}

=cut

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
sub on_return {
  my ($self, $request, $response, $entry) = @_;
  if ($response->is_success) {
    print "Woa! Request to ",$request->url," returned code ", $response->code,
    ": ", $response->message, "\n";
    #    print $response->content;

    my $email = $self->runCmd("parseURL.pl --output=email", $res->decoded_content());
    print "$email\n";

    $parser->parse_content($res->decoded_content()) || croak;
    my @a = $parser->look_down(_tag => 'a');
    foreach my $el (@a) {
      if ($el->tag =~ /^https?/) {
        print "register ".$el->attr('href')."\n";
        if ( my $res = $self->register (HTTP::Request->new(GET=>
              $el->attr('href')
            )) ) { 
          print STDERR $res->error_as_HTML; 
        }
      }
    }
  } else {
    print "\n\nBummer! Request to ",$request->url," returned code ", $response->code,
    ": ", $response->message, "\n";
    # print $response->error_as_HTML;
  }
  return;
}
}

package main;
use warnings;
use strict;

use DBI;
use DBD::CSV;
use LWP;
use LWP::Parallel;
#use LWP::Debug qw(+);
use Data::Dumper;

my $pua = chattyUA->new();
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
        
my $sth = $dbh->prepare ("select website from $filename as csv where char_length(csv.website) > 0");
$sth->execute;
  #        $sth->bind_columns (\my ($a, $b, $c, $d));
my $array = $sth->fetchall_arrayref({});

foreach my $el (@$array) {
  if ( my $res = $pua->register (HTTP::Request->new(GET=>$el->{website})) ) { 
    print STDERR $res->error_as_HTML; 
  }  
}


#
#
my $entries = $pua->wait();

do {
  sleep 1;
} while (1==1);
