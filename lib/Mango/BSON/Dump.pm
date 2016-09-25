
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

# bson_bin
Mojo::Util::monkey_patch 'Mango::BSON::Binary', TO_JSON => sub {
    my $bindata = Mojo::Util::b64_encode( $_[0]->data, '' );
    my $type = unpack( "H2", $BINTYPE_MAP{ $_[0]->type // 'generic' } );
    { '$binary' => $bindata, '$type' => $type };
};

# bson_code
Mojo::Util::monkey_patch 'Mango::BSON::Code', TO_JSON => sub {
    $_[0]->scope
      ? { '$code' => $_[0]->code, '$scope' => $_[0]->scope }
      : { '$code' => $_[0]->code };
};

# bson_double
# bson_int32
# bson_int64
Mojo::Util::monkey_patch 'Mango::BSON::Number', TO_JSON => sub {
    ( $_[0]->type eq Mango::BSON::INT64() )
      ? { '$numberLong' => $_[0]->to_string }
      : $_[0]->value + 0    # DOUBLE() or INT32()
};

# bson_max
Mojo::Util::monkey_patch 'Mango::BSON::_MaxKey', TO_JSON => sub {
    { '$maxKey' => 1 };
};

# bson_min
Mojo::Util::monkey_patch 'Mango::BSON::_MinKey', TO_JSON => sub {
    { '$minKey' => 1 };
};

# bson_oid
Mojo::Util::monkey_patch 'Mango::BSON::ObjectID', TO_JSON => sub {
    { '$oid' => $_[0]->to_string };
};

# bson_time
Mojo::Util::monkey_patch 'Mango::BSON::Time', TO_JSON => sub {

    #     {'$date' => {'$numberLong' => $_[0]->to_string . ''}}
    { '$date' => $_[0]->to_datetime };
};

# bson_ts
Mojo::Util::monkey_patch 'Mango::BSON::Timestamp', TO_JSON => sub {
    { '$timestamp' => { 't' => $_[0]->seconds, 'i' => $_[0]->increment } };
};

# regex
Mojo::Util::monkey_patch 'Regexp', TO_JSON => sub {
    my ( $p, $m ) = re::regexp_pattern( $_[0] );
    { '$regex' => $p, '$options' => $m };
};

# Don't need TO_JSON:
#   bson_doc
#   bson_dbref
#   bson_true
#   bson_false

1;

# https://docs.mongodb.com/manual/reference/mongodb-extended-json/
# https://docs.mongodb.com/manual/reference/bson-types/
# http://bsonspec.org/
# https://github.com/mongodb/specifications/tree/master/source/bson-corpus

__END__

