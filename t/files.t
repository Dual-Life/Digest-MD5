use strict;
use warnings;
use Test::More;
use Digest::MD5 qw(md5 md5_hex md5_base64);

# Algorithm correctness is validated by t/md5-aaa.t (256 known vectors).
# This test verifies all interfaces produce consistent results on real files.

if (!(-f "README") && -f "../README") {
    chdir("..") or die "Can't chdir: $!";
}

my @files = qw(README MD5.xs rfc1321.txt);
if ($ENV{PERL_CORE}) {
    @files = grep { $_ ne 'rfc1321.txt' && $_ ne 'README' } @files;
}
@files = grep { -f $_ } @files;

if (!@files) {
    plan skip_all => 'No test files found';
}

my $B64 = eval { require MIME::Base64; 1 };

plan tests => scalar(@files) * ($B64 ? 11 : 8);

for my $file (@files) {
    my $data = do {
        open(my $fh, '<', $file) or die "Can't open $file: $!";
        binmode($fh);
        local $/;
        <$fh>;
    };

    my $bin = md5($data);
    my $hex = md5_hex($data);

    is($hex, unpack("H*", $bin), "$file: md5_hex matches md5");

    if ($B64) {
        my $expected = MIME::Base64::encode($bin, "");
        $expected =~ s/=+$//;
        is(md5_base64($data), $expected, "$file: md5_base64 matches md5");
    }

    is(Digest::MD5->new->add($data)->digest, $bin,
       "$file: OO add->digest");
    is(Digest::MD5->new->add($data)->hexdigest, $hex,
       "$file: OO add->hexdigest");
    if ($B64) {
        is(Digest::MD5->new->add($data)->b64digest, md5_base64($data),
           "$file: OO add->b64digest");
    }

    my @chars = split //, $data;
    is(md5(@chars), $bin, "$file: md5 with char list");
    is(Digest::MD5->new->add(@chars)->digest, $bin,
       "$file: OO add(chars)->digest");

    my $ctx = Digest::MD5->new;
    $ctx->add($_) for @chars;
    is($ctx->digest, $bin, "$file: OO add loop");

    {
        open(my $fh, '<', $file) or die "Can't open $file: $!";
        binmode($fh);
        is(Digest::MD5->new->addfile($fh)->digest, $bin,
           "$file: addfile->digest");
    }
    {
        open(my $fh, '<', $file) or die "Can't open $file: $!";
        binmode($fh);
        is(Digest::MD5->new->addfile($fh)->hexdigest, $hex,
           "$file: addfile->hexdigest");
    }
    if ($B64) {
        open(my $fh, '<', $file) or die "Can't open $file: $!";
        binmode($fh);
        is(Digest::MD5->new->addfile($fh)->b64digest, md5_base64($data),
           "$file: addfile->b64digest");
    }
}
