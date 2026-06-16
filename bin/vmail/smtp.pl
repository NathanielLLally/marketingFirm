#!/usr/bin/perl
use warnings;
use strict;

use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Try::Tiny;
use DBI;
use constant EX_UNAVAILABLE => 69;

my ($host,$port, $qid) = @ARGV;
open(LOG, ">>/home/vmail/smtp.log");
print LOG "$host $port $qid\n";


local $/;
my $message = <STDIN>;
if ($message =~ /^X-Rate-Limit-Reached:\s?(.*?)$/m) {
	my $reason = $1;
	my ($addr,$mx);
	if ($message =~ /^To: (.*?)$/m) {
		$addr = $1;
	}
	if ($reason =~ /svr (.*)\,?/) {
		$mx = $1;
	}
	$reason = "5.7.1 550 $reason";
	print LOG "$reason\n";
	try {
		my $dbh = DBI->connect('dbi:Pg:dbname=postgres;host=127.0.0.1', 'postgres', undef, {
				RaiseError => 1, PrintError => 0,
			}) or print LOG "cannot connect: $DBI::errstr\n" and die;
		my $sth = $dbh->prepare('insert into mx.smtp_status (qid, status,result,addr,mx) values (?,?,?,?,?)');
		my $result = 'bounced';
		$sth->execute($qid,$reason,$result, $addr, $mx || "");
		
	 } catch {
		 print LOG "dberror $_\n";
	 };

	exit EX_UNAVAILABLE;
}

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

