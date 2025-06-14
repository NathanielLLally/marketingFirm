#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use Try::Tiny;
use Data::Dumper;

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
	@log = `/usr/bin/journalctl -xu postfix`;
} else {
	@log = `/usr/bin/journalctl -xeu postfix`;
}

my %qidNfo;
my %midQid;

	foreach my $line (@log) {
		my ($dtJ, $lqid, $addr,$mx,$ip,$port, $status, $mid);
		$status = '';
		#		message-id=<17493613610.A747.955182@hawkeye>
		if ($line =~ /((.*?) (.*?) (.*?)).*?: ([A-F0-9]+): (.*?)$/) {
			$dtJ = $1;
			$lqid = $5;
			my $nfo = $6;

			if ($nfo =~ /message-id=<(.*?)>/) {
				my $mid = $1;
				$qidNfo{$lqid}->{mid} = $mid;
				$midQid{$mid}->{$lqid}++;
				foreach my $q (keys %{$midQid{$mid}}) {
					if ($q ne $lqid) {
						$qidNfo{$lqid}->{qid} = $q;
					}
				}
			}
			if ($nfo =~ /to=(.*?)\,/) {
				$addr = lc $1;
				$addr =~ s/<//;
				$addr =~ s/>//;
				$qidNfo{$lqid}->{to} = $addr;
			} 
			if ($nfo =~ /from=(.*?)\,/) {
				$addr = lc $1;
				$addr =~ s/<//;
				$addr =~ s/>//;
				$qidNfo{$lqid}->{from} = $addr;
			}
			if ($nfo =~ /relay=(.*?)\,/) {
				$qidNfo{$lqid}->{relay} = $1;
				if ($qidNfo{$lqid}->{relay} =~ /^(.*?)\[(.*?)\]:(\d+)$/) {
					($mx,$ip,$port) = ($1,$2,$3);
					$qidNfo{$lqid}->{mx} = $1;
				}
			}
			if ($nfo =~ /status=(\w+) \((.*?)\)/) {
				$qidNfo{$lqid}->{result} = $1;

				($status) = ($2);
				$qidNfo{$lqid}->{status} = $status;
			}

		}
	}

print Dumper(\%qidNfo);


foreach my $row (@$rs) {
	#sent,defer,bounce codes
	my $munge = $row->{status};
	$munge =~ s/^(\d\.\d\.\d) //;
	printf "%u %s\n",$row->{id},$munge;
	foreach my $qid (keys %qidNfo) {
		my $minlen = length($munge);
		my $status = $qidNfo{$qid}->{status};
		$minlen = length($status) if (length($status) < $minlen);
		if ($minlen > 0 and substr($status,0,$minlen) eq substr($munge,0,$minlen)) {
			print sprintf("local q id %s rcpt %s from %s mx %s status %s\n", $qid, $qidNfo{$qid}->{to}, $qidNfo{$qid}->{from}, $qidNfo{$qid}->{mx}, $status);
			#print LOG sprintf("local q id %s addr %s mx %s status %s\n", $lqid, $addr, $mx, $status);
			#    print LOG sprintf("local q id %s addr %s mx %s status %s\n", $lqid, $addr, $mx, $status);
			#    print LOG "updated rows: ".$rv->{processed}."\n";

			my $sql = sprintf("update mx.smtp_status set result = ?, qid = ?, addr = ?, mx = ?  where id = ?");
			try {
				my $sth= $dbh->prepare($sql);
				$sth->execute($qidNfo{$qid}->{result}, $qidNfo{$qid}->{qid} || $qid, $qidNfo{$qid}->{to}, $qidNfo{$qid}->{mx}, $row->{id});
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
		}
	}
}

$dbh->disconnect;
close(LOG);
