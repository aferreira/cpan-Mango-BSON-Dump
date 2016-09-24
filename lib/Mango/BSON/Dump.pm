
package Mango::BSON::Dump;
# ABSTRACT: Helpers to dump Mango BSON documents as Extended JSON

use Mojo::Base -strict;

use Mango::BSON ();
use Mojo::Util ();
use JSON::XS;

my $encoder = JSON::XS->new->convert_blessed(1)->pretty(1);

sub to_extjson {
    my $doc = shift;
    state $encoder = JSON::XS->new->convert_blessed(1)->pretty(1);
    return $encoder->encode($doc) . "\n";
}

# bson_bin
our %BINTYPE_MAP = (
    'generic'      => Mango::BSON::BINARY_GENERIC(),
    'function'     => Mango::BSON::BINARY_FUNCTION(),
    'md5'          => Mango::BSON::BINARY_MD5(),
    'uuid'         => Mango::BSON::BINARY_UUID(),
    'user_defined' => Mango::BSON::BINARY_USER_DEFINED(),
);

sub Mango::BSON::Binary::TO_JSON {
    my $bindata = Mojo::Util::b64_encode($_[0]->data, '');
    my $type = unpack( "H2", $BINTYPE_MAP{ $_[0]->type } );
    { '$binary' => $bindata, '$type' => $type };
}

# bson_code
sub Mango::BSON::Code::TO_JSON {
    $_[0]->scope
      ? { '$code' => $_[0]->code, '$scope' => $_[0]->scope }
      : { '$code' => $_[0]->code };
}

# bson_double
# bson_int32
# bson_int64
sub Mango::BSON::Number::TO_JSON {
    if ( $_[0]->type eq Mango::BSON::INT64() ) {
        return { '$numberLong' => $_[0]->to_string };
    }
    else {    # DOUBLE() or INT32()
        return $_[0]->value + 0;
    }
}

# bson_max
sub Mango::BSON::_MaxKey::TO_JSON { { '$maxKey' => 1 } }

# bson_min
sub Mango::BSON::_MinKey::TO_JSON { { '$minKey' => 1 } }

# bson_oid
sub Mango::BSON::ObjectID::TO_JSON {
    { '$oid' => $_[0]->to_string };
}

# bson_time
sub Mango::BSON::Time::TO_JSON {

    #     {'$date' => {'$numberLong' => $_[0]->to_string . ''}}
    { '$date' => $_[0]->to_datetime };
}

# bson_ts
sub Mango::BSON::Timestamp::TO_JSON {
    { '$timestamp' => { 't' => $_[0]->seconds, 'i' => $_[0]->increment } };
}

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

