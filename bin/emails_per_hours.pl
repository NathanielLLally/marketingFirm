#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature 'isa';

use DBI;
use Data::Dumper;
use List::Util qw(shuffle);
use Config::Tiny;
use File::Basename;
use File::Spec;
use Try::Tiny;
use Role::Tiny;
use DateTime;
use Date::Manip;
use Tie::IxHash;
use Text::Table;
use Text::ANSITable;

binmode(STDOUT, ":utf8");


my $dirname = dirname(__FILE__);
my $cfgFile = File::Spec->catfile($ENV{HOME},'.obiseo.conf');
print "using config $cfgFile\n";
our $CFG = Config::Tiny->read( $cfgFile );

print `date`;

my $dbh = DBI->connect($CFG->{dB}->{dsn}, $CFG->{dB}->{user}, $CFG->{dB}->{pass},{
      RaiseError => 1,
      #    AutoCommit => 1,
    }) or die "cannot connect: $DBI::errstr";

my $age = 24; 

my (@cid,@hosts,%cid);

my ($sth,$rs);
try {
  $sth = $dbh->prepare ("select id,basename,description from email_content ec join (select distinct cid from track_email where sent >= date_trunc('hour', now()) - INTERVAL '$age hour') sq on ec.id = sq.cid;");
  $sth->execute();
  $rs = $sth->fetchall_arrayref({});
  foreach my $row (@$rs) {
    push @cid, $row->{id};
    foreach (keys %$row) {
      $cid{$row->{id}}->{$_} = $row->{$_};
    }
  }
} catch {
};

#print Dumper(\%cid);

my $sql = "select regexp_replace(pending,'.*\\.(.*?)\\..*', '\\1') as pending from (select distinct pending from track_email where pending is not null and sent >= date_trunc('hour', now()) - INTERVAL '$age hour') sq;";
try {
  $sth = $dbh->prepare($sql);
  $sth->execute();
  $rs = $sth->fetchall_arrayref({});
  foreach my $row (@$rs) {
    push @hosts, $row->{pending};
  }
} catch {
};

$sql = <<EOF
  select cid,hour,pending as host, ct from (
        select cid,to_timestamp(to_char(sent,'YY/MM/DD HH24'), 'YY/MM/DD HH24') as hour, regexp_replace(pending,'.*\\.(.*?)\\..*', '\\1') as pending, count(*) as ct
        from track_email
        where sent is not null and sent >= date_trunc('hour',now()) - INTERVAL '$age hour'
        group by 1,2,3
        union all
        select cid,to_timestamp(to_char(sent,'YY/MM/DD HH24'), 'YY/MM/DD HH24') as hour, 'total'::text as pending, count(*) as ct
        from track_email
        where sent is not null and sent >= date_trunc('hour',now()) - INTERVAL '$age hour'
        group by 1,2
        order by 2,1,3
      ) sq where pending is not null
EOF
;

$sth = $dbh->prepare($sql);
$sth->execute();

$rs = $sth->fetchall_arrayref({});

#print Dumper(\$rs);
my %th;
tie %th, 'Tie::IxHash';
foreach my $r (@$rs) {
  my $h = $r->{host};
  if ($h =~ /total/) {
    $h = "_$h";
  }
  my $th = $h .'_'. $r->{cid};
  #  print "$th\n";
  $th{$r->{cid}}->{$r->{hour}}->{$r->{host}} = $r->{ct};
  $th{$r->{cid}}->{'total'}->{$r->{host}} += $r->{ct};
}

foreach my $cid (keys %th) {
  my $t = Text::ANSITable->new;
  $t->border_style('UTF8::SingleLineBold');  # if not, a nice default is picked
  $t->color_theme('Data::Dump::Color::Light');  # if not, a nice default is picked
  $t->{header_bgcolor} = '000000';
  $t->{header_fgcolor} = 'ffffff';
  $t->{header_align} = 'middle';

  #printf "\n\nemail [%s:%s]\n",$cid,$cid{$cid}->{basename};
  #  $t->add_row([undef,join("\t",$cid,$cid{$cid}->{basename})]);
  my $short = $cid{$cid}->{description};
  my $type = "html";
  if ($short =~ /(plaintext)/) {
    $type = $1;
  }
  my $bsc = $t->{border_style_obj}->get_border_char(char=>'v_i');
  $t->columns(["email", $type]);
  $t->add_row([$cid, $cid{$cid}->{basename}]);
  #  $t->set_column_style($colname, align  => 'middle');
  $t->set_cell_style(0, "email", align  => 'middle');
  $t->set_cell_style(0, "email", fgcolor  => 'ccffcc');
  $t->set_cell_style(1, $type, fgcolor  => 'ccffcc');
  $t->set_cell_style(0, $type, align  => 'middle');
  $t->set_cell_style(0, $type, fgcolor  => '66ffff');

  if ($short =~ /domain \[(.*?)\]/){
    #    print "  $1\n" if (defined $1);
    $t->add_row(["tracking domain", $1]);
  }
  if ($short =~ /tracking tags \[(.*?)\]/) {
    my @t = split(/,/,$1);
    $t->add_row(["tracking query tags", join($bsc,@t)]);
  }
  if ($short =~ /embedded image tags \[(.*?)\]/) {
    my @t = split(/,/,$1);
    $t->add_row(["embedded images", join($bsc,@t)]);
  }
  if ($short =~ /pages \[(.*?)\]/) {
    my @t = split(/,/,$1);
    $t->add_row(["linked pages", join($bsc,@t)]);
  }
  print $t->draw;

  my $sep = \'│';
  my $major_sep = \'║';

  #  my $tb = Text::Table->new($sep," hour ", $major_sep, @hosts, "total");
  my $t = Text::ANSITable->new;
  $t->border_style('UTF8::SingleLineBold');  # if not, a nice default is picked
  $t->color_theme('Data::Dump::Color::Light');  # if not, a nice default is picked
  
  $t->columns(["hour", @hosts, "total"]);

  foreach my $ds (
    sort { Date_Cmp(ParseDate($a) || ParseDate('now'), ParseDate($b) || ParseDate('now')) } 
    keys %{$th{$cid}}
  ) {
    my $date = Date::Manip::Date->new;
    my $err = $date->parse($ds);
    my $hourField = ($err) ? 'total' : $date->printf("%b %d %I%p");
    my @vals = map{ $th{$cid}->{$ds}->{$_} || 0 } @hosts, 'total';
    #    $tb->load([$date->printf("%b %d %I%p"), @vals]);
    $t->add_row([$hourField , @vals]);
  }
  #  $t->set_row_style(-1, {fgcolor => '000000', bgcolor => 'ffffff'});
  $t->{header_fgcolor} = '000000';
  $t->{header_bgcolor} = 'ffffff';
  $t->set_column_style('hour', fgcolor => '000000');
  $t->set_column_style('hour', bgcolor => 'ffffff');
  $t->set_column_style('total', fgcolor => '66FFFF');
  $t->set_column_style('total', bgcolor => '000000');
  $t->add_cond_cell_style(sub { not defined $_ or $_ eq "0" }, fgcolor=>'D22630', bgcolor=>'000000');

  $t->set_row_style($#{$t->{rows}}, {fgcolor => '66FFFF', bgcolor => '000000'});
  foreach (@hosts) {
    $t->set_cell_style($#{$t->{rows}}, $_, fgcolor => '66FFFF');
    #    $t->set_cell_style($#{$t->{rows}}, $_, bgcolor => '');
  }
  $t->set_cell_style($#{$t->{rows}}, "hour", align  => 'middle');

  print $t->draw;
  print "\n";
  #  print $tb;
}

=head2
    map { 
      my $d = Date::Manip::Date->new; 
      $d->parse($_); 
      $th{$cid}->{$_}->{date} = $d;
      $d; 
    } keys %{$th{$cid}}
=cut

