use strict;
use warnings;

use FindBin::libs;

use Data::Dumper;
use Playwright;
use Try::Tiny;
use Net::EmptyPort;
use Carp::Always;
use File::Which;

use constant IS_WIN => $^O eq 'MSWin32';
goto CDP;

NORMAL: {
    my $handle = Playwright->new( debug => 1 );

    # Open a new chrome instance
    #my $browser = $handle->launch( headless => 0, type => 'chromium', proxy => 'socks5://localhost:9050');
    my $browser = $handle->launch( headless => 0, type => 'firefox');
    #my $browser = $handle->launch( headless => 1, type => 'firefox');
    my $process = $handle->server( browser => $browser, command => 'process' );
    print "Browser PID: ".$process->{pid}."\n";

    # Open a tab therein
    my $page = $browser->newPage({ videosPath => 'video', acceptDownloads => 1 });

   # Browser contexts don't exist until you open at least one page.
    # You'll need this to grab and set cookies.
    my ($context) = @{$browser->contexts()};

    #my $res = $page->goto('https://www.linkedin.com/', { waitUntil => 'networkidle' });
    #my $res = $page->goto('https://www.linkedin.com/', { waitUntil => 'domcontentloaded' });

    # Load a URL in the tab
    my $res = $page->goto('https://www.linkedin.com/directory/companies?trk=homepage-basic_directory_companyDirectoryUrl', { waitUntil => 'networkidle' });
    print Dumper($res->status(), $browser->version());

    # Put your hand in the jar
    my $cookies = $context->cookies();
    print Dumper($cookies);

    # Grab the main frame, in case this is a frameset
    my $frameset = $page->mainFrame();
    print Dumper($frameset->childFrames());

    # Take screen of said element
    $page->screenshot({ path => 'li_cd.jpg' });

sleep 60;
}

CDP: {
    my $chromium = File::Which::which('chromium') || File::Which::which('chromium-browser');
    die "Chromium not installed on this host." unless $chromium;

    my $port = Net::EmptyPort::empty_port();

    open(my $stdin, '|-', qq{$chromium --remote-debugging-port=$port --headless}) or die "Could not open chromium-browser to test!";
    #open(my $stdin, '|-', qq{$chromium --remote-debugging-port=$port}) or die "Could not open chromium-browser to test!";
    print "Waiting for cdp server on port $port to come up...\n";
    Net::EmptyPort::wait_port( $port, 10 )
      or die( "Server never came up after 10s!");
    print "done\n";

    #XXX not clear that this doesn't want an http uri instead? idk
    my $handle = Playwright->new( debug => 1, cdp_uri => "http://127.0.0.1:$port" );

    # Open a new chrome instance
    my $browser = $handle->launch( headless => 1, type => 'chrome' );

    # Open a tab therein
    my $page = $browser->newPage({ videosPath => 'video', acceptDownloads => 1 });

    # Load a URL in the tab
    my $res = $page->goto('https://www.linkedin.com/', { waitUntil => 'domcontentloaded' });
    print Dumper($res->status(), $browser->version());

    #my $res = $page->goto('https://www.linkedin.com/directory/companies?trk=homepage-basic_directory_companyDirectoryUrl', { waitUntil => 'networkidle' });

# Grab us some elements
my $body = $page->select('body');
# You can also get the innerText
my $text = $body->textContent();
print "\n\n********textContent:\n$text\n";
$body->click();

    my $loc = $page->locator('body');
    my $innerTubes = $loc->allInnerTexts();
    print Dumper($innerTubes);
    $body->screenshot({ path => 'li_body.jpg' });


    $page->screenshot({ path => 'li_cd_cdp.jpg' });

    my ($context) = @{$browser->contexts()};

    # Put your hand in the jar
    my $cookies = $context->cookies();
    print Dumper($cookies);

    # Grab the main frame, in case this is a frameset
    my $frameset = $page->mainFrame();
    print Dumper($frameset->childFrames());

    # Run some JS
    my $fun = "
        var input = arguments[0];
        return {
            width: document.documentElement.clientWidth,
            height: document.documentElement.clientHeight,
            deviceScaleFactor: window.devicePixelRatio,
            arg: input
        };";
        #    my $result = $page->evaluate("\$x('//a/\@href)');");
    my $result = $page->evaluate($fun, 'zippy');
        #    my $result = $page->evaluate("\$x('//a/\@href)');");
    print Dumper($result);

    print "\n***getByRole link -> allInnerTexts\n";
    my $links = $page->getByRole('link');
    print Dumper($links->allInnerTexts());

=head2 selectMulti

    my $inputs = $page->selectMulti('input');

    foreach my $input (@$inputs) {
        try {
            # Pretty much a brute-force approach here, again use a better pseudo-selector instead like :visible
            $input->fill('tickle', { timeout => 250 } );
        } catch {
            print "Element not visible, skipping...\n";
        }
    }
=cut

  my $dirlink = $page->select('a[href="https://www.linkedin.com/directory/companies?trk=homepage-basic_directory_companyDirectoryUrl"]');

  #my $promise = $page->waitForURL('**/companies');
  my $promise = $page->waitForLoadState('domcontentloaded');
  $dirlink->click();
  my $ares = $handle->await($promise);
  print Dumper(\$ares);


  #my $loc = $page->locator('body');
    #  my $innerTubes = $loc->allInnerTexts();
    #print Dumper($innerTubes);

    my $body = $page->select('body');
    $body->screenshot({ path => 'li_2_body.jpg' });


    my @bucketUrls = ();
    foreach my $l ('a'..'z', 'more') {
      push @bucketUrls, "https://www.linkedin.com/directory/companies/$l";
    }
    my $linkBucket = $page->select(sprintf('a[href="%s"]', shift @bucketUrls));
    my $promise = $page->waitForLoadState('domcontentloaded');
    $linkBucket->click();
    my $ares = $handle->await($promise);

    my $body = $page->select('body');
    $body->screenshot({ path => 'li_bucket.jpg' });

    my $bucketPages = $page->locator('div[class="pagination-links"]');
    print "\n****bucket pages:\n";
    print Dumper($bucketPages->allInnerTexts());

    
    my $lists = $page->getByRole('list');
    my $re = qr/^\d+$/;
    my $list = $lists->getByText($re);
    #, has => $page->getByRole('link')});
    #    my $ll = $lists->getByRole('link');
#    print Dumper($lists->filter({hasNot => $page->locator('[class="listings"]')})->allInnerTexts());
    #    my $bucketPages = $page->getByRole('listitem');
    print Dumper($list->allInnerTexts());

    #$bucketPages->filter({has => $page->getByRole('link', {name => '1'}) });
    #$bucketPages->filter({hasText => '1'});

#    locator('div[class="pagination-links"]');

=head2 why use browser console to eval each list element- order of mag slower

    my $bucketPages = $page->selectMulti('a[class="pagination-links__link"]');
    foreach my $page (@$bucketPages) {
      try {
        # Pretty much a brute-force approach here, again use a better pseudo-selector instead like :visible
        my $href = $page->getAttribute('href', { timeout => 250 } );
        print "bucket href $href\n";
      } catch {
        print "Element not visible, skipping...\n";
      }
    }

=cut


    # Only reliable way to close chrome, also how you can CDP directly
    my $cdp = $context->newCDPSession($page);
    $cdp->send('Browser.close');

}



