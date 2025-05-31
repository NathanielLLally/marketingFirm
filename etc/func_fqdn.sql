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

CREATE or REPLACE FUNCTION public.phoneIsValid(phone text,country text) RETURNS bool
    LANGUAGE plperlu
    AS $_X$
use Number::MuPhone;
if (not defined $_[0] or not defined $_[1]) {
  return 0;
  }
my $num = Number::MuPhone->new({ number => $_[0], country => $_[1]});
if ($num->error) {
  return 0;
}
return 1;

$_X$;

CREATE or REPLACE FUNCTION public.domain(url text) RETURNS varchar
    LANGUAGE plperlu
    AS $_X$
use PURI;
my $o = PURI::parse($_[0]);
my @k = keys %$o;
return $o->{$k[0]}->{'domain'};

$_X$;

--  using table wi.blacklist(field,clause)
--  and zip code regexes for the US,Canada, and the UK
--  make a view attempting to make valid contacts
--
create or replace procedure wi.makeViewValidContact()
 language plpgsql
as $$
    declare _sql text;
    declare _clause text;
  begin
select 'and ' || string_agg(field||' not like ''' || clause || '''', ' and ') from wi.blacklist into _clause;
select 'create or replace view wi.valid_contact as select * from wi.contact where phone is not null and zip is not null and country is not null' ||
' and (regexp_like(zip, ''^\d{5,5}(-\d{4,4})?$'') or regexp_like(zip, ''^(?!.*[DFIOQU])[A-VXY][0-9][A-Z] ?[0-9][A-Z][0-9]$'') '  ||
' or regexp_like(zip, ''^(?:(?:[A-PR-UWYZ][0-9]{1,2}|[A-PR-UWYZ][A-HK-Y][0-9]{1,2}|[A-PR-UWYZ][0-9][A-HJKSTUW]|[A-PR-UWYZ][A-HK-Y][0-9][ABEHMNPRV-Y]) [0-9][ABD-HJLNP-UW-Z]{2}|GIR 0AA)$'') ) ' 
 into _sql;

execute _sql || _clause; 
  end
$$;

CREATE or REPLACE FUNCTION public.emailIsValid(email text) RETURNS bool
    LANGUAGE plperlu
    AS $_X$
use Email::Valid;
if (($_[0] =~ /@wix-domains\.com/) or 
   ($_[0] =~ /@whoisprivacyprotect\.com/)
  ) {
  return 0;
  }
my $to = Email::Valid->address($_[0]);
if (not defined $to) {
  return 0;
}
return 1;

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

