package PURI;

use strict;
use warnings;

use URI::Find;
use URI;
use URI::Encode;
use URI::Escape;
#use URI::Info;
use URI::Simple;
use Data::Dumper;
use Getopt::Long;
use Tie::IxHash;

sub parse 
{
	my ($text) = @_;
	my %url;
	my %urlParts;

	our $finder = URI::Find->new(
		sub {
			my ($uri) = shift;
			#            my $u = URI->new(
			#            my $nfo = $uriInfo->info($uri); 
			#print "$uri\n";
			#$uri =~ /(.*?)\,/;
			#print "$1\n";

			$url{uri_unescape($uri)}++;
			#            $url{$nfo->host}++;
			#            print $nfo->host."\n";
		}
	);



	my $count = $finder->find(\$text);


	foreach my $k (keys %url) {
		$k =~ s/\/$//;

		#  if ($k =~ /(https?:\/\/)([\w\-\.]+)((\/.*?)(\?.*?))?/)
		#
		#  see URI pod, section PARSING URIs WITH REGEXP
		#
		if ($k =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|) {
			$urlParts{$k} = {
				scheme => $1, 
				authority => $2,  fqdn => $2, 
				path => $3, 
				query => $4, 
				fragment => $5, 
				url => $k,
			};
			my $q = $4;
			my $u = URI->new($k);
			if ($urlParts{$k}{scheme} eq "mailto") {
				$urlParts{$k}{email} =  $urlParts{$k}{path};
			}

			# TODO: HACK - bitch at them or submit a patch
			#
			#Copyright 1995-2009 Gisle Aas.
			#Copyright 1995 Martijn Koster.
			#
			#  libwww-perl
			#
			my %p;
			tie %p, 'Tie::IxHash';
      if ( $u->can('query_param')) {
			my @keys = $u->query_param;
			if ($#keys >= 0) {
                $urlParts{$k}{'paramk'} = ();
				foreach (@keys) {
					if ($_ !~ /^\s/) {
						push @{$urlParts{$k}{'paramk'}},$_;
					}
				}
				#print Dumper($urlParts{$k}{'paramk'});
				my @k = @{$urlParts{$k}{'paramk'}};
				my ($last,$first,$next) = $k[-1];
				foreach my $i (0..($#k - 1)) {
					($first, $next) = ($k[$i], $k[$i+1]);

					$q =~ /\Q$first\E\=(.*?)\&?\Q$next\E/;
                    #$urlParts{$k}{'params'}{$first} = uri_escape($1);
					$urlParts{$k}{'params'}{$first} = $1;
                    #$p{$first} = uri_escape($1);
					$p{$first} = $1;
				}
                #broken
				$q =~ /\Q$last\E\=(.*?)\&?/;
                #$p{$last} = uri_escape($1);
                $p{$last} = $1;

				$urlParts{$k}{'params'} = \%p;
				my @q;
				foreach ( my ($k, $v) = each %{$urlParts{$k}{'params'}} ) {
					push @q, "$k\=$v";
				}
				$urlParts{$k}{'query'} = join("&", @q);
			}
        }

            if (defined $urlParts{$k}{fqdn}) {
                my @parts = split(/\./,$urlParts{$k}{fqdn});

                $urlParts{$k}{host} = shift @parts if ($#parts > 1);

                $urlParts{$k}{domain} = join('.', @parts); 
                $urlParts{$k}{tld} = $parts[-1];
            }
        }
		# ) = ($1,$2,$4,$5);
		#  print "$scheme, $fqdn, $path, $query\n" if (defined $Pverbose);
	}

	return \%urlParts;
}

1;
