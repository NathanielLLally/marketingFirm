#!/usr/bin/perl

use strict;
use HTML::Parser ();
use HTML::Tagset ();
use HTML::Element;
use HTML::TreeBuilder;
use URI;
use Data::Dumper;

#use warnings;
#  CSS classes
#    
#  business-name
#    href
#
#  info-section
#    ><div
#    phones phone phone primary
#    street-address
#    locality
#      city state zip
#
#  track-visit-website
#    href 
#

=head1  walked my own

my ($classes,$class,$subclass,$href,$text,$text2) = ("" x 6);
#while ($f =~ /class.?.?\=.*?\"(.*?)\".*?((href.*?\=.*?\"(.*?)\".*?\>)|(div.*?(class=\"(.*?)\")?.*?\>(.*?)\<\/))/gc) {

while ($f =~ /class.?.?\=.*?\"(.*?)\"(.*?href.?\=.?\"(.*?)\")?/gc) {
  $classes = $1;
  $href = $3;
  print "$classes\n$2\n$href\n\n";
}
exit;


while ($f =~ /class.?.?\=.*?\"(.*?)\".*?div.*?class=\"(.*?)\".*?\>(.*?)\<\/div/gc) {
  $class = $1;
  $subclass = $2;
  $text = $3;
  print "$class\n$subclass\n$text\n\n";
}

=cut

my $file = shift @ARGV;
print "$file\n";

my $parser = HTML::TreeBuilder->new; 

$parser->parse_file($file) || die "Can't open file $file: $!\n";

my @div = $parser->look_down(_tag => 'div', class=>'info');

#my @div = $parser->find_by_tag_name('div');

my $nfo = {};
foreach my $el (@div) {
    
    my $css = 'business-name';
    my @tags = $el->look_down(class => $css);
    my $tag;
    $nfo->{$css} = $tags[0]->as_text;

    $css = 'track-visit-website';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    $nfo->{$css} = (defined $tag) ? $tag->attr('href') : "";

    $css = 'bbb-rating';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    $nfo->{$css} = (defined $tag) ? $tag->as_text: "";

    $css = 'phone';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    $nfo->{$css} = (defined $tag) ? $tag->as_text : "";

    #TODO performance
    $css = 'street-address';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;

    $css = 'adr';
    @tags = $el->look_down(class => $css);
    my $elsetag = shift @tags;
    $nfo->{$css} = (defined $tag) ? $tag->as_text : $elsetag->as_text;

    $css = 'locality';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    $nfo->{$css} = (defined $tag) ? $tag->as_text : "";

    print Dumper(\$nfo);
}


