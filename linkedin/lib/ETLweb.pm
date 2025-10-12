package Error::Fatal;
use Moose;
extends 'Throwable::Error';

has class => ( is => 'ro', isa => 'Str', default => 'Fatal' );

package ETLweb;
use Moose;
use FindBin::libs;
use Data::Dumper;
use Try::Tiny;
use Net::EmptyPort;
use Carp::Always;
use File::Which;
use Playwright;

#has IS_WIN => $^O eq 'MSWin32';

has 'backend_binary' => ( is =>'rw', isa => 'Str',  default => sub {
    File::Which::which('chromium') || File::Which::which('chromium-browser');
    });

has 'verbose' => ( is => 'rw', isa => 'Bool', default => 1 );

sub info {
    my $s = shift;
    my ($fmt, @args) = @_;
    printf($fmt, @args) if ($s->verbose);
}

has 'port' => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { 
    my $s = shift;
    my $port = Net::EmptyPort::empty_port();
    print "backend binary: ".sprintf("%s --remote-debugging-port=%s --headless",$s->backend_binary,$port)."\n";
    #open(my $stdin, '|-', sprintf("%s --remote-debugging-port=%s --headless",$s->backend_binary,$port)) or Error::Fatal->throw({message => "Could not open chromium-browser to test!"});
    open(my $stdin, '|-', sprintf("%s --remote-debugging-port=%s --headless",$s->backend_binary,$port)) or die "WTFFFF";

    #    $s->info("Waiting for cdp server on port $port to come up...\n");
    Net::EmptyPort::wait_port( $port, 10 ) or die "hmmmmm";
    print "done got port $port\n";

    return $port;
});

has 'debug' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'cdp_uri' => ( is =>'rw', isa => 'Str',  lazy => 1,
    default => sub { 
        my $s = shift; 
        print "WTF\n";
        my $v = sprintf("http://127.0.0.1:%s",$s->port); 
        print "cdp_url: $v\n";
        return sprintf("http://127.0.0.1:%s",$s->port); 
    });

has 'handle' => ( is => 'rw', isa => 'Playwright', lazy => 1, default => sub {
        my $s = shift;
        my $h = Playwright->new( debug => 1 );
        return $h;
    });

has 'cdphandle' => ( is => 'rw', isa => 'Playwright', lazy => 1, default => sub {
        my $s = shift;
        print "WTFFFF\n";
        my $v = sprintf("http://127.0.0.1:%s",$s->port); 
        print "cdp_uri:". $s->cdp_uri."\n";
        my $h = Playwright->new( debug => $s->debug, cdp_uri => $s->cdp_uri );
        print Dumper(\$h);
        return $h;
    });

has 'browser' => ( is => 'rw', isa => 'Object', lazy => 1, default => sub {
        my $s = shift;
        print "browser init\n";
        my $b = $s->handle->launch( headless => 0, type => 'firefox');
        my $process = $s->handle->server( browser => $b, command => 'process' );
        print "Browser PID: ".$process->{pid}."\n";
        return $b;
        #        $s->handle->launch( headless => 1, type => 'chrome' );
    });

has 'page' => ( is => 'rw', isa => 'Object', lazy => 1, default => sub {
        my $s = shift;
        print "page init\n";
        $s->browser->newPage({ videosPath => 'video', acceptDownloads => 1 });
    });


no Moose;
__PACKAGE__->meta->make_immutable;
