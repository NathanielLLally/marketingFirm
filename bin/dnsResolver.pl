#!/usr/bin/perl
use warnings;
use strict;

use Net::DNS::Async::Simple;
use Net::DNS::DomainName;
#use Test::More;
#my $list = [
#    {   query => ['www.realms.org','A'],
#    },{ query => ['174.136.1.7','PTR'],
#        nameServers => ['8.8.4.4','4.2.2.2']
#    }
#];
#Net::DNS::Async::Simple::massDNSLookup($list);
#ok $list->[0]->{address} eq '174.136.1.7', 'forward lookup worked';
#ok $list->[1]->{ptrdname} eq 'tendotfour.realms.org', 'reverse lookup worked';

use Data::Dumper;

my $file = shift @ARGV;

if (defined $file and -e "$file") {
  open(FD, "<$file") || die "cannot open $file";
} else {
  die "arg filename";
}

#print Dumper $adns->synchronous("www.google.com", ADNS_R_A);

my $n = 0;
my $list = [];
while (<FD>) {
  chomp;
  #  print "$_\n";
  push @$list, { query => [$_, 'A'], nameServers => ['8.8.8.8', '8.8.4.4'] };
  push @$list, { query => [$_, 'MX'], nameServers => ['8.8.8.8', '8.8.4.4'] };
}

#close FD;

print " looking up ".$#{$list}." records\n";

Net::DNS::Async::Simple::massDNSLookup($list);
#no warnings;
my $name = '';
foreach my $el (@$list) {
  if (exists $el->{address}) {
    print "\n";
    print $el->{name};
  }
  if (@{$el->{query}}[1] eq 'MX') {
    my @list;
    #    print @{$el->{query}}[1];
    my $e = $el->{NetDNSAnswer}->{exchange};
    #        print Dumper($e);
    my $label;
    if (exists $e->{'label'}) {
      $label = join('.', @{$e->{label}});
    }
    if (exists $e->{'origin'}) {
      $label .= '.'.join('.', @{$e->{origin}->{label}});
      if (exists $e->{'origin'}->{origin}) {
        $label .= '.'.join('.', @{$e->{origin}->{origin}->{label}});
        if (exists $e->{'origin'}->{origin}->{origin}) {
          $label .= '.'.join('.', @{$e->{origin}->{origin}->{origin}->{label}});
        }
      }
    }
    if (defined $label) {
    print ",$label";
  }
    #print ",".join(".",@{$el->{NetDNSAnswer}->{exchange}->{origin}->{label}})."\n";
  }
}

print "\n";

