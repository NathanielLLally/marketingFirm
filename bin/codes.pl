#!/usr/bin/perl
use warnings;
use strict;
use Email::Find;
use ParsePURI;
use List::Util qw/reduce any all none notall first reductions max maxstr min minstr product sum sum0 pairs unpairs pairkeys pairvalues pairfirst pairgrep pairmap shuffle uniq uniqint uniqnum uniqstr zip mesh/;

my $cb = sub {
	my($email, $orig_email) = @_;
	#	$email->format;
	return $orig_email;
};

my @pertainsToUser = ( 'mailbox', 'no such user', 'relay', 'recipient', 'does not exist', 'address rejected');
my @interesting = ('dkim', 'spf', 'rbl', 'blocked', 'junkmail', 'spam', 'black list', 'reputation', 'unsolicited');
my @mailservers = qw/obiseo.net 147.93.146.52 accurateleadinfo.com 144.91.96.230 leadtinfo.com 173.212.235.5 winblows98.com 194.180.176.214/;

my $finder = Email::Find->new($cb);
my $puri = ParsePURI->new();
while (<STDIN>) {
	my $status;
	my $enhanced;
	if ($_ =~ /Diagnostic-Code => (.*?)\|/) {
		my $dc = $1;
		my $emailCount = $finder->find(\$dc);
		my $r = $puri->parse($dc);
		my @urls;
		if (defined $r) {
			foreach (keys %$r) {
				push @urls, $r->{$_}->{url};
			}
		}

		if ($dc =~ /(.*?); ?(\d{3,})/) {
			$status = $2;
		} else {
			#	print "no status: $dc\n";
		}

		if ($dc =~ /[- ](\d\.\d\.\d+)[^\.\d]+/) {
			$enhanced = $1;
			#			print "enhanced = $enhanced\n";
		} else {
			#			print "$dc\n";
		}

		#https://en.wikipedia.org/wiki/List_of_SMTP_server_return_codes
		#
		#5.4.310 dns - domain doesnt exist
		#
		#5.7.1
		#5.7.13 sender email account disabled
		#5.7.129 either not no white list or is on blacklist
		#5.7.133 exchange auth to group
		#5.7.134 -microsoft - could be spam or settings
		#5.7.193 not memeber of microsoft teams
		#5.7.23 spf ip fail
		#5.7.27 spf fail
		#5.7.26 unauth - dkim or spf etc..
		if (defined $enhanced and $enhanced =~ /(\d)\.(\d)\.(\d+)/) {
			my $class = $1;
			my $subject = $2;
			my $detail = $3;
			if ($class == 5) {
				if ($subject =~ /[01234]/) {
					print "user block code [$enhanced]: $dc\n";
					next;


				} elsif ($subject == 7 and $detail !~ /(129|133|134|193)/) {
					print "domain block code [$enhanced]: $dc\n";
					next;

				}
			}
		}
		my $ppD = join('|',@interesting);
		#$ppD = join('|', @mailservers);
		#$ppD =~ s/\./\\\./g;
		my $reD = qr/($ppD)/;
		if ($dc =~ /$reD/) {
			print "domain block regex: $dc\n";
			next;
		}

		my $ppU = join('|',@pertainsToUser);
		my $reU = qr/($ppU)/;
		if ($dc =~ /$reU/ or $emailCount > 0) {
			print "user block: $dc\n";
			next;
		}

		print "unknown: $dc\n";

	} else {
		#		print "no match: $_\n";
	}
}
