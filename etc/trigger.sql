CREATE OR REPLACE FUNCTION mx.after_status_insert_trigger_function()
RETURNS trigger AS
$$
  use Data::Dumper;

  my $new_row = $_TD->{new};
  warn( Dumper(\$new_row) );

  if (exists $new_row->{qid} and defined $new_row->{qid}) {
    return;
  }

  $SIG{CHLD} = "IGNORE";

  my $pid = fork();

  if ($pid == 0) {
    `/var/lib/pgsql/data/smtp_status.pl`;
  }
  return; # Return is ignored for AFTER triggers
$$
LANGUAGE plperlu;



