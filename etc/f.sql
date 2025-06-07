CREATE or REPLACE FUNCTION mx.mxdomain(mx text) RETURNS varchar
    LANGUAGE plperlu
    IMMUTABLE STRICT
    AS $_X$
use Data::Dumper;

my %tld = map { $_ => 1; } qw/com org net int edu gov mil/;
#warn Dumper(\%tld);

#  ip address
#
if ($_[0] =~ /^((\d+)\.?)+$/) {
  return $_[0];
}

my @parts = reverse split(/\./,(lc $_[0]));

my $d = join('.',$parts[1],$parts[0]);
if (exists $tld{$parts[1]}) {
 $d = join('.',$parts[2],$d);
}

return $d;
$_X$;

