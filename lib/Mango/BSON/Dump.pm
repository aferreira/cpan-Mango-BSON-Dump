
package Mango::BSON::Dump;

# ABSTRACT: Helpers to dump Mango BSON documents as Extended JSON

use 5.010;
use Mojo::Base -strict;

use Mango::BSON ();
use Mojo::Util  ();
use re          ();    # regexp_pattern()
use JSON::XS    ();

sub to_extjson {
    my $doc = shift;
    state $encoder = JSON::XS->new->convert_blessed(1)->pretty(1);
    return $encoder->encode($doc) . "\n";
}

our %BINTYPE_MAP = (
    'generic'      => Mango::BSON::BINARY_GENERIC(),
    'function'     => Mango::BSON::BINARY_FUNCTION(),
    'md5'          => Mango::BSON::BINARY_MD5(),
    'uuid'         => Mango::BSON::BINARY_UUID(),
    'user_defined' => Mango::BSON::BINARY_USER_DEFINED(),
);

my %TO_EXTJSON = (

    # bson_bin
    'Mango::BSON::Binary' => sub {
        my $bindata = Mojo::Util::b64_encode( $_[0]->data, '' );
        my $type = unpack( "H2", $BINTYPE_MAP{ $_[0]->type // 'generic' } );
        { '$binary' => $bindata, '$type' => $type };
    },

    # bson_code
    'Mango::BSON::Code' => sub {
        $_[0]->scope
          ? { '$code' => $_[0]->code, '$scope' => $_[0]->scope }
          : { '$code' => $_[0]->code };
    },

    # bson_double
    # bson_int32
    # bson_int64
    'Mango::BSON::Number' => sub {
        ( $_[0]->type eq Mango::BSON::INT64() )
          ? { '$numberLong' => $_[0]->to_string }
          : $_[0]->value + 0    # DOUBLE() or INT32()
    },

    # bson_max
    'Mango::BSON::_MaxKey' => sub {
        { '$maxKey' => 1 };
    },

    # bson_min
    'Mango::BSON::_MinKey' => sub {
        { '$minKey' => 1 };
    },

    # bson_oid
    'Mango::BSON::ObjectID' => sub {
        { '$oid' => $_[0]->to_string };
    },

    # bson_time
    'Mango::BSON::Time' => sub {

        # {'$date' => {'$numberLong' => $_[0]->to_string . ''}}
        { '$date' => $_[0]->to_datetime };
    },

    # bson_ts
    'Mango::BSON::Timestamp' => sub {
        { '$timestamp' => { 't' => $_[0]->seconds, 'i' => $_[0]->increment } };
    },

    # regex
    'Regexp' => sub {
        my ( $p, $m ) = re::regexp_pattern( $_[0] );
        { '$regex' => $p, '$options' => $m };
    },

);

# Don't need TO_EXTJSON:
#   bson_doc
#   bson_dbref
#   bson_true
#   bson_false

for my $class ( keys %TO_EXTJSON ) {
    my $patch = $TO_EXTJSON{$class};
    Mojo::Util::monkey_patch( $class, TO_JSON => $patch );
}


1;

# https://docs.mongodb.com/manual/reference/mongodb-extended-json/
# https://docs.mongodb.com/manual/reference/bson-types/
# http://bsonspec.org/
# https://github.com/mongodb/specifications/tree/master/source/bson-corpus

__END__

