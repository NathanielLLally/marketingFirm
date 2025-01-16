#!/usr/bin/perl -w
use strict;

#
#  gcloud compute ssh *requires* project && zone
#

my ($TOKEN,$project,$zone, $name) = ((undef) x 4);
my $DEBUG=undef;

open(CMD, "gcloud auth print-access-token|") || die "no gcloud";
while (<CMD>) {
  chomp;
  $TOKEN=$_;
}

if ("$TOKEN" eq "") {
  `gcloud auth login`;
}

open(CMD, "gcloud projects list|") || die "no gcloud";
while (<CMD>) {
    if ($_ =~ /(staging\-\d+)/) {
        $project=$1;
    };
  print $_ if (defined $DEBUG);
}

open(CMD, "gcloud compute instances list|") || die "no gcloud";

while (<CMD>) {
    my @line = split(/\s+/, $_);
    if (defined $line[0] and $line[0] ne 'NAME') {
        ($name,$zone) = ($line[0], $line[1]);
        print "$_\n" if (defined $DEBUG);
    }
}

#print "instance [$name], zone [$zone] project [$project]\n";
print "gcloud compute ssh $name --zone $zone\n";
#instance [$name], zone [$zone] project [$project]\n";

close(CMD);
