use Test::More;
use Test::WWW::Mechanize::Catalyst;

$ENV{ZONESTAT_CONFIG_FILE} = 't/config/Config';
$ENV{TZ} = 'CET'; # Some tests are time zone sensitive.

my $version = Test::WWW::Mechanize::Catalyst->VERSION;
my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'Statweb' );

$mech->get_ok( '/' );
$mech->title_like( qr'.SE | H..?lsol..?get i Sverige' );
$mech->submit_form_ok(
    {
        form_number => 1,
        fields      => {
            username => 'someuser',
            password => 'somepwd'
        }
    },
    'Posting login form'
);
$mech->title_is( 'Statweb' );

is_deeply [ sort map { $_->url } $mech->followable_links ], [ 'http://localhost/', 'http://localhost/domainset/testset', 'http://localhost/enqueue/testset', 'http://localhost/showstats/dnscheck', 'http://localhost/showstats/index', 'http://localhost/showstats/servers', 'http://localhost/showstats/webpages', 'http://localhost/static/css/default.css', 'http://localhost/testrun/1', 'http://localhost/toggletestrun/1', 'http://localhost/user/logout' ], 'Expected links seen.';

$mech->content_lacks( '<li class="selected">' );
$mech->get_ok( '/toggletestrun/1' );
$mech->content_contains( '<li class="selected">' );
$mech->get_ok('/clearselection');
$mech->content_lacks( '<li class="selected">' );
$mech->get_ok( '/toggletestrun/1' );
$mech->content_contains( '<li class="selected">' );

$mech->get_ok( '/testrun/1' );
$mech->content_contains( '<h1>Testrun testset 2012-06-14 14:50</h1>' );
is_deeply [ sort map { $_->url } $mech->followable_links ], [ 'http://localhost/', 'http://localhost/showstats/dnscheck', 'http://localhost/showstats/index', 'http://localhost/showstats/servers', 'http://localhost/showstats/webpages', 'http://localhost/static/css/default.css', 'http://localhost/testrun/1/detail/handelsbanken.se', 'http://localhost/testrun/1/detail/iis.se', 'http://localhost/testrun/1/detail/nic.se', 'http://localhost/testrun/1/detail/pts.se', 'http://localhost/testrun/1/detail/riksdagen.se', 'http://localhost/user/logout' ], 'Expected links seen.';

$mech->get_ok( '/testrun/1/detail/nic.se' );

$mech->get_ok( '/showstats/index' );
$mech->text_like( qr/Domains using IPv6[^%]*60\.00%/ ) if $version >= 0.58;

$mech->get_ok( '/showstats/dnscheck' );
$mech->text_like( qr/ADDRESS:PTR_NOT_FOUND[^%]+20\.00%/ ) if $version >= 0.58;

$mech->get_ok( '/showstats/servers' );
$mech->title_is( 'Mail-, HTTP- and DNS-server Statistics' );
$mech->text_contains( 'Top 25 Nameservers for each runtestset 2012-06-14 ' ) if $version >= 0.58;

$mech->get_ok( '/showstats/webpages' );
$mech->text_contains( 'Apache 40.0%' ) if $version >= 0.58;

$mech->get_ok('/showstats/view_by_level/error/1');
$mech->content_contains('<td class="numeric">137</td>');

$mech->get_ok('/csv/webserver_software_http');
$mech->content_contains('"Microsoft IIS",1');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/csv/webserver_software_https');
$mech->content_contains('Apache,1');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/csv/webserver_response_http');
$mech->content_contains('200,5');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/csv/webserver_response_https');
$mech->content_contains('200,2');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/csv/webserver_content_http');
$mech->content_contains('text/html,5');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/csv/webserver_content_https');
$mech->content_contains('text/html,2');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/csv/webserver_charset_http');
$mech->content_contains('utf-8,4');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/csv/webserver_charset_https');
$mech->content_contains('utf-8,1');
is($mech->ct, 'text/comma-separated-values', 'Correct Content-Type');

$mech->get_ok('/domainset/testset');
$mech->content_contains('handelsbanken.se');
$mech->get_ok('/domainset/testset/delete/handelsbanken.se');
$mech->content_lacks('handelsbanken.se');
$mech->post_ok('/domainset/testset/add',{domainname => 'handelsbanken.se'});
$mech->content_contains('handelsbanken.se');
$mech->post_ok('/domainset/create', {name => 'newset'});
$mech->content_contains('newset');

$mech->get_ok('/tests/1/handelsbanken.se');
$mech->content_contains('SOA:TTL_OK');

$mech->get_ok('/enqueue/testset');
$mech->text_contains('Queue Length5') if $version >= 0.58;

$mech->get('/supercalifragilisticexpialidocious');
ok(!$mech->success, 'Failed to get non-existant URL');
is($mech->status, 404, 'Response to above is 404');

$mech->get_ok( '/user/logout' );
$mech->title_like( qr'.SE | H..?lsol..?get i Sverige' );
$mech->content_contains( 'Username:' );
$mech->content_contains( 'Password:' );

done_testing;
