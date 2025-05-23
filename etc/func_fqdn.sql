CREATE or REPLACE FUNCTION public.perl_require() RETURNS varchar
    LANGUAGE plperlu
    AS $_X$

    my @m = qw(URI::Find URI URI::Encode URI::Escape URI::Simple Data::Dumper Tie::IxHash PURI);
    foreach my $m (@m) {
unless (eval "require $m") {
  elog(INFO,"couldn't load $m: $@");
  } else {
  elog(INFO,"$m loaded fine");
  }
  }

return "giggity";

$_X$;
CREATE or REPLACE FUNCTION public.domain(url text) RETURNS varchar
    LANGUAGE plperlu
    AS $_X$
use PURI;
my $o = PURI::parse($_[0]);
my @k = keys %$o;
return $o->{$k[0]}->{'domain'};

$_X$;

CREATE or REPLACE FUNCTION public.fqdn(url text) RETURNS varchar
    LANGUAGE plperlu
    IMMUTABLE STRICT
    AS $_X$

use PURI;

#unless (eval "require ParsePURI") {
#  elog(INFO,"couldn't load ParsePURI: $@");
#  } else {
#  elog(INFO,"loaded fine");
#  }

my $o = PURI::parse($_[0]);
my @k = keys %$o;
return $o->{$k[0]}->{'fqdn'};

$_X$;

CREATE or REPLACE FUNCTION public.path(url text) RETURNS varchar
    LANGUAGE plperlu
    AS $_X$

use PURI;

my $o = PURI::parse($_[0]);
my @k = keys %$o;
return $o->{$k[0]}->{'path'};

$_X$;

