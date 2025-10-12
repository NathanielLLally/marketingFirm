package Voip.ms
use REST::Client;
use URI::Encode;
use JSON;
use Time::Piece;
use DBI;
use Data::Dumper;
use FindBin;
use File::Spec;
use Moose;

has 'dbh' => (is => 'rw', isa => 'Object', lazy => 1, default => sub {
    DBI->connect('dbi:Pg:dbname=postgres;host=127.0.0.1', 'postgres', undef, {
    RaiseError => 1, PrintError => 0, AutoCommit => 1, }
    ) or die "cannot connect: $DBI::errstr";
});

has 'URI' => (is => 'rw', isa => 'URI::Encode', default => sub { URI::Encode->new( { encode_reserved => 0 } ); });


has 'json' => (is => 'rw', isa => 'JSON', default => sub {JSON->new->allow_nonref; });

has 'rest' => (is => 'rw', isa => 'REST::Client', default => sub { REST::Client->new({ host => 'https://voip.ms' }); });

has 'data' => (is => 'rw', isa => 'HASHREF', default => sub {
        my $s = shift;
        my $creds = {
            api_username => '',
            api_password => '',
        };

        local $/;
        undef $/;
        my $file = $FindBin::Bin.'/../etc/voip.creds';
        open(FH, $file) || die "cannot open credentials file [$file]";
        my $creds = $s->json->decode(<FH>);
        close(FH);
        %$creds;
    });

my %call = %data;
$call{method} = 'getSMS';
$call{all_messages} = 1;
$call{did} = '7025515025';

%call = %data;

sub restCall {
    my $s = shift;
    my %data = $s->data
    my $q = '?'.join ('&', map { sprintf("$_=%s", $URI->encode($data{$_})); } keys %data);
    print "query=[$q]\n" if ($DEBUG);
    $client->GET("/api/v1/rest.php$q");
    my $res = $json->decode($client->responseContent());
    if ($res->{status} eq 'success') {
        return $res;
    } elsif ($res->{status} eq 'ip_not_enabled') {
        die "ip_not_enabled";
    } else {
        die Dumper(\$res);
    }
}

sub info
{
    my $self = shift;
    my %call = %{$self->{data}};
    $call{method} = 'getBalance';
    $call{advanced} = 1;
    my $res = $self->restCall(%call);
    $res;
}

sub poll
{
    my $s = shift;
    my %call = %{$self->{data}};
    $s->restCall(
    $call{method} = 'getSMS';
    $call{all_messages} = 1;
}

1;
