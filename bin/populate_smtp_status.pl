#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use Try::Tiny;

my $dbh = DBI->connect('dbi:Pg:dbname=postgres;host=127.0.0.1', 'postgres', undef, {
		RaiseError => 1,
		AutoCommit => 1,
	}) or die "cannot connect: $DBI::errstr";

open(LOG, ">>/var/lib/pgsql/data/log/smtp_status.log") || die "$!";

print LOG `date`;

my @log = `/usr/bin/journalctl -xt 'postfix/smtp'`;
my $tzsql = "to_timestamp(date_part('Year', now()) || ' ' || ?,'YYYY Mon DD hh24:mi:ss')";

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

			print LOG sprintf("local q id %s addr %s mx %s status %s\n", $lqid, $addr, $mx, $status);
			#    print LOG sprintf("local q id %s addr %s mx %s status %s\n", $lqid, $addr, $mx, $status);
			my $sql = sprintf("insert into mx.smtp_status (qid,addr,mx,status,updated) values (?,?,?,?,$tzsql) on conflict(qid) do update set updated=excluded.updated");
			my $sth= $dbh->prepare($sql);
			$sth->execute($lqid, $addr, $mx, $status, $dtJ);
			#    print LOG "updated rows: ".$rv->{processed}."\n";
		}
	}

$dbh->disconnect;
close(LOG);
