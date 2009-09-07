package Zonestat::DBI::Result::Server;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('server');
__PACKAGE__->add_columns(
    qw[id kind country ip asn city latitude longitude run_id domain_id created_at]
);

# http://maps.google.com/maps?q=<latitude>+<longitude>
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    domain => 'Zonestat::DBI::Result::Domains',
    'domain_id'
);
__PACKAGE__->belongs_to(testrun => 'Zonestat::DBI::Result::Testrun', 'run_id');

1;
