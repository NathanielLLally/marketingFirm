#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use Try::Tiny;

my $full = shift @ARGV;

sleep 1;

my $dbh = DBI->connect('dbi:Pg:dbname=postgres;host=127.0.0.1', 'postgres', undef, {
		RaiseError => 1,
		PrintError => 0,
		AutoCommit => 1,
	}) or die "cannot connect: $DBI::errstr";

my $sth = $dbh->prepare('select id,status from mx.smtp_status where qid is null');
$sth->execute();
my $rs = $sth->fetchall_arrayref({});

open(LOG, ">>/var/lib/pgsql/data/log/smtp_status.log") || die "$!";

print LOG `date`;

my @log;
if (defined $full) {
	print LOG "full switch\n";
	@log = `/usr/bin/journalctl -xt 'mynetwork/smtp' -t 'postfix/smtp'`;
} else {
	@log = `/usr/bin/journalctl -xet 'mynetwork/smtp' -t postfix/smtp`;
}

foreach my $row (@$rs) {
	my ($dtJ, $lqid, $addr,$mx,$ip,$port, $status);
	foreach my $line (reverse @log) {
		if ($line =~ /((.*?) (.*?) (.*?)).*?: ([A-F0-9]+): (.*?)$/) {
			$dtJ = $1;
			$lqid = $5;
			my $nfo = $6;
			if ($nfo =~ /to=(.*?)\,/) {
				$addr = lc $1;
				$addr =~ s/<//;
				$addr =~ s/>//;
			} 
			if ($nfo =~ /relay=(.*?)\[(.*?)\]:(\d+)\,/) {
				($mx,$ip,$port) = ($1,$2,$3);
			}
			if ($nfo =~ /status=(\w+) \((.*?)\)/) {
				($status) = ($2);
			}

			#sent,defer,bounce codes
			my $munge = $row->{status};
			$munge =~ s/^(\d\.\d\.\d) //;
			my $minlen = length($munge);
			$minlen = length($status) if (length($status) < $minlen);
			if (substr($status,0,$minlen) eq substr($munge,0,$minlen)) {
				print LOG sprintf("local q id %s addr %s mx %s status %s\n", $lqid, $addr, $mx, $status);
				#    print LOG sprintf("local q id %s addr %s mx %s status %s\n", $lqid, $addr, $mx, $status);
				my $sql = sprintf("update mx.smtp_status set qid = ?, addr = ?, mx = ?  where id = ?");
				try {
					my $sth= $dbh->prepare($sql);
					$sth->execute($lqid, $addr, $mx, $row->{id});
				} catch {
					if ($_ =~ /constraint "smtp_status_qid_unique"/) {
						my $sql = sprintf("delete from mx.smtp_status where id = ?");
						try {
							my $sth= $dbh->prepare($sql);
							$sth->execute($row->{id});
						} catch {
						};
					} else {
						print "uncaught Db error: $_\n";
					}
				};
				#    print LOG "updated rows: ".$rv->{processed}."\n";
				last;
			}
		}
	}
}

$dbh->disconnect;
close(LOG);
