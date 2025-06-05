#!/usr/bin/perl
use warnings;
use strict;

use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Try::Tiny;

my ($host,$port) = @ARGV;

local $/;
my $message = <STDIN>;

try {
    sendmail(
        $message,
        {
            transport => Email::Sender::Transport::SMTP->new({
                    host => $host,
                    port => $port,
                })
        }
    );
} catch {
    warn "sending failed: $_";
};

