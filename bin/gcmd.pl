#!/usr/bin/perl -w
use strict;

#
#  gcloud compute ssh *requires* project && zone
#

my ($TOKEN,$project,$zone, $name, $user, $cmd) = ((undef) x 4, "devel", "/home/devel/bin/gitSync");
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

close(CMD);

#print "instance [$name], zone [$zone] project [$project]\n";
my $u = '';
$u = "$user@" if (defined $user);
my $c = "gcloud compute ssh $u$name --zone $zone -- -AXn $cmd|";
open(CMD, "$c") || die "failed: [$c]";
#instance [$name], zone [$zone] project [$project]\n";
while (<CMD>) {
    print $_;
}

close(CMD);
