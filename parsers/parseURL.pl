#!/usr/bin/perl

use strict;
use warnings;

use URI::Find;
use URI;
use URI::Encode;
use URI::Escape;
#use URI::Info;
use URI::Simple;
use Data::Dumper;
use Getopt::Long;
use Tie::IxHash;

my %url;
my %urlParts;

my $URI = URI::Encode->new( { encode_reserved => 0 } );

#$SIG{__DIE__} = sub {
#  print "die hook\n";
  #exit;
  #};

my ($Pverbose, $Pcount, $Phelp, $Pfile, @Poutput) = ((undef) x 3, '' x 1);
GetOptions ("count" => \$Pcount, 
  "file=s" => \$Pfile,
  "output=s" => \@Poutput,
  "verbose" => \$Pverbose,
  "help" => \$Phelp
);

if (defined $Phelp) {
 print "output (url,fqdn,query,params,path,scheme)\n";
 exit;
}

my $file = $Pfile;
my $FD = *STDIN;

if (defined $file and -e "$file") {
  open($FD, "<$file") || die "cannot open $file";
}

local $/;
undef $/;

my $text = <$FD>;
#print "$text\n";


#my $uriInfo = URI::Info->new();
my $finder = URI::Find->new(
        sub {
            my ($uri) = shift;
            #            my $u = URI->new(
            #            my $nfo = $uriInfo->info($uri); 
            #print "$uri\n";
            #$uri =~ /(.*?)\,/;
            #print "$1\n";

            $url{uri_unescape($uri)}++;
            #            $url{$nfo->host}++;
            #            print $nfo->host."\n";
        }
);


print $finder->uri_re."\n".$finder->schemeless_uri_re."\n" if (defined $Pverbose);

my $count = $finder->find(\$text);

print "output=".Dumper(\@Poutput)."\n" if (defined $Pverbose);

foreach my $k (keys %url) {

  #  if ($k =~ /(https?:\/\/)([\w\-\.]+)((\/.*?)(\?.*?))?/) {
  #
  #  see URI pod, section PARSING URIs WITH REGEXP
  #
     if ($k =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|) {
       $urlParts{$k} = {
         scheme => $1, 
         authority => $2,  fqdn => $2, 
         path => $3, 
         query => $4, 
         fragment => $5, 
         url => $k
       };
       my $q = $4;
       my $u = URI->new($k);

       # TODO: HACK - bitch at them or submit a patch
       #
       #Copyright 1995-2009 Gisle Aas.
       #Copyright 1995 Martijn Koster.
       #
       #  libwww-perl
       #
       $urlParts{$k}{'paramk'} = ();
       my %p;
       tie %p, 'Tie::IxHash';
       my @keys = $u->query_param;
       foreach (@keys) {
         if ($_ !~ /^\s/) {
           push @{$urlParts{$k}{'paramk'}},$_;
         }
      }
       my @k = @{$urlParts{$k}{'paramk'}};
       my ($last,$first,$next) = $k[-1];
       foreach my $i (0..($#k - 1)) {
         ($first, $next) = ($k[$i], $k[$i+1]);
         $q =~ /$first\=(.*?)\&?$next/;
         $urlParts{$k}{'params'}{$first} = uri_escape($1);
         $p{$first} = uri_escape($1);
       }
       $q =~ /$last\=(.*)\&?/;
       $p{$last} = uri_escape($1);
       $urlParts{$k}{'params'} = \%p;
     
       my @q;
       foreach my ($k, $v) ( %{$urlParts{$k}{'params'}} ) {
         push @q, "$k\=$v";
       }
       $urlParts{$k}{'query'} = join("&", @q);

       my @parts = split(/\./,$urlParts{$k}{fqdn});

       $urlParts{$k}{host} = shift @parts if ($#parts > 1);

       $urlParts{$k}{domain} = join('.', @parts); 
       $urlParts{$k}{tld} = $parts[-1];
     }
    # ) = ($1,$2,$4,$5);
    #  print "$scheme, $fqdn, $path, $query\n" if (defined $Pverbose);
}

print Dumper(\%urlParts) if (defined $Pverbose);

foreach my $k (keys %urlParts) {
  print "-> $k\n" if (defined $Pverbose);
  foreach my $el (@Poutput) {
    if (defined $el and exists $urlParts{$k}{$el}) {
      if ($el eq 'params' or $el eq 'paramk') {
        print Dumper($urlParts{$k}{$el});
      } else {
        print $urlParts{$k}{$el}."\n";
      }
    }
  }
  print "\n";# if (defined $Pverbose);
}

if (defined $Pcount) {
  print "found $count\n";
}
