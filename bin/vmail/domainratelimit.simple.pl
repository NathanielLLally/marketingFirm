#!/usr/bin/perl
use strict;
use warnings;

# Exit codes from <sysexits.h>
my $EX_TEMPFAIL=75;
my $EX_UNAVAILABLE=69;

my ($sender, $recipient) = @ARGV;

my $file = "/home/vmail/domainratelimit.log";
open(LOG, ">$file") or die "cannot open file [$file]";

print LOG `date`;
print LOG "$sender, $recipient\n";
close(LOG);

local $/;
my $email = <STDIN>;

open(EMAIL, ">/home/vmail/email") or die "cannot open file [/home/vmail/email]";
print EMAIL $email;
close EMAIL;

open(CMD, "|/usr/sbin/sendmail -f $sender -G -i -- $recipient");
print CMD $email;
close(CMD);

my $exit_status = $? >> 8;
exit($exit_status);
