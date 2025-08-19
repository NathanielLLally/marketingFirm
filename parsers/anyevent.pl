#!/usr/bin/perl
use strict;
use warnings;
use AnyEvent::HTTP;
use AnyEvent::UserAgent;
use Data::Dumper;
print "ok 1\n";
my $cv = AnyEvent->condvar;
AnyEvent::HTTP::http_get ("https://www.yellowpages.com/peoria-az/dui-dwi-attorneys?page=5", timeout => 1, sub {
   print "ok 3\n";
      my ($body, $hdr) = @_;
      print "returned ";
      print Dumper(\$body);
      printf "status %s\n",$hdr->{Status};

   $cv->send;
});
print "ok 2\n";
$cv->recv;
print "ok 4\n"; 


my $ua = AnyEvent::UserAgent->new;

print "\nuseragent get\n";
$ua->get('https://www.yellowpages.com/peoria-az/dui-dwi-attorneys?page=5', sub {
    my ($res) = @_;
    print(Dumper($res, $ua->cookie_jar));
    $cv->send();
  });
$cv->recv();

