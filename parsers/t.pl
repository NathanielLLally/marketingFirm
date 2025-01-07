      use Getopt::Long;
      my $data   = "file.dat";
      my $length = 24;
      my $verbose;
      GetOptions ("length=i" => \$length,    # numeric
                  "file=s"   => \$data,      # string
                  "verbose"  => \$verbose)   # flag
      or die("Error in command line arguments\n");

