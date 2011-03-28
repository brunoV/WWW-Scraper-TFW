use strict;
use warnings;

# ABSTRACT: Show weather information from thefuckingweather.com

package WWW::Scraper::TFW;
use Moo;
use Web::Scraper;
use LWP::UserAgent;
use URI;

has city    => ( is => 'ro', required => 1);
has celsius => ( is => 'ro', default => sub { 0 } );

has _ua => ( is => 'ro', default => sub { LWP::UserAgent->new; } );
has _base_url => (
    is      => 'ro',
    default => sub { URI->new('http://www.thefuckingweather.com') }
);

has _url => ( is => 'ro', lazy => 1, builder => '_build_url' );
has _response => ( is => 'ro', lazy => 1, builder => '_build_response' );

has temperature => ( is => 'ro', lazy => 1, builder => '_build_temperature' );
has remark      => ( is => 'ro', lazy => 1, builder => '_build_remark' );
has forecast    => ( is => 'ro', lazy => 1, builder => '_build_forecast' );

sub _build_url {
    my $self = shift;

    my $uri     = $self->_base_url->clone;
    my $celsius = $self->celsius ? 'yes' : 'no';

    $uri->query_form( zipcode => $self->city, CELSIUS => $celsius );

    return $uri;
}

sub _build_response {
    my $self = shift;

    my $response = $self->_ua->get( $self->_url )->as_string;

    $response or die "No response from " . $self->_url . "\n";

}

sub _build_temperature {
    my $self = shift;

    my $s = scraper {
        process '.large', 'text' => 'TEXT';
    };

    my $temp = $s->scrape( $self->_response );

    # Space between ?! and 'ITS...'
    $temp->{text} =~ s/\!/\! /;

    # Replace the degree symbol for º
    $temp->{text} =~ s/^([-]*\d+)./$1º/;

    return $temp->{text};
}

sub _build_remark {
    my $self = shift;

    my $s = scraper {
        process '#remark', text => 'TEXT';
    };

    my $remark = $s->scrape( $self->_response );

    return $remark->{text};
}

sub _build_forecast {
    my $self = shift;

    my $s = scraper {
        process "div.boxbody tr", 'rows[]' => scraper {
            process "td", 'columns[]' => 'TEXT';
        };
    };

    my $result = $s->scrape( $self->_response );

    die "Error parsing the forecast\n" unless $result and @{$result->{rows}} == 4;

    my $forecast = _assemble_forecast( $result );

    return $forecast;
}

sub _assemble_forecast {
    my $result = shift;

    my @forecast;

    my @rows = @{ $result->{rows} };

    my @days     = @{ (shift @rows)->{columns} }[1..2];
    my @high     = @{ (shift @rows)->{columns} }[1..2];
    my @low      = @{ (shift @rows)->{columns} }[1..2];
    my @weather  = @{ (shift @rows)->{columns} }[1..2];

    for my $i (0..1) {
        push @forecast,
          {
            day      => $days[$i],
            high     => $high[$i],
            low      => $low[$i],
            weather  => $weather[$i]
          };
    }

    return \@forecast;
}

1;
