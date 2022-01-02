package Koha::Plugin::HKS3Link2Wikipedia::Link2Wikipedia;

use Modern::Perl;

use base qw(Koha::Plugins::Base);
use C4::Context;
use Cwd qw(abs_path);

use Koha::Authorities;
use C4::AuthoritiesMarc;

use Mojo::JSON qw(decode_json);;

our $VERSION = "0.2";

our $metadata = {
    name            => 'Link2Wikipedia Plugin',
    author          => 'Mark Hofstetter',
    date_authored   => '2021-02-05',
    date_updated    => "2021-02-05",
    minimum_version => '19.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'this plugin generates extracts & links to wikipedia articles via GND lookup http://tools.wmflabs.org/persondata/redirect/gnd/de/',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);
    $self->{cgi} = CGI->new();

    return $self;
}

sub api_routes {
    my ( $self, $args ) = @_;
    my $spec_str = $self->mbf_read('openapi.json');
    my $spec = decode_json($spec_str);
    return $spec;
}

sub api_namespace {
    my ( $self ) = @_;
    return 'link2wikipedia';
}

sub opac_head {
    my ( $self ) = @_;
    return undef;
}

sub opac_js {
    my ( $self ) = @_;
    my $cgi = $self->{'cgi'};
    return unless $cgi->script_name =~ /opac-authoritiesdetail.pl/;
    my $authid = $cgi->param('authid');
    return unless $authid;
    my $record = GetAuthority( $authid );

    my $authority = Koha::Authorities->find( $authid );
    return undef unless $record->field('035');
    my @f35 =  $record->field('035')->subfields;
    my $gnd = $f35[0][1];
    $gnd =~ s/\(.*\)//;

    my $js = "<script> var gnd = '$gnd' \n";
    $js .= <<'JS';
    var page = $('body').attr('ID');
    var lang = $('html').attr('lang');
    if (page == "opac-authoritiesdetail") {

        $(function(e) {
            var ajaxData = { 'id': gnd };
            $.ajax({
              url: '/api/v1/contrib/link2wikipedia/gnd',
            type: 'GET',
            dataType: 'json',
            data: ajaxData,
        })
        .done(function(data) {
            // console.log('fetched data from wikipedia');
            $('<div class="newscontainer"><div class="media"><span class="label">Wikipedia</span><br>' +
            '<span class="float-left media-left mx-2"><img id="wikipedia_image" src=""/></span>' +
            '<div class="media-body"><div id="wikipedia_extract"></div><a id="wikipedia_url" target="_blank" href="#">' +
            '<img src="https://upload.wikimedia.org/wikipedia/commons/6/62/Banner_80x15.png"></a></div></div></div>')
            .insertAfter( ".usedin" );
            $('#wikipedia_extract').html(data.content);
            $("#wikipedia_url").attr("href", data.wikipedia_url);
            $("#wikipedia_image").attr("src", data.image_url).load(function(){
                 this.width;
                });

            })
        .error(function(data) {});
        });

    }
    </script>
JS

    return $js;
}
