#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature 'isa';

use DBI;
use Data::Dumper;
use List::Util qw(shuffle);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Try::Tiny;
use Role::Tiny;
use ParsePURI;
use HTML::Packer;


sub makeDescription {
  my $html = shift;

my $pseudoUniversalResourceIndicator = ParsePURI->new();

my $r = $pseudoUniversalResourceIndicator->parse($html);
my @k = keys %$r;

my %trackedClicks;
my %pages;
my %untracked;
my %outgoing;
my $domain;
foreach my $k (@k) {
  if (defined $r->{$k}->{'fqdn'}) {
    if (defined $r->{$k}->{'query'} and $r->{$k}->{'query'} =~ /%UUID%/) {
      $r->{$k}->{'query'} =~ s/=%UUID%//;
      $r->{$k}->{'path'} =~ s|^/||;
      if ($r->{$k}->{'path'} =~ /track\.png/) {
        #           printf "tracking pixel domain [%s]\n", $r->{$k}->{'fqdn'};
        $domain = $r->{$k}->{'fqdn'};
        $r->{$k} = undef;
      } else {
        $trackedClicks{$r->{$k}->{'query'}}++;
        #        $pages->{$r->{$k}->{'fqdn'}}->{$r->{$k}->{'path'}}++;
        #        printf "%s %s %s\n", $r->{$k}->{'fqdn'}, $r->{$k}->{'path'}, $r->{$k}->{'query'};
      }
    }
  }
}
foreach my $k (@k) {
  if (defined $r->{$k}->{'fqdn'}) {
    if ($r->{$k}->{'fqdn'} ne $domain) {
      printf "outgoing? [%s]\n", $r->{$k}->{'fqdn'};
      $outgoing{$r->{$k}->{'fqdn'}}->{$r->{$k}->{'path'}}++;
    } else {
      if (defined $r->{$k}->{'query'}) {
        $pages{$r->{$k}->{'fqdn'}}->{$r->{$k}->{'path'}}++;
      } elsif (defined $r->{$k}->{path} and length($r->{$k}->{path})>0){

        $untracked{$r->{$k}->{'fqdn'}}->{$r->{$k}->{'path'}}++;
      }
    }
  }
}

my @imageTags;
while ($html =~ /src="cid:(.*?)"/gc) {
  push @imageTags, $1;
}

my $description;


$description .= sprintf "tracking pixel domain [%s]\nclick tracking tags [%s]\n  over pages [%s]\n", 
  $domain, join(",",sort keys %trackedClicks), join(",",sort keys %{$pages{$domain}});

if (exists $untracked{$domain} and scalar keys %{$untracked{$domain}} > 0) {
  $description .= sprintf "untracked links [%s]\n", join(",",sort keys %{$untracked{$domain}});
}
if ($#imageTags > -1) {
  $description .= sprintf "embedded image tags [%s]\n", join(",", @imageTags);
}
#print "outgoing:\n";
#print Dumper(\%outgoing);
if (scalar keys %outgoing > 0) {
  $description .= sprintf "outgoing link domains [%s]\n", join(",",sort keys %outgoing);
}


  return $description;
}

my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($ENV{HOME},'.obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

#print `date`;

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $file = shift @ARGV;
  open(FH, "<$file") || die "cannot open html [$file]!\n";
undef $/; # enable slurp mode
my $html = <FH>;
close FH;

my $description = 'plaintext';
if ($html =~ /\<html.*?\>/i) {
  $description = makeDescription($html);
}

my $packer = HTML::Packer->init();
$packer->minify( \$html, {
    remove_comments => 1, 
    remove_newlines => 1, 
    do_stylesheet => 'minify', 
    do_javascript => 'best',
    do_csp => 'sha512',
    html5 => 1,
  } );


my ($basename, $path, $suffix) = fileparse($file);
print "basename $basename\n";
print "description $description\n";
try {
  my $sth = $dbh->prepare ("insert into email_content (content, basename, description) values (?,?,?) on conflict (content_md5) do update set basename=EXCLUDED.basename, description=EXCLUDED.description");
  $sth->execute($html, $basename, $description);
  $sth->finish;
} catch {
};

my $sth = $dbh->prepare ("select id from email_content where content = ?");
$sth->execute($html);
printf "content id:%s\n",$sth->fetchall_arrayref({})->[0]->{id};


