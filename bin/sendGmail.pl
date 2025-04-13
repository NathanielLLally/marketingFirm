#!/usr/bin/perl
use strict;
use warnings;
use Email::Send;
use Email::Send::Gmail;
use Email::Simple::Creator;
my $email = Email::Simple->create(
    header => [
        From    => 'nathaniel@obiseo.net',
        To      => 'nathaniel@obiseo.net',
        Subject => 'Server down',
    ],
    body => 'The server is down. Start panicing.',
);


my $sender = Email::Send->new(
    {   mailer      => 'Gmail',
        mailer_args => [
            #username => 'nate.lally@gmail.com',
            #password => 'czmk sbfd hbcw ljwt',
            username => 'sales@grandstreet.group',
            password => 'xmno vbhe bwkx ptgz',
        ]
    }
);
eval { $sender->send($email) };
die "Error sending email: $@" if $@;

