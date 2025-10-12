package Wrap::ETLweb;

use Test::Most;
use Playwright;
use Data::Dumper;
use base 'Test::Class';

sub class { 'ETLweb' }

#our $etlw = undef;

sub startup : Tests(startup) {
    my $test = shift;
    my $class = $test->class;
    eval "use $class";
    die $@ if $@;
}

sub shutdown : Tests(shutdown) {
    my $test = shift;

    # Only reliable way to close chrome, also how you can CDP directly
    #my $cdp = $context->newCDPSession($page);
    #$cdp->send('Browser.close');

}

sub company_directory : Tests(no_plan) {
    my $test  = shift;
    my $class = $test->class;
    can_ok($class, 'new');
    ok(1,'can construct');
    my $etlw = $class->new;
    #    ok(2,"port: ".$etlw->port);
    my $r = $etlw->page->goto('https://www.linkedin.com/', { waitUntil => 'domcontentloaded' });
    ok(2, $etlw->browser->version());

    my $loc = $etlw->page->locator('body');
    $etlw->handle->await( $loc->waitFor({state => 'visible'}) );

    $loc->screenshot({ path => 'li_body.jpg' });

    my $dirlink = $etlw->page->getByRole('link', { name => 'Companies' });
    my $promise = $etlw->page->waitForLoadState('domcontentloaded');
    $dirlink->last()->click();
    sleep 1;
    $etlw->handle->await($promise);

    my $loc = $etlw->page->locator('body');
    $etlw->handle->await( $loc->waitFor({state => 'visible'}) );
    $loc->screenshot({ path => 'li_company_buckets.jpg' });


    my @bucketUrls = ();
    foreach my $l ('a'..'z', 'more') {
        push @bucketUrls, "https://www.linkedin.com/directory/companies/$l";
    }
    foreach my $url (@bucketUrls) {
      my $linkBucket = $etlw->page->select(sprintf('a[href="%s"]', $url));
      my $promise = $etlw->page->waitForLoadState('domcontentloaded');
      $linkBucket->click();
      $etlw->handle->await($promise);

        

      my $loc = $etlw->page->locator('body');
      $etlw->handle->await( $loc->waitFor({state => 'visible'}) );

      #https://playwright.dev/docs/api/class-locator#locator-aria-snapshot
      $loc = $etlw->page->getByRole('link').ariaSnapshot();

      #      like($loc->
      $loc->screenshot({ path => 'li_bucket_spread.jpg' });
    }
}

1;
