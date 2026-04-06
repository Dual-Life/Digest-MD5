#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 39;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $empty_hex = 'd41d8cd98f00b204e9800998ecf8427e';
my $abc_hex   = '900150983cd24fb0d6963f7d28e17f72';

# --- reset() is an alias for new() ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add("abc");
    $ctx->reset;
    is($ctx->hexdigest, $empty_hex, 'reset() clears state');
}

{
    my $ctx = Digest::MD5->new;
    $ctx->add("abc");
    my $ret = $ctx->reset;
    isa_ok($ret, 'Digest::MD5', 'reset() returns object');
    is($ret->hexdigest, $empty_hex, 'returned object is reset');
}

# --- digest() auto-resets state ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add("abc");
    my $first = $ctx->hexdigest;
    is($first, $abc_hex, 'first hexdigest correct');
    my $second = $ctx->hexdigest;
    is($second, $empty_hex, 'hexdigest auto-resets for second call');
}

{
    my $ctx = Digest::MD5->new;
    $ctx->add("abc");
    $ctx->digest;  # consume
    $ctx->add("abc");
    is($ctx->hexdigest, $abc_hex, 'can reuse context after digest()');
}

# --- add() with zero arguments ---
{
    my $ctx = Digest::MD5->new;
    my $ret = $ctx->add();
    isa_ok($ret, 'Digest::MD5', 'add() with no args returns self');
    is($ctx->hexdigest, $empty_hex, 'add() with no args is a no-op');
}

# --- add() with many arguments ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add('a', 'b', 'c');
    is($ctx->hexdigest, $abc_hex, 'add() with 3 args');
}

{
    my $ctx = Digest::MD5->new;
    $ctx->add(split //, 'abcdefghij');
    my $expect = md5_hex('abcdefghij');
    is($ctx->hexdigest, $expect, 'add() with 10 single-char args');
}

# --- add() method chaining ---
{
    my $ctx = Digest::MD5->new;
    my $digest = $ctx->add('a')->add('b')->add('c')->hexdigest;
    is($digest, $abc_hex, 'add() method chaining works');
}

# --- new() on instance resets in place ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add("abc");
    my $ret = $ctx->new;
    is($ctx->hexdigest, $empty_hex, 'new() on instance resets state');
}

# --- functional interface: single and multi-arg ---
{
    is(md5_hex('abc'), $abc_hex, 'md5_hex single arg');
    is(md5_hex('a', 'b', 'c'), $abc_hex, 'md5_hex multi arg');
    is(md5_hex(''), $empty_hex, 'md5_hex empty string');
}

{
    is(length(md5('abc')), 16, 'md5() returns 16 bytes');
    is(length(md5_base64('abc')), 22, 'md5_base64() returns 22 chars');
}

# --- md5_base64 format ---
{
    my $b64 = md5_base64('abc');
    like($b64, qr/^[A-Za-z0-9+\/]+$/, 'md5_base64 uses valid base64 chars');
}

# --- context() save and restore: initial state ---
{
    my $ctx = Digest::MD5->new;
    my @state = $ctx->context;
    is(scalar @state, 2, 'initial context returns 2 elements (blocks + state)');
    is($state[0], 0, 'initial block count is 0');
    is(length($state[1]), 16, 'state buffer is 16 bytes');
}

# --- context() save and restore: with partial buffer ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add('hello');  # 5 bytes, less than 64 block
    my @state = $ctx->context;
    is(scalar @state, 3, 'context with partial buffer returns 3 elements');
    is($state[0], 0, 'block count 0 with < 64 bytes');
    is(length($state[1]), 16, 'state buffer is 16 bytes');
    is(length($state[2]), 5, 'partial buffer is 5 bytes');
}

# --- context() save and restore: after full block ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add('a' x 64);  # exactly one block
    my @state = $ctx->context;
    is(scalar @state, 2, 'exact block boundary: 2 elements');
    is($state[0], 1, 'block count is 1 after 64 bytes');
}

# --- context() restore with 4th argument (partial buffer) ---
{
    my $ctx1 = Digest::MD5->new;
    $ctx1->add('hello world');
    my @saved = $ctx1->context;

    # Restore using the 4-arg form: blocks, state, partial
    my $ctx2 = Digest::MD5->new;
    $ctx2->context(@saved);

    # Both should produce same digest after adding more data
    $ctx1->add(' test');
    $ctx2->add(' test');
    is($ctx1->hexdigest, $ctx2->hexdigest, 'context restore with partial buffer');
}

# --- context() restore preserves mid-block state ---
{
    my $data = 'a' x 100;  # 1 block + 36 bytes
    my $ctx1 = Digest::MD5->new;
    $ctx1->add($data);
    my @state = $ctx1->context;

    my $ctx2 = Digest::MD5->new;
    $ctx2->context(@state);
    $ctx2->add('more');

    my $ctx3 = Digest::MD5->new;
    $ctx3->add($data . 'more');

    is($ctx2->hexdigest, $ctx3->hexdigest, 'context restore mid-block matches direct computation');
}

# --- addfile() method chaining ---
{
    use File::Temp;
    my $tmp = File::Temp->new;
    print $tmp "abc";
    close $tmp;

    open my $fh, '<', $tmp->filename or die $!;
    binmode $fh;
    my $ctx = Digest::MD5->new;
    my $ret = $ctx->addfile($fh);
    close $fh;

    isa_ok($ret, 'Digest::MD5', 'addfile() returns self');
    is($ret->hexdigest, $abc_hex, 'addfile() computed correct digest');
}

# --- addfile() with empty file ---
{
    use File::Temp;
    my $tmp = File::Temp->new;
    close $tmp;

    open my $fh, '<', $tmp->filename or die $!;
    binmode $fh;
    my $ctx = Digest::MD5->new;
    $ctx->addfile($fh);
    close $fh;
    is($ctx->hexdigest, $empty_hex, 'addfile() with empty file');
}

# --- digest formats are consistent ---
{
    my $data = 'The quick brown fox jumps over the lazy dog';
    my $bin = md5($data);
    my $hex = md5_hex($data);
    my $b64 = md5_base64($data);

    is(unpack('H*', $bin), $hex, 'md5() and md5_hex() are consistent');

    # Verify the hex is correct (known value)
    is($hex, '9e107d9d372bb6826bd81d3542a419d6', 'known test vector');
}

# --- DESTROY doesn't crash on normal use ---
{
    for (1..100) {
        my $ctx = Digest::MD5->new;
        $ctx->add("test");
    }
    pass('rapid create/destroy cycle does not crash');
}

# --- add() with empty string ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add('');
    is($ctx->hexdigest, $empty_hex, 'add("") same as no add');
}

# --- multiple empty adds don't change state ---
{
    my $ctx = Digest::MD5->new;
    $ctx->add('') for 1..100;
    is($ctx->hexdigest, $empty_hex, '100 empty adds same as none');
}

# --- subclass works ---
{
    package My::MD5;
    our @ISA = ('Digest::MD5');

    package main;
    my $ctx = My::MD5->new;
    $ctx->add('abc');
    is($ctx->hexdigest, $abc_hex, 'subclass produces correct digest');
    isa_ok($ctx, 'My::MD5', 'subclass maintains type');
}
