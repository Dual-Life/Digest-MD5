use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir tempfile);
use File::Spec;
use Config;

plan tests => 4;

my $perl = $Config{perlpath};
my $lib  = File::Spec->rel2abs("blib/lib");
my $arch = File::Spec->rel2abs("blib/arch");

# Helper: write a perl script to a temp file and run it
sub run_perl_script {
    my ($code) = @_;
    my ($fh, $script) = tempfile(SUFFIX => '.pl', UNLINK => 1);
    print $fh $code;
    close $fh;
    my $out = `$perl -I$lib -I$arch $script 2>&1`;
    return ($?, $out);
}

# Escape backslashes for safe interpolation into double-quoted strings
# (Windows paths like C:\Users\... would otherwise be mangled by \U, \f, etc.)
sub escape_path {
    my ($path) = @_;
    $path =~ s/\\/\\\\/g;
    return $path;
}

# Test 1: When FIPS file contains "1", loading Digest::MD5 should croak
{
    my $dir = tempdir(CLEANUP => 1);
    my $fips_file = File::Spec->catfile($dir, "fips_enabled");
    open my $fh, '>', $fips_file or die "Cannot write $fips_file: $!";
    print $fh "1\n";
    close $fh;

    my $safe_path = escape_path($fips_file);
    my ($status, $out) = run_perl_script(<<"EOT");
\$ENV{DIGEST_MD5_FIPS_FILE} = "$safe_path";
eval { require Digest::MD5 };
if (\$\@ =~ /FIPS/) { print "FIPS_CROAK\\n"; exit 0 }
else { print "NO_CROAK: \$\@\\n"; exit 1 }
EOT

    like($out, qr/FIPS_CROAK/, "Digest::MD5 croaks when FIPS mode is enabled");
}

# Test 2: When FIPS file contains "0", loading should succeed
{
    my $dir = tempdir(CLEANUP => 1);
    my $fips_file = File::Spec->catfile($dir, "fips_enabled");
    open my $fh, '>', $fips_file or die "Cannot write $fips_file: $!";
    print $fh "0\n";
    close $fh;

    my $safe_path = escape_path($fips_file);
    my ($status, $out) = run_perl_script(<<"EOT");
\$ENV{DIGEST_MD5_FIPS_FILE} = "$safe_path";
eval { require Digest::MD5 };
if (\$\@) { print "CROAK: \$\@\\n"; exit 1 }
else { print "OK\\n"; exit 0 }
EOT

    like($out, qr/^OK/, "Digest::MD5 loads normally when FIPS is not enabled");
}

# Test 3: When FIPS file does not exist, loading should succeed
{
    my $dir = tempdir(CLEANUP => 1);
    my $fips_file = File::Spec->catfile($dir, "no_such_file");

    my $safe_path = escape_path($fips_file);
    my ($status, $out) = run_perl_script(<<"EOT");
\$ENV{DIGEST_MD5_FIPS_FILE} = "$safe_path";
eval { require Digest::MD5 };
if (\$\@) { print "CROAK: \$\@\\n"; exit 1 }
else { print "OK\\n"; exit 0 }
EOT

    like($out, qr/^OK/, "Digest::MD5 loads normally when FIPS file is absent");
}

# Test 4: Verify the croak message is informative
{
    my $dir = tempdir(CLEANUP => 1);
    my $fips_file = File::Spec->catfile($dir, "fips_enabled");
    open my $fh, '>', $fips_file or die "Cannot write $fips_file: $!";
    print $fh "1\n";
    close $fh;

    my $safe_path = escape_path($fips_file);
    my ($status, $out) = run_perl_script(<<"EOT");
\$ENV{DIGEST_MD5_FIPS_FILE} = "$safe_path";
eval { require Digest::MD5 };
print \$\@;
EOT

    like($out, qr/MD5.*FIPS/i,
         "Croak message mentions MD5 and FIPS");
}
