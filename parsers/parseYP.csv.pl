#!/usr/bin/perl -w 
use strict;
use HTML::Parser ();
use HTML::Tagset ();
use HTML::Element;
use HTML::TreeBuilder;
use HTML::TreeBuilder::Select;
use URI;
use Data::Dumper;

#https://www.yellowpages.com/search?search_terms=%20Home%20Improvement%20%26%20Remodeling&geo_location_terms=Las%20Vegas%2C%20NV%3Fpage%3D2&page=1
# use warnings;
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
#print "$file\n";

my $parser = new HTML::TreeBuilder::Select; 

if (-e $file) {
  $parser->parse_file($file) || die "Can't open file $file: $!\n";
} else {
  local $/;
  undef $/;
  my $content = <STDIN>;
  $parser->parse($content) || die "Can't open file $file: $!\n";
}

my @elements;
my $tag;
#@elements = $parser->select("div.info div.adr");
# xp->findnodes('//@att[.=~ /^v.$/]');
#

#@elements = $parser->select("div.info");

my @div = $parser->look_down(_tag => 'div', class=>'info');

=head1 all_attr_values

  for -> phone, phones phone primary

  street-address
  adr

  $h->all_attr_names();

=cut


my $ent={};
my $nfo;
foreach my $el (@div) {
    my $css = 'business-name';
    my @tags = $el->look_down(class => $css);
    my $tag;
    $nfo = {};

    $nfo->{Name} = $tags[0]->as_text;

    $css = 'track-visit-website';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    $nfo->{Website} = (defined $tag) ? $tag->attr('href') : "";

    $css = 'bbb-rating';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    $nfo->{Tags} = (defined $tag) ? "BBB-Accredited" : "";

    #    my $info = $parser->parse($el);
    #my @el = $info->select("div[class*=phone]");
    #foreach my $i (@el) {
    #    print $i->as_text."\n";
    #}

    #TODO
    #    my @css = ('phone', 'phones phone primary', 
    $css = 'phone';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    if (defined $tag) {
        $nfo->{Phone} = $tag->as_text;
    } else {
        $css = 'phones phone primary';
        @tags = $el->look_down(class => $css);
        $tag = shift @tags;
        $nfo->{Phone} = (defined $tag) ? $tag->as_text : "";
    }

    #TODO performance
    $css = 'street-address';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;

    $css = 'adr';
    @tags = $el->look_down(class => $css);
    my $elsetag = shift @tags;
    $nfo->{Address} = (defined $tag) ? $tag->as_text : ((defined $elsetag) ? $elsetag->as_text : "Cloud 9, Apt 7A, HV");

    $css = 'locality';
    @tags = $el->look_down(class => $css);
    $tag = shift @tags;
    #$nfo->{$css} = (defined $tag) ? $tag->as_text : "";
    if (defined $tag) {
      $tag = $tag->as_text;

      if ($tag =~ /(.*?)\,.?(\w\w).?(\d+)/ ) {
        ($nfo->{City}, $nfo->{State}, $nfo->{Zip}) = ($1, $2, $3);
      }
    }

    my $email = "bogus_".$nfo->{'Address'}.'@'.$nfo->{'Name'};
    $email =~ s/\s//g;
    $email =~ s/[\.\,]/_/g;
    $nfo->{'Email'} = $email.".com";
    $ent->{$nfo->{'Name'}} = $nfo;
}

#print Dumper(\$ent);

# walk & out csv
#
#$VAR1 = \{
#    'Chiropractic Treatment' => {
#        'phone' => '',
#        'track-visit-website' => '',
#
my @headers;
my @sheet;
foreach my $biz (keys %$ent) {
    if ($#headers <= 0) { 
        foreach my $itm (sort keys %{$ent->{$biz}}) {
            push @headers, $itm;
        }
        #print join(',', @headers);
    }
    #print "\n";

    my @line;
    foreach my $itm (sort keys %{ $ent->{$biz} }) {
      $ent->{$biz}->{$itm} =~ s/\"//g;
      push @line, "\"".$ent->{$biz}->{$itm}."\"";
    }
    print join(',',@line); 
    print "\n";
}


