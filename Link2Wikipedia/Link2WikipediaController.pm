package Koha::Plugin::HKS3Link2Wikipedia::Link2Wikipedia::Link2WikipediaController;

use Mojo::Base 'Mojolicious::Controller';

use C4::Context;
use C4::Debug;
use C4::Output qw(:html :ajax pagination_bar);

use HTTP::Request;
use LWP::UserAgent;

# use JSON;

my $header = ['Content-Type' => 'application/json; charset=UTF-8'];

use Mojo::JSON qw(decode_json encode_json);

my $translate = {
    'de-DE' =>
        {dt      => 'https://cdn.datatables.net/plug-ins/1.10.21/i18n/German.json',
         columns => ['Daten', 'Band', 'Jahr', 'Cover'],
         label   => 'Bände',
        },
    'si-SI' =>
        {dt      => 'https://cdn.datatables.net/plug-ins/1.10.21/i18n/Slovenian.json',
        }
};

sub gnd_redirect {
    my $gnd = shift;
    my $url='https://persondata.toolforge.org/redirect/gnd/de/';
    my $request = HTTP::Request->new(GET => $url.$gnd);
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($request);
    my @redirects = $response->redirects;
    my $location = $redirects[-1]->headers->{location};
    $location =~ /.*\/(.*$)/;
    return ($location, $1);
}

sub get_extract {
    my $title = shift;
    my $article_url = 'https://de.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro&explaintext&redirects=1&titles='.$title;
    my $r = HTTP::Request->new('GET', $article_url, $header);
    my $ua = LWP::UserAgent->new();
    my $res = $ua->request($r);
    my $content = decode_json($res->content);
    my @keys = keys %{$content->{query}->{pages}};
    return $content->{query}->{pages}->{$keys[0]}->{extract}
}

sub get_pageimage {
    my $title = shift;
    my $pageimage_url = 'https://de.wikipedia.org/w/api.php?format=json&action=query&prop=pageimages&redirects=1&pithumbsize=200&titles='.$title;
    my $r = HTTP::Request->new('GET', $pageimage_url, $header);
    my $ua = LWP::UserAgent->new();
    my $res = $ua->request($r);
    my $content = decode_json($res->content);
    my @keys = keys %{$content->{query}->{pages}};
    return $content->{query}->{pages}->{$keys[0]}->{thumbnail}->{source};
}

sub get {
    my $c = shift->openapi->valid_input or return;
    my $gnd_id = $c->validation->param('id');
    my ($wikipedia_url, $wikipedia_title) = gnd_redirect($gnd_id);
    my $content = get_extract($wikipedia_title);
    my $image_url = get_pageimage($wikipedia_title);

    return $c->render( status => 200, openapi => {
        content => $content,
        wikipedia_url => $wikipedia_url,
        image_url => $image_url,
    } );

}

1;
