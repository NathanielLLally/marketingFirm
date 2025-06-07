CREATE OR REPLACE FUNCTION mx.classify_smtp_status(status text)
RETURNS varchar
    IMMUTABLE STRICT
AS $$

  use Email::Find;

  my @pertainsToUser = ( 'mailbox', 'no such user', 'relay', 'recipient', 'does not exist', 'address rejected');
  my @interesting = ('dkim', 'spf', 'rbl', 'blocked', 'junkmail', 'spam', 'black list', 'reputation', 'unsolicited');
  my @mailservers = qw/obiseo.net 147.93.146.52 accurateleadinfo.com 144.91.96.230 leadtinfo.com 173.212.235.5 winblows98.com 194.180.176.214/;

  my $finder = Email::Find->new(sub{});
  my $status;
  my $enhanced;
  my $dc = $_[0];
  my $emailCount = $finder->find(\$dc);

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
            return "user block code [$enhanced]";

          } elsif ($subject == 7 and $detail !~ /(129|133|134|193)/) {
            return "domain block code [$enhanced]";
          }
        }
      }
      my $ppD = join('|',@interesting);
      #$ppD = join('|', @mailservers);
      #$ppD =~ s/\./\\\./g;
      my $reD = qr/($ppD)/;
      if ($dc =~ /$reD/) {
        return "domain block regex";
      }

      my $ppU = join('|',@pertainsToUser);
      my $reU = qr/($ppU)/;
      if ($dc =~ /$reU/ or $emailCount > 0) {
        if ($emailCount > 0) {
#          return "user block has email";
        } else {
          return "user block regex";
        }
      }
    return;
$$
LANGUAGE plperlu;



