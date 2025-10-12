#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use JSON;
use Data::Dumper;
use LWP::UserAgent ();
use HTTP::CookieJar::LWP ();
use Try::Tiny;
use FindBin;
use File::Spec;
use List::Util qw(
          reduce any all none notall first reductions
          max maxstr min minstr product sum sum0
          pairs unpairs pairkeys pairvalues pairfirst pairgrep pairmap
          shuffle uniq uniqint uniqnum uniqstr head tail zip mesh
        );
use Scalar::Util qw(blessed dualvar isdual readonly refaddr reftype
	tainted weaken isweak isvstring looks_like_number
	set_prototype openhandle);
# and other useful utils appearing below


my $TIKTOK = 0;
my $MAKE = 0;
my $N8N = 1;
my $q = CGI->new;
our $logFile = File::Spec->catpath($FindBin::Bin, 'webhook.log');

sub postJSON
{
	my ($endpoint, $payload, $header, $logFH) = @_;
	if (not defined openhandle($logFH)) {
		open $logFH, '>>', $logFile or die "cannot open $logFile: $!";
		print $logFH "opened log at " . scalar(localtime) . ":\n";
	}
	print $logFH "posting to webhook [$endpoint]\n";
	my $jar = HTTP::CookieJar::LWP->new;
	my $ua = LWP::UserAgent->new(timeout => 10, cookie_jar => $jar);
	try {
		my $req = HTTP::Request->new('POST', $endpoint);
		if (defined $header and ref($header) eq 'HASH') {
			$req->header( %$header );
		}
		$req->header('Content-Type' => 'application/json');
		my $j = encode_json($payload);
		print $logFH Dumper(\$j);
		$req->content($j);
		my $response = $ua->request($req);
		if ($response->is_success) {
			print $logFH "success... remote said: \t";
			print $logFH $response->decoded_content."\n";
			return 1;
		}
		else {
			print $logFH "bad response from post:\n";
			print $logFH $response->decoded_content;
			print $logFH $response->status_line;
			return 0;
		}
	} catch {
		print $logFH $_;
		return 0;
	}
}

# Set content type for the response
print $q->header('application/json');

# Read incoming POST data
my $input = $q->param('POSTDATA') || do {
    local $/; # Enable slurp mode
    <STDIN>;
};

# Attempt to parse as JSON
my $data;
eval {
    $data = decode_json($input);
};
if ($@) {
    # Handle non-JSON input or parsing errors
    print encode_json({ status => 'error', message => 'Invalid JSON input' });
    exit;
}

# Process the received data (example: log it)
open my $fh, '>>', $logFile or die "Cannot open $logFile: $!";
print $fh "Received webhook at " . scalar(localtime) . ":\n";
my @names = $q->param;
foreach my $k (@names) {
	my $v = $q->param($k);
	print $fh "param $k => $v\n"; 
}

print $fh Dumper(\%ENV);
print $fh Dumper($data);

# Send a success response
print encode_json({ status => 'success', message => 'Webhook received and processed' });

#  fastfunnels form submit webhook
#
if (exists $data->{formName}) {
	if ($TIKTOK) {
		print $fh "calling tiktok webhook\n";
		# "test_event_code" => 'TEST20585',
		my $payload = {
			"event_source"=> "web",
			"event_source_id"=> "D3EAVTBC77UAH4NB4J4G",

			"data"=> [
				{
					"event"=> "Lead",
					"event_time"=> time(),
					"event_id"=> sprintf("%s_%s",time(),$$),
					"user"=> {
						"email"=> $data->{contact}->{email},
						"phone"=> $data->{contact}->{phone},
						"name"=> $data->{contact}->{name},
						"external_id"=> sprintf("%s",$data->{contact}->{id}),
						"ip"=> $ENV{REMOTE_ADDR},
						"user_agent"=> "Mozilla/, like Gecko) Chrome/129.0.0.0 Safari/537.36",
					},
					"limited_data_use" => 0,
					"page"=> {
						"url"=> "https://".$data->{website}->{domain},
					}
				}
			]
		};
		my $res = postJSON( 
			'https://business-api.tiktok.com/open_api/v1.3/event/track/',
			$payload, 
			{ 'Access-Token' =>'9bec27218b4143d2dd31da051e0b9dd1f34aafee' },
			$fh
		);
	}

	my $c = $data->{contact};
	my $message = sprintf("HappyTailsPawCare\nform %s\n%s\n%s\n%s\ntags [%s]", $data->{formName},$c->{name}, $c->{phone}, $c->{email}, join(',',@{$c->{tags}}));
	print $fh "sent text [$message]\n";
	`voip.ms.rest.pl -m "$message"`;
} else {
	#  voip.ms ssm/mms recieved
	#
	if (exists $data->{data} and exists $data->{data}->{event_type} and $data->{data}->{event_type} eq 'message.recieved') {
		my $text = $data->{data}->{payload};
		print $fh 'recieved '.$text->{type} . " from ".$text->{from}->{phone_number}."\n".$text->{text}."\n";
		`voip.ms.rest.pl -p`;
	}

	#  contact insert/update from fastfunnels.com
	#
	my @contact = qw/email name id phone properties/;
	my $c = sum map { exists $data->{$_} && 1; } @contact;
	if ($c == ($#contact + 1)) {
		print $fh "we have a contact upsert record\n";

		if ($MAKE) {
			my $header = {
				'x-make-apikey' => '6P-QHv2mAgHkKJ7',
			};
			my $payload = $data;
			my $res = postJSON( 
				"https://hook.us2.make.com/lwkxmdiw5bepvsv9fcqjr7aqptkwfisa", #call hook
				$payload, $header, $fh
			);
		}
		if ($N8N) {
			my $payload = $data;
			my $endpoint = 'https://leadtinfo.com:5678/webhook/CRMcontact';
			if (exists $payload->{n8n_test}) {
				$endpoint = 'https://leadtinfo.com:5678/webhook-test/CRMcontact';
			}
			my $res = postJSON($endpoint, $payload, {'webhook-auth' => '8yZe6An6nat4QNM'}, $fh);
		}

	}
}
	
close $fh;
