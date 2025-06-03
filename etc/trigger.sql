CREATE OR REPLACE FUNCTION mx.after_status_insert_trigger_function()
RETURNS trigger AS
$$
  use Data::Dumper;
  use Date::Manip;

  my $new_row = $_TD->{new};

  warn Dumper(\$new_row);
  my $dtDb = Date::Manip::Date->new();
  $dtDb->parse($new_row->{updated});
  warn $dtDb->printf("%c");
  my $status = $new_row->{status};

#Jun 02 19:16:52 mail.obiseo.net postfix/smtp[3347060]: 5E5F454055E: to=<vmail@leadtinfo.com>, relay=mail.leadtinfo.com[173.212.235.5]:25, delay=2.2, delays=0.84/0.04/0.9/0.46, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 4BC806A00AC
#   
my ($dtJ, $lqid, $addr,$mx,$ip,$port, $status);
my @log = `/usr/bin/journalctl -xet 'postfix/smtp'`;
foreach my $line (reverse @log) {
  if ($line =~ /((.*?) (.*?) (.*?)).*?: ([A-F0-9]+): (.*?)$/) {
    $dtJ = $1;
    $lqid = $5;
    my $nfo = $6;
    if ($nfo =~ /to=(.*?)\,/) {
      $addr = $1;
    } 
    if ($nfo =~ /relay=(.*?)\[(.*?)\]:(\d+)\,/) {
      ($mx,$ip,$port) = ($1,$2,$3);
    } 
    if ($nfo =~ /status=(\w+) \((.*?)\)$/) {
      ($status) = ($2);
    } 

#sent,defer,bounce codes
my $munge = $new_row->{status};
$munge =~ s/^(\d\.\d\.\d) //;

if ($status eq $munge) {
    warn sprintf("local q id %s addr %s mx %s status %s\n", $lqid, $addr, $mx, $status);
    my $sql = sprintf("update mx.smtp_status set qid = '%s', addr = '%s', mx = '%s' where id = %u", $lqid, $addr, $mx, $new_row->{id});
    my $rv = spi_exec_query($sql);
    warn "updated rows: ".$rv->{processed}; 
  last;
}

  }
} 

  return; # Return is ignored for AFTER triggers
$$
LANGUAGE plperlu;


