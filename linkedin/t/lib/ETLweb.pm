package Error::Fatal;
use Moose;
extends 'Throwable::Error';

has class => ( is => 'ro', isa => 'Str', default => 'Fatal' );

package Wrap::ETLweb;

use FindBin::libs;
use Data::Dumper;
use Try::Tiny;
use Net::EmptyPort;
use Carp::Always;
use File::Which;
use Playwright;
use DBI;
use open qw(:std :encoding(UTF-8));

use Moose::Util::TypeConstraints;
use Test::Class::Moose;

# public profile
#"?trk=people-guest_people_search-card"

#our $test = undef;

sub test_startup {
    my $test = shift;
    my $report               = $test->test_report;
    my $instance             = $report->current_instance->name;
    #    my $upcoming_test_method = $report->current_method->name;
    $test->next::method;
    $test->dbh;
}

sub test_setup {
   my $test = shift;
   $test->next::method;    # run this before your test_setup code
   # more setup
}

sub test_teardown {
   my $test = shift;
   # more teardown
   $test->next::method;    # run this after your test_teardown code
}

sub test_shutdown {
    my $test = shift;
   # more teardown
    $test->next::method;    # run this after your test_shutdown code

    #    my ($context) = @{$test->browser->contexts()};
    # Only reliable way to close chrome, also how you can CDP directly
    #    my $cdp = $context->newCDPSession($test->page);
    #    $cdp->send('Browser.close');
}

has 'dbh' => ( is => 'ro', isa => 'Object', lazy => 1, default => sub {
        my $s = shift;
        DBI->connect("dbi:Pg:dbname=postgres;host=127.0.0.1", 'postgres', undef, {
                RaiseError => 1, #    AutoCommit => 1,
            }) or Error::Fatal->throw({message => "cannot connect: $DBI::errstr"});
    });

has 'backend_binary' => ( is =>'rw', isa => 'Str',  default => sub {
    File::Which::which('chromium') || File::Which::which('chromium-browser');
    });

has 'verbose' => ( is => 'rw', isa => 'Bool', default => 1 );

sub info {
    my $s = shift;
    my ($fmt, @args) = @_;
    printf($fmt, @args) if ($s->verbose);
}

my $stdin;
has 'port' => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { 
    my $s = shift;
    my $port = Net::EmptyPort::empty_port();
    print "backend binary: ".sprintf("%s --remote-debugging-port=%s --headless",$s->backend_binary,$port)."\n";
    #open(my $stdin, '|-', sprintf("%s --remote-debugging-port=%s --headless",$s->backend_binary,$port)) or Error::Fatal->throw({message => "Could not open chromium-browser to test!"});
    open($stdin, '|-', sprintf("%s --remote-debugging-port=%s ",$s->backend_binary,$port)) or die "WTFFFF";

    $s->info("Waiting for cdp server on port $port to come up...\n");
    Net::EmptyPort::wait_port( $port, 10 ) or die "hmmmmm";
    print "done got port $port\n";

    return $port;
});

has 'debug' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'cdp_uri' => ( is =>'rw', isa => 'Str',  lazy => 1,
    default => sub { 
        my $s = shift; 
        if (exists $ENV{CDP_URI}) {
            my $cdp_uri = $ENV{CDP_URI};
            if ($cdp_uri =~ /:(\d+)$/) {
                $s->port($1);
                return $cdp_uri;
            }
        }
        my $v = sprintf("http://127.0.0.1:%s",$s->port); 
        print "cdp_url: $v\n";
        return sprintf("http://127.0.0.1:%s",$s->port); 
    });

has 'handle' => ( is => 'rw', isa => 'Playwright', lazy => 1, default => sub {
        my $s = shift;
        my $h = Playwright->new( debug => 1 );
        #my $h = Playwright->new( debug => 1 );
        return $h;
    });

has 'cdphandle' => ( is => 'rw', isa => 'Playwright', lazy => 1, default => sub {
        my $s = shift;
        my $v = sprintf("http://127.0.0.1:%s",$s->port); 
        print "cdp_uri:". $s->cdp_uri."\n";
        my $h = Playwright->new( debug => $s->debug, cdp_uri => $s->cdp_uri );
        print Dumper(\$h);
        return $h;
    });

subtype 'BrowserType'
    => as 'Str'
    => where { $_ =~ /^(firefox|chrome)$/ && $1 eq $_; };
    
    #has 'browser_type' => ( is => 'ro', isa => 'BrowserType', default => 'firefox' );
has 'browser_type' => ( is => 'ro', isa => 'BrowserType', default => 'chrome' );

has 'browser_host' => ( is => 'ro', isa => 'Str', default => '127.0.0.1' );

sub browser_firefox
{
    my $s = shift;

    my $b = $s->handle->launch( headless => 1, type => 'firefox');
    my $process = $s->handle->server( browser => $b, command => 'process' );
    print "Browser PID: ".$process->{pid}."\n";
    return $b;
}

sub browser_chrome
{
    my $s = shift;
        # Open a new chrome instance
    $s->handle($s->cdphandle);
    my $browser = $s->handle->launch( headless => 1, type => 'chrome' );
    return $browser;
}

has 'browser' => ( is => 'rw', isa => 'Object', lazy => 1, default => sub {
        my $s = shift;
        #By default, firefox will open PDFs in a pdf.js window. To suppress this behavior (such as in the event you are await()ing a download event), you will have to pass this option to launch():

# Assuming $handle is a Playwright object
        #my $browser = $handle->launch( type => 'firefox', firefoxUserPrefs => { 'pdfjs.disabled' => JSON::true } );

        printf "browser init type [%s]\n", $s->browser_type;

        print "browser_".$s->browser_type."\n";
        print "ref:".ref($s->{"browser_".$s->browser_type})."\n";
        print Dumper(\$s);
        my $method = "browser_".$s->browser_type;
        return $s->$method();
        #        $s->handle->launch( headless => 1, type => 'chrome' );
    });

has 'page' => ( is => 'rw', isa => 'Object', lazy => 1, default => sub {
        my $s = shift;
        print "page init\n";
        #$s->browser->newPage({ videosPath => 'video', acceptDownloads => 1 });
        my $context = $s->browser->newContext({
            proxy => { 
                server => '23.95.150.145:6114',
                username => 'huosowav',
                password => '9tym2wl2a6ix'
            }
        }
        );
        $context->newPage({acceptDownloads => 1});
    });

=head2 network copy from chromium on successful profile get

fetch("https://in.linkedin.com/in/sunil-ta-advisor?trk=people-guest_people_search-card&original_referer=https%3A%2F%2Fwww.linkedin.com%2F", {
  "headers": {
    "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
    "accept-language": "en-US,en;q=0.9",
    "priority": "u=0, i",
    "sec-ch-ua": "\"Chromium\";v=\"135\", \"Not-A.Brand\";v=\"8\"",
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": "\"Linux\"",
    "sec-fetch-dest": "document",
    "sec-fetch-mode": "navigate",
    "sec-fetch-site": "same-origin",
    "upgrade-insecure-requests": "1",
    "cookie": "bcookie=\"v=2&15b5a76d-11ba-4786-8af2-2afdbaac07d6\"; lidc=\"b=VGST08:s=V:r=V:a=V:p=V:g=3296:u=1:x=1:i=1755532720:t=1755619120:v=2:sig=AQH-gXAGeNBDRpkgvq8ZQPhsSShu9I9G\"; dfpfpt=cb1ace031b3644d5a2ebdc6fc5a2de36; lang=v=2&lang=en-us; __cf_bm=havoL6vVKSBEWvvSodlxJ_ABBRtZuGIgQecXm3rJvJU-1755535521-1.0.1.1-s2kcHrn9ce72MpTUHjheZ_mNSm7O3qMV6EBaotUqrXLIAIDCNB3Jw1vG.pGDGyf43A.OcsBdRDaNtUBlKBB0.C5LvlawnjgOhK7cAMbG.ak; AMCVS_14215E3D5995C57C0A495C55%40AdobeOrg=1; AMCV_14215E3D5995C57C0A495C55%40AdobeOrg=-637568504%7CMCIDTS%7C20319%7CMCMID%7C18738664442014422470041236350715880402%7CMCAAMLH-1756140322%7C7%7CMCAAMB-1756140322%7C6G1ynYcLPuiQxYZrsz_pkqfLG9yMXBpb2zX5dvJdYQJzPXImdj0y%7CMCOPTOUT-1755542722s%7CNONE%7CvVersion%7C5.1.1; fptctx2=taBcrIH61PuCVH7eNCyH0I1otfYAPn9VOPY9aMX8tO3rUhCnbliKCQe1XJZMT494RUlvlmBu%252bhaewIAlPprwbQWsZg7cEexGlrmzz0X4ojK79fqjYdR8r5HWBpqOnw0YnzlH5SMJH86LaWJI3z%252fwCkYbsglEx%252brDZWbZ1R%252f5YGn1W6WGKyNn%252bwiAEidpELBmtZwGxXanMMjX5OHuTaoEM3X6uz8Wu%252bqg916GaW834addmYfHDgE7ST7AFeGJcY8ngrhfl3jYKB1fptFfwIYLhXf3nABmoUAuWRgR5%252fSafJFyVDKHaTH3QZMwwC%252f3nt%252f7UEY12twE8yUErN86DFT0OGDokcFWNrJjKy8Cd24yJdLB1kdE1oU93sf6F0EiERHO; aam_uuid=19315875602930258040026369598789128217; recent_history=AQEQUEcxMVDjOQAAAZi-EuYY-jwf7mZdWcafJfb1kcK7VWy8OlYEgtUQ3G76Y0GsLhY1kx0U8xpEODnOxsWcjWiyyM_Di_YgZg_sYZp4cBjEZu5hAhBbOo31SBzf87Cs9rkit1yaLY45eb_isis-hdvBcSJaZzEkLRAozlwo-BNy05jEMMPHNyN4LYidxuxWXe2hHZEMVWaey8cS0DLcQ2aXMaZn1HaUKzWC4CsozaCaq4Vl4jJKhu_6ywHr1w; bscookie=\"v=1&202508181647001b42c50a-6d40-4b35-8371-6060da89fc0bAQFpeCtVNTVQeCZ-zb72S_kDxVdRmk63\"; ccookie=0001AQFvGLH5J1lr+QAAAZi+E79wyyDOWYC9GVrWvUPdqUyvXYNZ7jMOWHoHlRYG55BnjbQxOtzIQr6Yfy6BM+K09tC7/7L6fSyld3hBujqAoHbfAdjt2PX8Mj2EeWlApvSOoZD0wRtqI3Rm6DjIbJDa71b0Q1DotYqU9rPBbPATQxnSGLk7uf7VKA4mo5cdQTtOGw==|/MfjY+CgSzCjEiVYpsGpVwuTWXvpUB97pvSfiyIF1rQ=",
    "Referer": "https://in.linkedin.com/in/sunil-ta-advisor?trk=people-guest_people_search-card",
    "Referrer-Policy": "strict-origin-when-cross-origin"
  },
  "body": null,
  "method": "GET"
});

=cut

sub test_profile_person : Tags(person) {
    my $test  = shift;
    my $url = shift;
    $url = "https://www.linkedin.com/";
    my $r = $test->page->goto($url, { waitUntil => 'commit' });
    my $loc = $test->page->locator('body');
    $test->handle->await( $loc->waitFor({state => 'visible'}) );
    $loc->click();

    $loc->screenshot({ path => 'li_home.jpg' });

    $url = "https://www.linkedin.com/directory/people-search?trk=homepage-basic_directory_peopleSearchDirectoryUrl";
    $r = $test->page->goto($url, { waitUntil => 'commit' });
    $loc = $test->page->locator('body');
    $test->handle->await( $loc->waitFor({state => 'visible'}) );

    $loc->screenshot({ path => 'li_profile.jpg' });

}

sub test_anti_bot_profile_person : Tags(antibot) {
    my $test  = shift;
    my $url = shift;
    $url = "https://www.linkedin.com/in/a-jason-jones-104aa312b?trk=people-guest_people_search-card&original_referer=https%3A%2F%2Fwww.linkedin.com%2F",
    $url = "https://www.linkedin.com/";
    $url = "https://www.linkedin.com/directory/people-search?trk=homepage-basic_directory_peopleSearchDirectoryUrl";
    #$url = "https://httpbin.io/ip";

    my $page = $test->page;
    my $wd = " return { webdriver: navigator.webdriver, ua: navigator.userAgent };";
    my $result = $test->page->evaluate($wd);
    print "webdriver status: ".$result->{webdriver}."\n";
    print "navigator userAgent: ".$result->{ua}."\n";

    # Read the console
    $test->page->on('console',"return [...arguments]");

    my $promise = $test->page->waitForEvent('console');
    #XXX this *can* race
    sleep 1;
    $test->page->evaluate("console.log('hug')");
    my $console_log = $test->handle->await( $promise );

    print "Logged to console: '".$console_log->text()."'\n";


    #$test->page->on("request", 'lambda request: print(">>", request.method, request.url)');
    $test->page->on("request", 'a=[...arguments]; req = a[0]; console.log(req.url());');
    #        print(">>", request.method, request.url)');
    $test->page->route("**/*", 'a=[...arguments]; route = a[0];
  const headers = route.request().headers();
  console.log("original headers:");
  console.log(headers);
  headers["sec-ch-ua"] = "\"Chromium\";v=\"135\", \"Not-A.Brand\";v=\"8\"";
  headers["user-agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36";
  headers["sec-fetch-dest"] = "document";
  headers["sec-fetch-mode"] = "navigate";
  headers["sec-fetch-site"] = "same-origin";
  headers["bcookie"] = 
  console.log(headers);
  await route.continue({ headers });
');

#    my $u = "https://www.linkedin.com/";
#    my $r = $test->page->goto($u, { waitUntil => 'commit' });
#    my $loc = $test->page->locator('body');
#    $test->handle->await( $loc->waitFor({state => 'visible'}) );

    my $r = $test->page->goto($url, { waitUntil => 'commit' });
    my $loc = $test->page->locator('body');
    $test->handle->await( $loc->waitFor({state => 'visible'}) );

    $loc->screenshot({ path => 'li_profile.jpg' });

    my $wd = " return { webdriver: navigator.webdriver, ua: navigator.userAgent };";
    my $result = $test->page->evaluate($wd);
    print "webdriver status: ".$result->{webdriver}."\n";
    print "navigator userAgent: ".$result->{ua}."\n";
    do {
        sleep 1;
    } while(1);
}

sub test_people_directory : Tags(people) {
    my $test  = shift;
    
    my @ln = $test->pd_max_page;
    is $#ln, 1, 'previous page has value';

    ok(1,'can construct');
    #    ok(2,"port: ".$test->port);
    my $r = $test->page->goto('https://www.linkedin.com/', { waitUntil => 'domcontentloaded' });
    ok(2, $test->browser->version());

    my $loc = $test->page->locator('body');
    $test->handle->await( $loc->waitFor({state => 'visible'}) );
    $loc->screenshot({ path => 'li_home.jpg' });

    my $dirlink = $test->page->getByRole('link', { name => 'Members' });
    my $promise = $test->page->waitForLoadState('domcontentloaded');
    $dirlink->last()->click();
    sleep 1;
    $test->handle->await($promise);

    $loc = $test->page->locator('body');
    $test->handle->await( $loc->waitFor({state => 'visible'}) );
    $loc->screenshot({ path => 'li_people_buckets.jpg' });


    my @bucketUrls = ();
    my $start = $ln[0] || 'a';
    foreach my $l ($start..'z', 'more') {
        push @bucketUrls, "https://www.linkedin.com/directory/people/$l";
    }
    my $once = undef;
    #my $once = 1;
    foreach my $url (@bucketUrls) {
      my $linkBucket = $test->page->select(sprintf('a[href="%s"]', $url));

      my $promise = $test->page->waitForLoadState('domcontentloaded');
      $linkBucket->click();
      sleep 1;
      $test->handle->await($promise);
        

      my $loc = $test->page->locator('body');
      $test->handle->await( $loc->waitFor({state => 'visible'}) );
      #      $loc->screenshot({ path => 'li_bucket_spread.jpg' });

      #https://playwright.dev/docs/api/class-locator#locator-aria-snapshot
      #$loc = $test->page->getByRole('list')->filter({ has => $test->page->getByRole('link', {name => '1', exact => 1} ) });

      $loc = $test->page->locator('ol[type="1"]');
      my $text = $loc->ariaSnapshot();
      while ($text =~ /url: (.*?)\s*$/mgc) {
          my $purl = $1;
          print "url [$purl]\n";
          my $p = join('-',@ln);
          if ($purl =~ /$p$/) {
              $once = 1;
          }
          if (defined $once) {
              $test->member_links_page($purl);

              my $sth = $test->dbh->prepare ("INSERT into pending_lip (url, resolved) values (?,now()) on conflict(url) do nothing");
              try {
                  $sth->execute($purl);
              } catch {
              };
          }
      }
      #      $loc = $test->page->locator('//ol//a[@href="https://www.linkedin.com/directory/companies/a-1"]');
      #      my $el = $test->page->select('a[href="https://www.linkedin.com/directory/companies/a-1"]');
      #      print ref($el)."\n";
      #      print ref($el->{parent})."\n";
      #      ;->filter({hasText => 'directory/companies/a-1'});
      #$loc = $test->page->getByRole('listitem')->filter({hasText => 'directory/companies/a-1'});
    }
}

sub pd_max_page
{
    my $test = shift;

    my $sth = $test->dbh->prepare ("with p as (select case when l='more' then 'A' else l end as l,n from (select regexp_replace(page,'-.*','') as l, regexp_replace(page,'.*-','')::integer as n from pending_lip where resolved is not null)) select max(l) as l,max(n)-1 as n from p where l = (select max(l) from p);");
    #    my $sth = $test->dbh->prepare ("with p as (select regexp_replace(page,'-.*','') as l, regexp_replace(page,'.*-','')::integer as n from pending_lip where resolved is not null) select max(l) as l,max(n)-1 as n from p where l = (select max(l) from p);");
    $sth->execute();
    my $r = $sth->fetchall_arrayref({});

    return ($r->[0]->{l},$r->[0]->{n});
}

sub member_links_page
{
    my $test = shift;
    my $url = shift;
    my $src = $url;

    my $el = $test->page->select(sprintf('a[href="%s"]', $url));
    my $promise = $test->page->waitForLoadState('domcontentloaded');
    $el->click();
    sleep 1;
    $test->handle->await($promise);

    my $sth = $test->dbh->prepare ("INSERT into lipd (name,url) values (?,?) on conflict (name,url) do nothing");

    my $loc = $test->page->locator('ul[class="listings"]');
    my $text = $loc->ariaSnapshot();
    #    print $text."\n";
    while ($text =~ /\s+- link "(.*?)":\s*\n\s+- \/url: (.*?)\s*\n/sgc) {
        my ($name,$url) = ($1,$2);
        $url =~ s/\?.*//;
        #        print "name [$name] url [$url]\n";
        try {
            $sth->execute ($name, $url);
        } catch {
        };
    }
      #      $loc = $test->page->locator('//ol//a[@href="https://www.linkedin.com/directory/companies/a-1"]');
}

sub test_company_directory : Tags(company) {
    my $test  = shift;
    my @ln = $test->cd_max_page;

    is $#ln, 1, 'previous page has value';

    ok(1,'can construct');
    #    ok(2,"port: ".$test->port);
    my $r = $test->page->goto('https://www.linkedin.com/', { waitUntil => 'domcontentloaded' });
    ok(2, $test->browser->version());

    my $loc = $test->page->locator('body');
    $test->handle->await( $loc->waitFor({state => 'visible'}) );

    #    $loc->screenshot({ path => 'li_body.jpg' });

    my $dirlink = $test->page->getByRole('link', { name => 'Companies' });
    my $promise = $test->page->waitForLoadState('domcontentloaded');
    $dirlink->last()->click();
    sleep 1;
    $test->handle->await($promise);

    $loc = $test->page->locator('body');
    $test->handle->await( $loc->waitFor({state => 'visible'}) );
    #    $loc->screenshot({ path => 'li_company_buckets.jpg' });


    my @bucketUrls = ();
    my $start = $ln[0] || 'a';
    foreach my $l ($start..'z', 'more') {
        push @bucketUrls, "https://www.linkedin.com/directory/companies/$l";
    }
    my $once = undef;
    foreach my $url (@bucketUrls) {
      my $linkBucket = $test->page->select(sprintf('a[href="%s"]', $url));
      my $promise = $test->page->waitForLoadState('domcontentloaded');
      $linkBucket->click();
      sleep 1;
      $test->handle->await($promise);


      my $loc = $test->page->locator('body');
      $test->handle->await( $loc->waitFor({state => 'visible'}) );
      #      $loc->screenshot({ path => 'li_bucket_spread.jpg' });

      #https://playwright.dev/docs/api/class-locator#locator-aria-snapshot
      #$loc = $test->page->getByRole('list')->filter({ has => $test->page->getByRole('link', {name => '1', exact => 1} ) });

      $loc = $test->page->locator('ol[type="1"]');
      my $text = $loc->ariaSnapshot();
      while ($text =~ /url: (.*?)\s*$/mgc) {
          my $purl = $1;
          print "url [$purl]\n";
          my $p = join('-',@ln);
          if ($purl =~ /$p$/) {
              $once = 1;
          }
          if (defined $once) {
              $test->company_links_page($purl);
              my $sth = $test->dbh->prepare ("INSERT into pending_lic (url, resolved) values (?,now()) on conflict(url) do nothing");
              try {
                  $sth->execute($purl);
              } catch {
              };
          }
      }
  }
}

sub cd_max_page
{
    my $test = shift;
    my $sth = $test->dbh->prepare ("with p as (select regexp_replace(page,'-.*','') as l, regexp_replace(page,'.*-','')::integer as n from pending_lic where resolved is not null) select max(l) as l,max(n)-1 as n from p where l = (select max(l) from p);");
    $sth->execute();
    my $r = $sth->fetchall_arrayref({});

    return ($r->[0]->{l},$r->[0]->{n});
}

sub company_links_page
{
    my $test = shift;
    my $url = shift;
    my $src = $url;

    my $el = $test->page->select(sprintf('a[href="%s"]', $url));
    my $promise = $test->page->waitForLoadState('domcontentloaded');
    $el->click();
    sleep 1;
    $test->handle->await($promise);

    my $sth = $test->dbh->prepare ("INSERT into licd (name,url) values (?,?) on conflict(name,url) do nothing");

    my $loc = $test->page->locator('ul[class="listings"]');
    my $text = $loc->ariaSnapshot();
    print $text."\n";
    while ($text =~ /\s+- link "(.*?)":\s*\n\s+- \/url: (.*?)\s*\n/sgc) {
        my ($name,$url) = ($1,$2);
        $url =~ s/\?.*//;
        #        print "name [$name] url [$url]\n";
        try {
            $sth->execute ($name, $url);
        } catch {
        };
    }
      #      $loc = $test->page->locator('//ol//a[@href="https://www.linkedin.com/directory/companies/a-1"]');
}

1;
