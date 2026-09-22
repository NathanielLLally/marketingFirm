requires 'perl', '5.020000';

# Core / Pragmas
requires 'strict';
requires 'warnings';

# Core Utilities
requires 'Carp';
requires 'Time::HiRes';
requires 'Time::Piece';
requires 'Time::Seconds';
requires 'File::Basename';
requires 'File::Spec';
requires 'Sys::Hostname';

# Modern Perl
requires 'Modern::Perl';
requires 'feature';

# Exception Handling
requires 'Try::Tiny';

# Database
requires 'DBI';
requires 'DBD::CSV';
requires 'DBD::Pg', '3.00';

# Configuration
requires 'Config::Tiny';

# HTTP & Web
requires 'LWP::UserAgent';
requires 'LWP::Parallel::UserAgent';
requires 'HTTP::Request';
requires 'HTTP::Request::Common';
requires 'HTTP::Response';
requires 'HTTP::Cookies';
requires 'HTTP::Message';
requires 'HTTP::Headers';
requires 'Net::SSLeay';
requires 'IO::Socket::SSL';

# Async / Concurrency
requires 'AnyEvent';
requires 'Coro';
requires 'Coro::AnyEvent';
requires 'AnyEvent::HTTP';
requires 'AnyEvent::UserAgent';

# HTML Parsing
requires 'HTML::Parser';
requires 'HTML::Tagset';
requires 'HTML::Element';
requires 'HTML::TreeBuilder';
requires 'HTML::TreeBuilder::Select';

# URI / URL Handling
requires 'URI::Find';
requires 'URI::Encode';
requires 'URI::Escape';
requires 'URI::Simple';
requires 'URI::URL';
requires 'PURI';

# Data Processing
requires 'Text::CSV_XS';
requires 'JSON';
requires 'Data::Dumper';
requires 'Data::Serializer';
requires 'Tie::IxHash';
requires 'Storable';

# Optional: if you want to use threads in addition to Coro
# requires 'threads';

# Development / Testing (optional)
on 'develop' => sub {
  requires 'Perl::Tidy';
  requires 'Perl::Critic';
};

# Testing (optional)
on 'test' => sub {
  requires 'Test::More';
  requires 'Test::Simple';
};
