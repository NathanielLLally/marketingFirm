#!/usr/bin/perl
use warnings;
use strict;
use Postfix::Parse::Mailq;
use Data::Dumper;
use DBI;
my $mailq_output = `mailq`;
my $entries = Postfix::Parse::Mailq->read_string($mailq_output);
my $bytes = 0;

my %dup;
my %rcptForIds;
## Please see file perltidy.ERR
my %idForRcpt;
for my $el (@$entries) {
  #  print Dumper(\$el);
    my $rcpt = ${ $el->{remaining_rcpts} }[0];
    $dup{$rcpt}++;
    $idForRcpt{ $el->{queue_id} } = $rcpt;
    push @{ $rcptForIds{$rcpt} }, $el;
}

foreach my $k (keys %dup) {
  if ($dup{$k} > 1) {
    printf "%u mails for %s\n", $dup{$k}, $k;

    my $anyError = undef;
    foreach my $el (@{$rcptForIds{$k}}) {
      printf "%s\t%s\t%s\n", $el->{queue_id}, $el->{date}, $el->{error_string} || "no error";
      $anyError = $anyError."\n".$el->{error_string} if (defined $el->{error_string});
    }
  }
}
