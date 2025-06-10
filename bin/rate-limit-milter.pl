#!/usr/bin/perl
use warnings;
use strict;
use Carp qw(verbose);
use Sendmail::PMilter qw(:all);
use Data::Dumper;
use Net::DNS;
use DBI;
use Try::Tiny;
use Sys::Syslog qw(:DEFAULT setlogsock);

our $verbose = 1;
my $syslog_socktype = 'unix'; # inet, unix, stream, console
my $syslog_facility = 'mail';
my $syslog_options  = 'pid';
my $syslog_priority = 'info';

my $me = 'mail.obiseo.net';

setlogsock $syslog_socktype;
openlog 'rate_limit_milter', $syslog_options, $syslog_facility;


syslog $syslog_priority, "rate_limit_milter starting ".`date` if $verbose > 0;

my $dns = Net::DNS::Resolver->new;

sub connectDBI
{
DBI->connect_cached('dbi:Pg:dbname=postgres;host=127.0.0.1', 'postgres',undef,{
      RaiseError => 1,
      InactiveDestroy => 1,
      PrintError => 0,
      PrintWarn => 0,
    }) or die "cannot connect: $DBI::errstr";
}

my $dbh = connectDBI;


# milter name should be the one used in sendmail.mc/sendmail.cf
my $miltername = 'ratelimit';
#shift @ARGV || die "usage: $0 miltername\n";

=head2 cb return

  SMFIS_CONTINUE - continue processing the message
  SMFIS_REJECT - reject the message with a 5xx error
  SMFIS_DISCARD - accept, but discard the message
  SMFIS_ACCEPT - accept the message without further processing
  SMFIS_TEMPFAIL - reject the message with a 4xx error
  SMFIS_MSG_LOOP - send a never-ending response to the HELO command

=cut

my $header;
my %cbs;
for my $cb (qw(close connect helo abort envfrom envrcpt header eoh)) {
	$cbs{$cb} = sub {
		my $ctx = shift;
                #                print "$$: $cb: @_\n";
                if ($cb eq "envfrom" or $cb eq "header") {
                  #  print Dumper($ctx->{symbols})."\n";
}
		SMFIS_CONTINUE;
	}
}

$cbs{envrcpt} = sub { 
  my $ctx = shift;
  print "$$: envrcpt: @_\n";
  #  print Dumper($ctx->{symbols})."\n";
  my $ret = SMFIS_CONTINUE;
  my $email = $ctx->{symbols}->{R}->{'{rcpt_addr}'};

  print "email $email\n";
  if ($email =~ /\@(.*)$/) {
    my $host = lc($1);
    my @hosts = mx($dns, $host);
    foreach (@hosts) {
      my $svr = lc $_->exchange();
      print "$email mx $svr\n";

      my $count = 0;
      my $limit = 49;
      my $domain;

      if ($svr ne $me) {
      try {
        #   time in seconds since the last status update from mail exchange domain
        #
        $dbh = connectDBI;
        my $sth = $dbh->prepare("select extract(epoch from (now() - max(updated))) as seconds from mx.smtp_status where mx.mxdomain(?) = mxdomain");
        $sth->execute($svr);
        my $rs = $sth->fetchall_arrayref({});
        if ($#{$rs} > -1) {
          if (defined $rs->[0]->{seconds} and $rs->[0]->{seconds} <= 60) {
            $header = "mx domain rate delay for $svr";
            syslog $syslog_priority, "header set: $header" if $verbose > 0;
            print "header set: $header\n" if $verbose > 0;
          }
        }
      } catch {
      };
    }
      try {
        #  any kind of ip or domain based block from this domain
        #
        $dbh = connectDBI;
        my $sth = $dbh->prepare("select * from mx.smtp_bounces where mxdomain = mx.mxdomain(?)");
        $sth->execute($svr);
        my $rs = $sth->fetchall_arrayref({});
        if ($#{$rs} > -1) {
          if ($rs->[0]->{domain_block} > 0) {
            $header = "domain based bounce within 7 days for svr $svr";
            syslog $syslog_priority, "header set: $header" if $verbose > 0;
            print "header set: $header\n" if $verbose > 0;
            return $ret;
          }
          if ($rs->[0]->{user_block} >= 3) {
            $header = "3 or more user based bounces within 7 days for svr $svr";
            syslog $syslog_priority, "header set: $header" if $verbose > 0;
            print "header set: $header\n" if $verbose > 0;
            return $ret;
          }
        }
      } catch {
      };
      try {
        #  number of smtp status updates for mail exchange domain within the last day joined with per limit
        #
        $dbh = connectDBI;
        my $sth = $dbh->prepare('select ct,"limit",mxdomain from (select count(*) as ct,mxdomain from mx.smtp_status where mxdomain = mx.mxdomain(?) and updated >= now() - interval \'1 day\' group by 2) s left join mx.rate_limits l on s.mxdomain = l.domain');

        $sth->execute($svr);
        my $rs = $sth->fetchall_arrayref({});
        if ($#{$rs} > -1) {
          $count = $rs->[0]->{ct};
          if (defined $rs->[0]->{limit}) {
            $limit = $rs->[0]->{limit};
          }
          $domain = $rs->[0]->{mxdomain};
          print "count $count limit $limit domain $domain src $svr\n";
        }
        if ($count >= $limit) {
          $header = sprintf "count at limit $limit for srv $svr, $domain, rejecting";
          syslog $syslog_priority, "header set: $header" if $verbose > 0;
        }

      } catch {
      };

    }
    #}
  }

  $ret;
};

$cbs{eom} = sub { 
  my $ctx = shift;
  print "$$: eom: @_\n";
  if (defined $header) {
      print "adding header 'X-Rate-Limit-Reached', $header\n";
    $ctx->addheader('X-Rate-Limit-Reached', $header);
    syslog $syslog_priority, "adding header X-Rate-Limit-Reached: $header";
    return SMFIS_TEMPFAIL if ($header =~ /rate delay/);
  }
  $header = undef;
  SMFIS_CONTINUE;
};

my $milter = new Sendmail::PMilter;

#$milter->auto_setconn($miltername);
$milter->setconn('inet:8892');

#$milter->register($miltername, \%cbs, SMFI_CURR_ACTS);
$milter->register($miltername, \%cbs, SMFI_CURR_ACTS);

my $dispatcher = Sendmail::PMilter::prefork_dispatcher(
	max_children => 10,
	max_requests_per_child => 100,
);

$milter->set_dispatcher($dispatcher);
$milter->main();
