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
use Storable qw(store thaw freeze nfreeze);
use Data::Serializer;
use JSON;
use Carp qw(croak cluck longmess shortmess);

my $oDS = Data::Serializer->new();

=head2
                        serializer => 'Storable',
                        digester   => 'MD5',
                        cipher     => 'DES',
                        secret     => 'my secret',
                        compress   => 1,
                      );

=cut

my $URI = URI::Encode->new( { encode_reserved => 0 } );

#use LWP::Debug qw(+);
use Data::Dumper;

my @drivers = DBI->available_drivers;
print join(", ", @drivers), "\n";

my ($dbh, @headers);
my ($cities, $categories, @url);

#my $DSN = 'driver={};server=$server_name;database=$database_name;uid=$database_user;pwd=$database_pass;';
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

#https://www.yellowpages.com/search?search_terms=%20Home%20Improvement%20%26%20Remodeling&geo_location_terms=Las%20Vegas%2C%20NV%3Fpage%3D2&page=1


my $pua = LWP::Parallel::UserAgent->new();
$pua->in_order  (0);  # handle requests in order of registration
$pua->duplicates(1);  # ignore duplicates
$pua->timeout   (20);  # in seconds
$pua->redirect  (1);  # follow redirects

my @u = ();
push @u, $url[0];

foreach my $k (@u) {
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
}
my $entries = $pua->wait();


=head2 runCmd(command, input butter, hashKey)
  returns hashref

=cut

my (%pagesByQuery,$in, $out, $err);

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


foreach (keys %$entries) {
    my $res = $entries->{$_}->response;

    print "Answer for '",$res->request->url, "' was \t", $res->code,"\n";

    #my %hash = 
    my $filename = runCmd('parseURL.pl --output=query',$res->request->url);
    chomp $filename;
    chop $filename;
    $filename = quotemeta($filename.".stobj");
    my $sv = $res->decoded_content();
    my @cmd = qw(html5debug);
    #my $out = runCmd("html5debug --output=parser:json", \$sv);
    my $out = runCmd("html5debug", \$sv);

    print "[$filename]\n";

    #{root{attributes[{}],children[{

    my $h = decode_json($out);
    print Dumper($h->{root}->{children});
    exit;
    my $svH = $oDS->deserialize($out);
    print Dumper(\$svH);


    store \$out, "./data/$filename";
    #my %hash = ($out);
    #print Dumper(\%hash);
exit;

=head2 

        while ($line =~ /(.*?)\n/gmc) {
            my $link = $1;

            #TODO pagination

            if ( my $res = $pua->register (HTTP::Request->new(GET=>$link)) ) { 
                print STDERR $res->error_as_HTML; 
            }  
        }
=cut

}

exit;

#
#
#
$entries = $pua->wait();

#  TODO:
#     some markup for an email
foreach (keys %$entries) {
  my $res = $entries->{$_}->response;

  print "Answer for '",$res->request->url, "' was \t", $res->code;

  #$linktreeByWebsite{ $websiteByLink{$res->request->url} }{$res->request->url} = $res->code;

}

$dbh->disconnect;
