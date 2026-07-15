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

# Test byte counter wrap near the 4GB boundary (GH#6)
{
    my $near_4gb_blocks = 67108863; # (2^32 - 64) / 64
    my $state = "\0" x 16;
    my $data = "x" x 128; # two blocks, crosses the 4GB boundary

    my $ctx = Digest::MD5->new;
    $ctx->context($near_4gb_blocks, $state);
    $ctx->add($data);
    my ($blocks) = $ctx->context;
    is $blocks, $near_4gb_blocks + 2, "byte counter wraps correctly near 4GB boundary";
}

# Verify consistent digest across 4GB boundary via context save/restore
{
    my $ctx1 = Digest::MD5->new;
    $ctx1->add("a" x 1024);

    my $ctx2 = Digest::MD5->new;
    $ctx2->context($ctx1->context);
    $ctx2->add("b" x 512);

    my $expect = do {
        my $c = Digest::MD5->new;
        $c->add("a" x 1024);
        $c->add("b" x 512);
        $c->hexdigest;
    };
    is $ctx2->hexdigest, $expect, "context save/restore preserves digest across add";
}
