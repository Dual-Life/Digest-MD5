#!/usr/bin/perl
# Test that byte counter handles values >= 2^32 correctly.
# Regression test for GitHub issue #6 / rt.cpan.org #123185
# where MD5Update's 32-bit byte counter overflowed for inputs >= 8 GiB.

use strict;
use warnings;
use Test::More;
use Config;

# This test only makes sense on 64-bit systems where STRLEN > 32 bits
if ($Config{ptrsize} < 8) {
    plan skip_all => '64-bit system required';
}

plan tests => 3;

use Digest::MD5;

# Test 1: Verify byte counter tracks correctly across the 4 GiB boundary.
# Set context to just below 4 GiB, add data that crosses, check block count.
{
    my $ctx = Digest::MD5->new;
    my ($b0, $s0) = $ctx->context;

    # Set to (2^26 - 1) blocks = 4 GiB - 64 bytes
    my $near_boundary = (1 << 26) - 1;
    $ctx->context($near_boundary, $s0);

    # Add 128 bytes (2 blocks) to cross the 4 GiB boundary
    $ctx->add("\x00" x 128);

    my ($blocks_after) = $ctx->context;
    is($blocks_after, $near_boundary + 2,
       'block count correct after crossing 4 GiB boundary');
}

# Test 2: Verify context round-trips above 4 GiB.
{
    my $ctx = Digest::MD5->new;
    my ($b0, $s0) = $ctx->context;

    # Set to 2^27 blocks = 8 GiB
    my $target_blocks = 1 << 27;
    $ctx->context($target_blocks, $s0);
    my ($b2) = $ctx->context;

    is($b2, $target_blocks,
       'context round-trips block count above 4 GiB');
}

# Test 3: Verify that the digest is correct when byte counter crosses 4 GiB.
# We feed the same initial state and same data, but at two different
# "virtual" byte offsets that should produce the same final block count
# and same data path — one set via context, one built incrementally from
# that context with identical data.
{
    my $ctx = Digest::MD5->new;
    my ($b0, $s0) = $ctx->context;

    # Set near 4 GiB boundary and add 128 bytes
    my $near = (1 << 26) - 1;
    my $ctx1 = Digest::MD5->new;
    $ctx1->context($near, $s0);
    $ctx1->add("\xAB" x 64);
    # Capture state after first 64 bytes
    my ($b1, $s1, $buf1) = $ctx1->context;
    $ctx1->add("\xAB" x 64);
    my $digest1 = $ctx1->hexdigest;

    # Now recreate using context from midpoint
    my $ctx2 = Digest::MD5->new;
    if (defined $buf1) {
        $ctx2->context($b1, $s1, $buf1);
    } else {
        $ctx2->context($b1, $s1);
    }
    $ctx2->add("\xAB" x 64);
    my $digest2 = $ctx2->hexdigest;

    is($digest1, $digest2,
       'digest matches when state is saved/restored across 4 GiB boundary');
}
