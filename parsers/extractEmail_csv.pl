#!/usr/bin/perl -w
package iRun;
use strict;
use Modern::Perl;

use Try::Tiny;
use IPC::Run qw( run );
use Carp;

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

  croak "$in need be a ref, no [$out]" unless (defined $out and length($out));
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

=head2  chattyPUA parallel user agent subclass
 
  no outbound links (see name of file) 

=cut

# col_names
# skip_first_row
#

# attributes

has 'remainingURLs' => (is => 'rw', 'isa' => 'Num', lazy => 1, default => 0);
has 'totalURLs' => (is => 'rw', 'isa' => 'Num', lazy => 1, default => 0);
has 'batchCount' => (is => 'rw', 'isa' => 'Num', default => 1000);

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

has 'dbgLevel' => (is => 'rw', isa => 'Num', default => 0);

sub debug {
	my ($self, $fmt, @v) = @_;


	if ($self->dbgLevel > 0) {
		printf($fmt,@v);
	}
}


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
	`rm data/email.csv`;	
    $dbh->do ("CREATE TABLE email (email VARCHAR (1000), website VARCHAR (1000))");
	`rm data/unique_email.csv`;	
    $dbh->do ("CREATE TABLE unique_email (email VARCHAR (1000), website VARCHAR (1000))");
  } catch {
  };

=head2 chattyPUA::stats  compile stats of the following:

      # list of entries
    $self->{'entries_by_sockets'} = {};   
    $self->{'entries_by_requests'} = {};

    $self->{'previous_requests'}  = {};

    # connection handling
    $self->{'current_connections'} = {}; # hash
    $self->{'pending_connections'} = {}; # hash (of [] arrays)
    $self->{'ordpend_connections'} = []; # array
    $self->{'failed_connections'}  = {}; # hash

    # duplicates
    $self->{'seen_request'} = {};

    # select objects for reading & writing
    $self->{'select_in'} = IO::Select->new();
    $self->{'select_out'} = IO::Select->new();

=cut

sub stats {
    my ($self) = @_;
	my $out = sprintf("URLs-> total: %u remaining: %u connections-> current: %u pending: %u failed: %u\n",
		$self->totalURLs,
		$self->remainingURLs,
		scalar keys %{$self->{'current_connections'}},
		scalar keys %{$self->{'pending_connections'}},
		scalar keys %{$self->{'failed_connections'}}
	);
	return $out;
}

=head2 chattyPUA::on_return

  html::treebuilder  ->  a attr-> href  /scheme/ & keywords
  output: csv 

=cut

  sub on_return {
	  
	no warnings;
    my ($self, $request, $response, $entry) = @_;

	print $self->stats();

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
		$website =~ s/\/$//;
      } catch {
        print "ERROR: ".$request->url."\n";
        return;
      };

      print "=> request url [".$request->url."] =>[$website]";
	  #      foreach my $ol ($self->outbound_links) {
	  #        print "$ol\n";
	  #      }

	  #$website = iRun::runCmd("parseURL.pl --output=fqdn", $request->url);
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
		my $url = lc($el->attr('href'));
        if (
			($url =~ /^https?/) &&
			($url =~ /(about|contact|us|facebook)/)
		) {

          $self->setLink($request->url() => $website);


	      #!! no CORS!!!
          my $outbound = iRun::runCmd("parseURL.pl --output=fqdn", \$url);
		  $outbound =~ s/\/$//;

		  #  url is internal, same domain
		  #
		  if ($website =~ /$outbound/) {
			  $outbound = undef;
			  $self->debug("\n\tregister internal link%s\t",$url);
			  if ($self->dbgLevel <= 0) {
				  print ".";
			  }
		  } else {
			#chatty about the outbound url 
		  }

		  if ( my $res = $self->register (HTTP::Request->new(GET=>
					  $el->attr('href')
				  )) ) { 
				  #print STDERR $res->error_as_HTML; 
			  }
        } elsif ($el->attr('href') =~ /^((mailto:)?\s?(.*?\@.*?\.\w+))/) {
			#mailto: might be responsible for breaking crm import

          my $email = "$3";
          print "wholly email batman, [$email]\n";

		  #print Dumper(\$array);
		  my $sth = $dbh->prepare ("INSERT into unique_email (email,website) values (?,?)");
		  $sth->execute ($email, $website);
		  $sth->finish;

          my $sth = $dbh->prepare ("select email from email where website = ?");
          $sth->execute($website);
          my $array = $sth->fetchall_arrayref({});
		  #print Dumper(\$array);
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
	use warnings;
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


my $begin =  join '', "$0 ",@ARGV," at ", scalar localtime(), "\n";

$SIG{HUP} = sub {
	print "process began @\t$begin\n";
	print  "\t\t\t".join '', "$0 @ARGV at ", scalar localtime(), "\n";
};


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
# make csv for importing into postgres
# also must use iconv to convert to UTF8
my $sth = $dbh->prepare ("select address,city,email,name,phone,state,tags,website,zip from $filename as csv where char_length(csv.website) > 0");
#my $sth = $dbh->prepare ("select website from $filename as csv where char_length(csv.website) > 0");
$sth->execute;
#     $sth->bind_columns (\my ($a, $b, $c, $d));
my $array = $sth->fetchall_arrayref({});

open(T, ">pages_sites.csv");
#"Address,City,Email,Name,Phone,State,Tags,Website,Zip"
foreach my $el (@$array) {
  if (exists $el->{tags} and exists $el->{zip}) {
    printf T '"%s","%s","%s","%s","%s","%s","%s","%s","%s"'."\n",
      $el->{address}, $el->{city}, $el->{email},$el->{name},$el->{phone},$el->{state},$el->{tags},$el->{website},$el->{zip};
    }
}
close(T);
exit;

my $count = 0;
my @rows;
foreach my $el (@$array) {
	push @rows, $el->{website};
  $count += 1;
}

my $pua = chattyPUA->new();
$pua->in_order  (0);  # handle requests in order of registration
$pua->duplicates(1);  # ignore duplicates
$pua->timeout   (2);  # def 2 in seconds
$pua->delay(5); # def 5
$pua->max_req(5); #def 5
$pua->max_hosts(100); #def 7
$pua->remember_failures(1); #def off
$pua->redirect  (1);  # follow redirects
$pua->dbgLevel(1);
$pua->totalURLs($count);
$pua->remainingURLs($count);
$pua->batchCount(20);

$SIG{HUP} = sub {
	print "process began @\t$begin\n";
	print  "\t\t\t".join '', "$0 $$: @_ at ", scalar localtime(), "\n";
	print "where batch is: $#{$array}\n"; 
	print "[total records=>\nwc -l ./data/$filename.csv\nurls in csv $count\n";
};

print "websites in csv $count\n";

my @batch;
while (@batch = splice(@rows,0,$pua->batchCount())) {
	print "process began @\t$begin";
	print  "\t\t\t\t\t".join '', scalar localtime(), "\n";
	printf "batch size %u rows %u\n",$#batch+1,$#rows+1;

	#TODO: dump rows into PUA class
	$pua->remainingURLs($#rows+1);

	#	print join("\n", @batch)."\n";

  foreach (@batch) {
    my ($csvData,$website) = ($_, undef);

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
	print "[total records=>\nwc -l ./data/$filename.csv\nurls input csv ^_^ :$count\n";
	my $entries = $pua->wait();
	print "waited\n";
};
#
#

print "[total records=>\nwc -l ./data/$filename.csv\nurls in csv $count\n";

#do {
#  print "wait()\n";
#  my $entries = $pua->wait();
#  sleep 1;
#} while (1==1);

