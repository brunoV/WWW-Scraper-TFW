use strict;
use warnings;
use Test::More;
use Test::Exception;

use_ok 'WWW::Scraper::TFW';

my $tfw = WWW::Scraper::TFW->new( city => 'La Plata' );
ok $tfw, 'Object created ok';
is $tfw->celsius, 0, 'default celsius no';

can_ok $tfw, qw(remark temperature forecast);

dies_ok { WWW::Scraper::TFW->new }, 'dies without city';

$tfw = WWW::Scraper::TFW->new( city => 'La Plata', celsius => 1 );
ok $tfw, 'Object created ok';
is $tfw->celsius, 1,          'celsius set ok';
is $tfw->city,    'La Plata', 'celsius set ok';

ok $tfw->temperature, 'Temperature is set';
like $tfw->temperature, qr/\d+º\?\! ITS.+$/, 'Temperature looks good';
diag $tfw->temperature;

ok $tfw->remark, 'Remark is set';
diag $tfw->remark;

ok my $forecast = $tfw->forecast, 'Forecast is set';

is ref $forecast, 'ARRAY', 'Forecast looks good';
is scalar @$forecast, 2, 'Forecast of two days';

is ref $forecast->[0], 'HASH', 'Forecast looks good';
is_deeply(
    [ sort keys %{ $forecast->[0] } ],
    [ 'day', 'high', 'low', 'weather' ],
    'Forecast looks good'
);

done_testing();
