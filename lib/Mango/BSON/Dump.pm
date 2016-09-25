
package Mango::BSON::Dump;

# ABSTRACT: Helpers to dump Mango BSON documents as Extended JSON

use 5.010;
use Mojo::Base -strict;

use Mango::BSON ();
use Mojo::Util  ();
use re          ();    # regexp_pattern()
use JSON::XS    ();

use Exporter 5.57 'import';
our @EXPORT_OK = qw(to_extjson);

sub to_extjson {
    my $doc = shift;
    state $encoder = JSON::XS->new->convert_blessed(1);
    my %opts = (pretty=>0,@_);
    $encoder->$_($opts{$_}) for qw(pretty);
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


__END__


=head1 SYNOPSIS

    use Mango::BSON ':bson';
    use Mango::BSON::Dump qw(to_extjson);

    #  '{"v":{"$numberLong":"42"},"created":{"$date":"1970-01-01T00:00:00Z"}}'
    to_extjson(bson_doc(v => bson_int64(42), created => bson_time(0)));

    use Mojo::JSON qw(encode_json);

    #  '{"v":{"$numberLong":"42"},"created":{"$date":"1970-01-01T00:00:00Z"}}'
    encode_json(bson_doc(v => bson_int64(42), created => bson_time(0)));

=head1 DESCRIPTION

This module enables dumping Mango BSON documents and objects
as Extended JSON (see L<https://docs.mongodb.com/manual/reference/mongodb-extended-json/>),
which might be handy for development and debugging.

=head1 FUNCTIONS

=over 4

=item B<to_extjson>

    $json = to_extjson($bson_doc);
    $json = to_extjson($bson_doc, pretty => 1);

Encodes C<$bson_doc> into Extended JSON.

=back

=head1 CAVEATS

This module installs C<TO_JSON> methods to a number of packages
(eg. Mango::BSON::Number, Mango::BSON::ObjectID, Regexp).
This does not play well with other modules defining or installing
the same methods to the same classes.
As of Mango 1.29, this clashes with defined C<TO_JSON>
for Mango::BSON::Binary, Mango::BSON::Number, and Mango::BSON::Time
(which don't conform to Extended JSON).

=head1 SEE ALSO

    https://docs.mongodb.com/manual/reference/mongodb-extended-json/

    https://docs.mongodb.com/manual/reference/bson-types/

    http://bsonspec.org/

    https://github.com/mongodb/specifications/tree/master/source/bson-corpus

=head1 ACKNOWLEDGMENTS

The development of this library has been partially sponsored by Connectivity, Inc.
