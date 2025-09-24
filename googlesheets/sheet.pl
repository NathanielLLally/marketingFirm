     use Net::Google::Spreadsheets;
     use Data::Dumper;

      my $service = Net::Google::Spreadsheets->new(
        username => 'nathaniel.lally@gmail.com',
        password => '@7+$=SGX'
      );

      my @spreadsheets = $service->spreadsheets();

      print Dumper(\@spreadsheets);

      # find a spreadsheet by key
      my $spreadsheet = $service->spreadsheet(
        {
            key => 'key_of_a_spreasheet'
        }
      );

      # find a spreadsheet by title
      my $spreadsheet_by_title = $service->spreadsheet(
        {
            title => 'list for new year cards'
        }
      );

      # find a worksheet by title
      my $worksheet = $spreadsheet->worksheet(
        {
            title => 'Sheet1'
        }
      );


