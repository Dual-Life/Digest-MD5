#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 37;
use Digest::MD5;

foreach my $length (
    1..17,
    31..33,
    63..65,
    127..129,
    191..193,
    1023..1025,
    2047..2049,
) {
    my $string =  'a' x $length;

    my $expect = do {
        my $ctx = Digest::MD5->new;
        $ctx->add($string);
        $ctx->add($string);
        $ctx->add($string);
        $ctx->hexdigest;
    };

    my $got = do {
        my $ctx1 = Digest::MD5->new;
        $ctx1->add($string);

        my $ctx2 = Digest::MD5->new;
        $ctx2->context( $ctx1->context );
        $ctx2->add($string);

        my $ctx3 = Digest::MD5->new;
        $ctx3->context( $ctx2->context );
        $ctx3->add($string);

        $ctx3->hexdigest;
    };

    is $got, $expect, "[$length] saved context";
}

# Validate that context() croaks on short state buffer
eval { Digest::MD5->new->context(0, "short") };
like $@, qr/must be exactly 16 bytes/, "context() croaks on short state buffer";

# Validate that context() croaks on overlong unprocessed data
eval { Digest::MD5->new->context(0, "\0" x 16, "x" x 64) };
like $@, qr/must be at most 63 bytes/, "context() croaks on overlong data buffer";
