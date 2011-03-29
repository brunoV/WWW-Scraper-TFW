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

has _url      => ( is => 'ro', lazy => 1, builder => '_build_url' );
has _response => ( is => 'ro', lazy => 1, builder => '_build_response' );

has temperature => ( is => 'ro', lazy => 1, builder => '_build_temperature' );
has remark      => ( is => 'ro', lazy => 1, builder => '_build_remark' );
has forecast    => ( is => 'ro', lazy => 1, builder => '_build_forecast' );

sub _build_url {
    my $self = shift;

    my $uri     = URI->new('http://www.thefuckingweather.com');
    my $celsius = $self->celsius ? 'yes' : 'no';

    $uri->query_form( zipcode => $self->city, CELSIUS => $celsius );

    return $uri;
}

sub _build_response {
    my $self = shift;

    my $response = LWP::UserAgent->new->get( $self->_url )->as_string;

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

    my @rows = @{ $result->{rows} };

    my ($days, $high, $low, $weather) = map { $_->{columns} } @rows;

    my @forecast;
    for my $i (1..2) {
        push @forecast,
          {
            day      => $days->[$i],
            high     => $high->[$i],
            low      => $low->[$i],
            weather  => $weather->[$i]
          };
    }

    return \@forecast;
}

=head1 SYNOPSIS

    use WWW::Scraper::TFW;
    my $tfw = WWW::Scraper::TFW->new( city => 'La Plata', celsius => 1 );

    say $tfw->temperature;
    # 20º?! ITS FUCKING NICE!

    say $tfw->remark;
    # Enjoy.

    # Tomorrow's high
    say $tfw->forecast->[0]{high}
    # 22

=cut

=head1 DESCRIPTION

This module scrapes L<thefuckingweather.com> with your preferred
city/zipcode and makes the weather information (along with some colorful
comments) available to you.

=cut

=attr city

The name of the city or zipcode whose weather you want to find out
about. You'll be insulted if either are incorrect.

This attribute is required at construction time and is read only.

=cut

=attr celsius

Set this attribute to true at construction time to have the temperature
in celsius degrees. Defaults to false.

=cut

=attr temperature

The current temperature of the specified location.

=cut

=attr remark

A remark on the current weather.

=cut

=attr forecast

Forecast for the following two days. Returns an array reference that
typically looks like:

    [
      {
        day     => 'Mon',
        high    => 22,
        low     => 13,
        weather => 'Clear',
      },
      {
        day     => 'Tue',
        high    => 24,
        low     => 13,
        weather => 'Sunny',
      }
    ];

=cut

1;
