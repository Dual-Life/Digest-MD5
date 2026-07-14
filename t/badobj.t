use strict;
use warnings;
use Test::More tests => 4;
use Digest::MD5;

# Issue #25: calling OO methods with a bareword class name instead of
# a blessed reference caused a segfault in get_md5_ctx().

eval { Digest::MD5->add("") };
like($@, qr/Not a reference/, "add() on bareword class croaks, not segfault");

eval { Digest::MD5::add("Digest::MD5") };
like($@, qr/Not a reference/, "add() with class string croaks, not segfault");

eval { Digest::MD5->clone };
like($@, qr/Not a reference/, "clone() on bareword class croaks, not segfault");

eval { Digest::MD5->hexdigest };
like($@, qr/Not a reference/, "hexdigest() on bareword class croaks, not segfault");
