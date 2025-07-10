#!/usr/bin/perl
use strict;
use warnings;
use AnyEvent::HTTP;
use AnyEvent::UserAgent;
use Data::Dumper;
print "ok 1\n";
my $cv = AnyEvent->condvar;

my $ua = AnyEvent::UserAgent->new;

print "\nuseragent get\n";
$ua->get('https://www.yellowpages.com/peoria-az/dui-dwi-attorneys?page=5', sub {
    my ($res) = @_;
    print(Dumper($res, $ua->cookie_jar));
    $cv->send();
  });
$cv->recv();

