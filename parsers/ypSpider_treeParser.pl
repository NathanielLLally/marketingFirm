#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use DBD::CSV;
use IPC::Run qw( run timeout );
use LWP;
use LWP::Parallel;
use HTTP::Request;
use URI::Encode;
use URI::Escape;
use Storable qw(retrieve store thaw freeze nfreeze);
#use Data::Serializer;
use JSON;
use Carp qw(croak cluck longmess shortmess);
use Data::Dumper;

#mkdir -p ./data

#https://www.yellowpages.com/search?search_terms=%20Home%20Improvement%20%26%20Remodeling&geo_location_terms=Las%20Vegas%2C%20NV%3Fpage%3D2&page=1

=head2 runCmd(command, input butter, hashKey)
  returns hashref

=cut

my ( %html,%pagesByQuery, $httpResponses, $in, $out, $err) = 
  ({},{}, (undef) x 4);

sub runCmd($$;$) {
  my ($cmd, $in, $key) = @_;
  if (not defined $key) {
    $key = "key";
  }

  my ($out, $err);
  my @cmd = split(/ /,$cmd);

  run \@cmd, $in, \$out, \$err, timeout( 10 ) or croak "$cmd: $?";

  #  return join(@$out);

  return $out;
}

#
#  GLOBALS
#
#################################################
my ($pageTotalN, $pageN, $pageTotal, $DEBUG) = (0,30, 0, 1); 

#my $oDS = Data::Serializer->new();

my $URI = URI::Encode->new( { encode_reserved => 0 } );

#use LWP::Debug qw(+);

my @drivers = DBI->available_drivers;
print join(", ", @drivers), "\n";

my ($dbh, @headers);
my ($cities, $categories, @url);

#my $DSN = 'driver={};server=$server_name;database=$database_name;uid=$database_user;pwd=$database_pass;';

#
#  combinitorics of categpories by cities
#
####################################################3
$dbh = DBI->connect("dbi:CSV:", undef, undef, {
    f_ext => ".list/r",
    RaiseError => 1,
  }) or die "cannot connect: $DBI::errstr";

#        # Simple statements
#        $dbh->do ("CREATE TABLE foo (id INTEGER, name CHAR (10))");

my $sth = $dbh->prepare ("select * from QandACategory");
$sth->execute;
$categories = $sth->fetchall_arrayref();
$sth = $dbh->prepare ("select * from PopularCities");
$sth->execute;
$cities = $sth->fetchall_arrayref();

my ($ciC, $caC) = (0,0);
foreach my $el (@$cities) {
    my $city = uri_escape($el->[0]);
    $ciC = $ciC + 1;
    foreach my $e (@$categories) {
        my $cat = uri_escape($e->[0]);
        $caC = $caC + 1;
        push @url, sprintf("https://www.yellowpages.com/search?search_terms=%s&geo_location_terms=%s&page=%s",$cat, $city, "1");
    }
}
printf("cities: %s, categories: %s, total %s\n", $caC, $ciC, $caC * $ciC);

my $pua = LWP::Parallel::UserAgent->new();
$pua->in_order  (0);  # handle requests in order of registration
$pua->duplicates(1);  # ignore duplicates
$pua->timeout   (10);  # in seconds
$pua->redirect  (1);  # follow redirects


foreach my $k (@url) {
  my $filename = runCmd('parseURL.pl --output=query',\$k);
  chomp $filename;
  chop $filename;
  if (not defined $filename or "$filename" eq "") {
    die "parseURL.pl issue with [$k]";
  }

  if (-e "./data/$filename") {
    $html{$filename} = retrieve("./data/$filename");
  } else {
    $html{$filename} = undef;
  }
}
my @keys = keys %html;

if (not defined $html{$keys[0]}) {
  #
  #  http spider Pass 1 (required for pagination & totals)
  #
  #############################################################

  foreach my $k (@url) {
    print "Registering '".$k."'\n";
    if ( my $res = $pua->register (HTTP::Request->new(GET=>$k)) ) { 
      print STDERR $res->error_as_HTML; 
    }  
    #
    #  output from parseURL  parseURL.pl --output=domain 
    # TODO: add https://data.domainrank.io/outbound_domains?$lookUp  
    #
    #if ( my $res = $pua->register (HTTP::Request->new(GET=>$k)) ) { 
    #  print STDERR $res->error_as_HTML; 
    #}  

    #  TODO: performant 
    #  subclass LWP::Parallel::on_return (save, pua->register paginated url)
    #    ,on_connect,on_error
    #
    #  discover throttling times, order of mag or two more instances
    #

  }

  $httpResponses = $pua->wait();
}
#
#  http spider Pass 2
#
###################################################################

if (defined $httpResponses) {
  foreach (keys %$httpResponses) {
    my $res = $httpResponses->{$_}->response;

    print "Answer for '",$res->request->url, "' was \t", $res->code,"\n";

    #my %hash = 
    my $filename = runCmd('parseURL.pl --output=query',$res->request->url);
    chomp $filename;
    chop $filename;
    my $query =$filename;
    $filename = quotemeta($filename.".html");
    my $sv = $res->decoded_content();

    open(FH, ">./data/$filename") || die "cannot open $filename for write";
    print FH $sv;
    close(FH);

    # pagination values
    # Showing 1-30 of 1963More info

    #  TODO performant performance
    #
    if ($sv =~ /Showing 1\-30 of (\d+)/) {
      $pageTotalN = $1;
      $pageTotal = int($pageTotalN / $pageN)+1;
    }

    foreach my $n (2..$pageTotal) {
      $query =~ s/page=\d+/page=$n/;
      my $url = sprintf("https://www.yellowpages.com/search?%s",$query);

      if ( my $res = $pua->register (HTTP::Request->new(GET=>$url)) ) { 
        print STDERR $res->error_as_HTML; 
      } 
    } 
  } #foreach
  $httpResponses = $pua->wait();
} else {

  foreach my $query (keys %html) {
    my $content =$html{$query};
    if ($content =~ /Showing 1\-30 of (\d+)/) {
      $pageTotalN = $1;
      $pageTotal = int($pageTotalN / $pageN)+1;
    }

    foreach my $n (2..$pageTotal) {
      $query =~ s/page=\d+/page=$n/;
      my $url = sprintf("https://www.yellowpages.com/search?%s",$query);
      $html{$query} = undef;
      print "Registering $url\n";
      if ( my $res = $pua->register (HTTP::Request->new(GET=>$url) )) { 
        print STDERR $res->error_as_HTML; 
      } 
    } 
  }
}

#
#
$httpResponses = $pua->wait();

#  TODO:
#     some markup for an email
foreach (keys %$httpResponses) {
  my $res = $httpResponses->{$_}->response;

  print "Answer for '",$res->request->url, "' was \t", $res->code."\n";

  my $filename = runCmd('parseURL.pl --output=query',$res->request->url);
  chomp $filename;
  chop $filename;
  $filename = quotemeta($filename.".html");
 
  my $sv = $res->decoded_content();

  open(FH, ">./data/$filename") || die "cannot open $filename for write";
  print FH $sv;
  close(FH);
}
