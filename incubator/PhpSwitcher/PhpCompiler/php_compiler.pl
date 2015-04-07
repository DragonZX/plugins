#!/usr/bin/perl
# i-MSCP PhpSwitcher plugin
# Copyright (C) 2014-2015 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

use strict;
use warnings;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use lib '/var/www/imscp/engine/PerlLib';
use File::Basename;
use File::Spec;
use iMSCP::Bootstrapper;
use iMSCP::Debug;
use iMSCP::File;
use iMSCP::Dir;
use iMSCP::Execute;
use iMSCP::Getopt;
use iMSCP::Service;
use version;

umask 022;

$ENV{'LANG'} = 'C.UTF-8';

# Quilt common configuration
$ENV{'QUILT_PUSH_ARGS'} = '--color=never';
$ENV{'QUILT_DIFF_ARGS'} = '--no-timestamps --no-index -p ab --color=never';
$ENV{'QUILT_REFRESH_ARGS'} = '--no-timestamps --no-index -p ab';
$ENV{'QUILT_DIFF_OPTS'} = '-p';

# Setup log file
newDebug('phpswitcher-php-compiler.log');

# Bootstrap i-MSCP backend
iMSCP::Bootstrapper->getInstance()->boot(
    { 'mode' => 'backend', 'nolock' => 'yes', 'nokeys' => 'yes', 'nodatabase' => 'yes', 'config_readonly' => 'yes' }
);

# Compiler maintenance directory
my $MAINT_DIR = $main::imscpConfig{'PLUGINS_DIR'} . '/PhpSwitcher/PhpCompiler/phpswitcher';

# Common build dependencies
# Build dependencies were pulled from many Debian control files.
# Note: Packages are installed only if available.
my @BUILD_DEPS = (
    'autoconf',
    'automake',
    'automake1.11',
#    'apache2-dev',         No needed because we do not want build any Apache SAPI
#    'apache2-prefork-dev'  No needed because we do not want build any Apache SAPI
    'bison',
    'chrpath',
#    'debhelper',
#    'dh-apache2',          # No needed because we do not build a Debian package
#    'dh-systemd',          # No needed because we do not build a Debian package
#    'dpkg-dev',            # No needed because this is a dependency of the build-essential package
    'firebird-dev',
    'firebird2.1-dev',
    'firebird2.5-dev',
    'flex',
    'freetds-dev',
#    'hardening-wrapper',   # No needed because we use dpkg-buildflags
    'language-pack-de',
    'libapparmor-dev',
#    'libapr1-dev',         # No needed because we do not want build apache SAPI
    'libbz2-dev',
    'libc-client-dev',
    'libc-client2007e-dev',
    'libcurl-dev',
    'libcurl4-openssl-dev',
    'libdb-dev',
    'libedit-dev',
    'libenchant-dev',
#    'libevent-dev',        # No needed because we do not compile PHP-FPM
    'libexpat1-dev',
    'libfreetype6-dev',
    'libgcrypt11-dev',
#    'libgd-dev',           # No needed because we use the bundled version
#    'libgd2-dev',          # No needed because we use the bundled version
    'libgd2-xpm-dev',
    'libglib2.0-dev',
    'libgmp3-dev',
    'libicu-dev',
    'libjpeg-dev',
#    'libjpeg62-dev',       # We do not want this ( conflict with libgd2-xpm-dev )
    'libkrb5-dev',
    'libldap2-dev',
#    'libmagic-dev',        # No needed because we use the bundled version
    'libmcrypt-dev',
    'libmhash-dev',
#    'libmysqlclient-dev',   # Moved to conditional build dependencies
#    'libmysqlclient15-dev', # Moved to conditional build dependencies
    'libonig-dev',
    'libpam0g-dev',
    'libpcre3-dev',
    'libpng-dev',
    'libpng12-dev',
    'libpq-dev',
    'libpspell-dev',
    'libqdbm-dev',
    'librecode-dev',
    'libsasl2-dev',
    'libsnmp-dev',
    'libsqlite3-dev',
    'libssl-dev',
#    'libsystemd-daemon-dev',  # No needed because we do not build for php5-fpm
    'libtidy-dev',
    'libtool',
    'libvpx-dev',
    'libwrap0-dev',
    'libxml2-dev',
    'libxmltok1-dev',
    'libxslt1-dev',
    'locales-all',
#    'mysql-server',            # Moved to conditional build dependencies
#    'netbase',                 # Not needed because we do not run any test
#    'netcat-traditional',      # Not needed?
    'quilt',
    're2c',
    'systemtap-sdt-dev',
#    'tzdata',                  # Disabled because we are using bundled timezone database
    'unixodbc-dev',
#    'virtual-mysql-server',    # Moved to conditional build dependencies
    'zlib1g-dev',

    # Out of control files
    'build-essential',
    'shtool',                   # Needed because we copy files instead of create symlink to them as it is done by Debian
    'wget'
);

# Conditional MySQL build dependencies
# Only needed for PHP5.2 since for newest versions, we are using MySQL native driver ( mysqlnd )
my %CONDITIONAL_BUILD_DEPS = (
    'mysql' => ['libmysqlclient-dev', 'libmysqlclient15-dev'],
    'mariadb' => ['libmariadb-client-lgpl-dev', 'libmariadb-client-lgpl-dev-compat'],
    'percona' => [] # todo
);

# Map short PHP versions to last known PHP versions
my %SHORT_TO_LONG_VERSION = (
#    '5.2' => '5.2.17',
#    '5.3' => '5.3.29',
#    '5.4' => '5.4.39',
#    '5.5' => '5.5.23',
    '5.6' => '5.6.7'
);

# URL patterns for PHP archives
my @URL_PATTERNS = (
    'http://de1.php.net/distributions/php-%s.tar.gz',
    'http://de2.php.net/distributions/php-%s.tar.gz',
    'http://uk1.php.net/distributions/php-%s.tar.gz',
    'http://uk3.php.net/distributions/php-%s.tar.gz',
    'http://us1.php.net/distributions/php-%s.tar.gz',
    'http://us2.php.net/distributions/php-%s.tar.gz',
    'http://us3.php.net/distributions/php-%s.tar.gz',
    'http://php.net/distributions/php-%s.tar.gz'
);

# Map long PHP versions to upstream version URLs
my %LONG_VERSION_TO_URL = ();

# Default values for non-boolean command line options
my $BUILD_DIR = '/usr/local/src/phpswitcher';
my $INSTALL_DIR = '/opt/phpswitcher';
my $PARALLEL_JOBS = 4;

# Parse command line options
iMSCP::Getopt->parseNoDefault(sprintf("\nUsage: perl %s [OPTION...] PHP_VERSION...", basename($0)) . qq {

PHP Compiler

This script allows to download, configure, compile and install one or many PHP versions on Debian/Ubuntu distributions in one step. Work is made by applying a set of patches which were pulled from the php5 Debian source package, and by using a dedicated Makefile file which defines specific targets for each PHP version.

PHP VERSIONS:
 Supported PHP versions are: } . ( join ', ', map { 'php' . $_ } keys %SHORT_TO_LONG_VERSION ) . qq {

 You can either specify one or many PHP versions or 'all' for all versions.

OPTIONS:
 -b,    --builddir      Build directory ( /usr/local/src/phpswitcher ).
 -i,    --installdir    Base installation directory ( /opt/phpswitcher ).
 -d,    --download-only Download only.
 -f,    --force-last    Force use of the last available PHP versions.
 -p,    --parallel-jobs Number of parallel jobs for make ( default: 4 ).
 -v,    --verbose       Enable verbose mode.},
 'builddir|b=s' => sub { setOptions(@_); },
 'installdir|i=s' => sub { setOptions(@_); },
 'download-only|d' => \ my $DOWNLOAD_ONLY,
 'force-last|f' => \ my $FORCE_LAST,
 'parallel-jobs|p=i' => sub { setOptions(@_); },
 'verbose|v' => sub { setVerbose(@_); }
);

my @sVersions = ();

eval {
    if(grep { lc $_ eq 'all' } @ARGV) {
        @sVersions = keys %SHORT_TO_LONG_VERSION;
    } else {
        for my $sVersion(@ARGV) {
            $sVersion = lc $sVersion;

            if($sVersion =~ /^php(5\.[2-6])$/ && exists $SHORT_TO_LONG_VERSION{$1}) {
                push @sVersions, $1;
            } else {
                die(sprintf("Invalid PHP version parameter: %s\n", $sVersion));
            }
       }
    }

    @sVersions = sort @sVersions;
};

if($@ || !@sVersions) {
    print STDERR "\n$@\n" if $@;
    iMSCP::Getopt->showUsage();
}

installBuildDep() unless $DOWNLOAD_ONLY;

for my $sVersion(@sVersions) {
    print output(sprintf('Processing PHP %s version', $sVersion), 'info');

    next unless (my $lVersion = getLongVersion($sVersion));

    downloadSource($sVersion, $lVersion);

    unless($DOWNLOAD_ONLY) {
        my $srcDir = File::Spec->join($BUILD_DIR, "php-$lVersion");
        chdir $srcDir or fatal(sprintf('Unable to change dir to %s', $srcDir));
        undef $srcDir;

        applyPatches($sVersion, $lVersion);
        install($sVersion, $lVersion);

        print output(sprintf('PHP %s has been successfully installed', $lVersion), 'ok');
    }
}

my $srvMngr = iMSCP::Service->getInstance();
exit $srvMngr->reload('apache2') unless $DOWNLOAD_ONLY || ! $srvMngr->isRunning('apache2');

sub setOptions
{
    my ($option, $value) = @_;

    if($option eq 'builddir') {
        print output(sprintf('Build directory set to %s', $value), 'info');
        $BUILD_DIR = $value;
    } elsif($option eq 'installdir') {
        if(-d $value) {
            print output(sprintf('Base installation directory set to %s', $value), 'info');
            $INSTALL_DIR = $value;
        } else {
            die("Directory speficied by the --installdir option must exists.\n");
        }
    } elsif($option eq 'parallel-jobs') {
        $PARALLEL_JOBS = $value;
    }
}

sub installBuildDep
{
    print output(sprintf('Installing build dependencies...'), 'info');

    # Filter packages which are not available since the build dependencies list is a mix of packages
    # that were pulled from different Debian/Ubuntu php5 package control files
    my ($stdout, $stderr);
    (execute("apt-cache --generate pkgnames", \$stdout, \$stderr) < 2) or fatal(sprintf(
        'An error occurred while installing build dependencies: Unable to filter list of packages to install: %s',
        $stderr
    ));
    @BUILD_DEPS = sort grep { $_ ~~ @BUILD_DEPS } split /\n/, $stdout;

    # Install packages
    (execute("apt-get -y --no-install-recommends install @BUILD_DEPS", undef, \$stderr) == 0) or fatal(sprintf(
        "An error occurred while installing build dependencies: %s", $stderr
    ));

    # Fix: "can not be used when making a shared object; recompile with –fPIC ... libc-client.a..." compile time error
    # Be sure that we do not have any /usr/lib/x86_64-linux-gnu/libc-client.a symlink to /usr/lib/libc-client.a since
    # this is not supported when using the --with--pic option
    unlink '/usr/lib/x86_64-linux-gnu/libc-client.a' if -s '/usr/lib/x86_64-linux-gnu/libc-client.a';

    print output(sprintf('Build dependencies were successfully installed'), 'ok');
}

sub getLongVersion
{
    my $sVersion = shift;
    my $lVersion = $SHORT_TO_LONG_VERSION{$sVersion};
    my $versionIsAlive = (version->parse($sVersion) > version->parse('5.3'));
    my ($tiny) = $lVersion =~ /(\d+)$/;

    if($FORCE_LAST) {
        print output(sprintf('Scanning PHP site for last PHP %s.x version...', $sVersion), 'info');
    } else {
        print output(sprintf('Scanning PHP site for PHP %s version...', $lVersion), 'info');
    }

    my $foundUrl;
    my $ret = 0;

    # At first, we scan the museum. This covers the versions which are end of life and the versions which were moved
    # since the last release of this script.
    do {
        my $url = sprintf('http://museum.php.net/php5/php-%s.tar.gz', "$sVersion.$tiny");
        my ($stdout, $stderr);
        $ret = execute("wget --spider $url", \$stdout, \$stderr);
        debug($stdout) if $stdout;
        debug($stderr) if $stderr;
        unless($ret) {
            $foundUrl = $url;
            $tiny++;
        }
    } while($ret == 0 && $versionIsAlive && $FORCE_LAST);

    # We scan PHP mirrors if needed
    if($versionIsAlive && $FORCE_LAST || !$foundUrl) {
        for my $urlPattern(@URL_PATTERNS) {
            do {
                my $url = sprintf($urlPattern, "$sVersion.$tiny");
                my ($stdout, $stderr);
                $ret = execute("wget --spider $url", \$stdout, \$stderr);
                debug($stdout) if $stdout;
                debug($stderr) if $stderr;
                unless($ret) {
                    $foundUrl = $url;
                    $tiny++;
                }
            } while($ret == 0 && $FORCE_LAST);

            next if $ret != 0 && $ret != 8;
            last if defined $foundUrl || $ret == 8;
        }
    }

    if($foundUrl) {
        $tiny--;
        $lVersion = "$sVersion.$tiny";
        $LONG_VERSION_TO_URL{$lVersion} = $foundUrl;
        print output(sprintf('Found php-%s archive at %s', $lVersion, $LONG_VERSION_TO_URL{$lVersion}), 'info');
    } else {
        print output(sprintf('Could not find any valid URL for PHP %s - Skipping', $sVersion), 'error');
        $lVersion = '';
    }

    $lVersion;
}

sub downloadSource
{
    my ($sVersion, $lVersion) = @_;
    my $archPath = File::Spec->join($BUILD_DIR, "php-$lVersion.tar.gz");
    my $srcPath = File::Spec->join($BUILD_DIR, "php-$lVersion");

    unless(-f $archPath) {
        print output(sprintf('Donwloading php-%s source archive into %s...', $lVersion, $BUILD_DIR), 'info');

        if(iMSCP::Dir->new( dirname => $BUILD_DIR  )->make( { mode => 0755 } )) {
            fatal(sprintf('Unable to create the %s build directory', $BUILD_DIR));
        }

        my ($stdout, $stderr);
        (
            execute("wget -t 1 -O $archPath $LONG_VERSION_TO_URL{$lVersion}", \$stdout, \$stderr) == 0
        ) or fatal(sprintf(
            "An error occurred while downloading the php-%s source archive: %s", $lVersion, $stderr
        ));
        debug($stdout) if $stdout;

        print output(sprintf('php-%s source archive successfully downloaded', $lVersion), 'ok');
    } else {
        print output(sprintf('php-%s source archive already present - skipping download', $lVersion), 'ok');
    }

    unless($DOWNLOAD_ONLY) {
        print output(sprintf('Extracting php-%s source archive into %s ...', $lVersion, $srcPath), 'info');

        # Remove previous directory if any
        iMSCP::Dir->new( dirname =>  $srcPath )->remove();

        my ($stdout, $stderr);
        (execute("tar -xzf $archPath -C $BUILD_DIR/", \$stdout, \$stderr) == 0) or fatal(sprintf(
            "An error occurred while extracting the php-%s source archive: %s", $lVersion, $stderr
        ));
        debug($stdout) if $stdout;

        print output(sprintf('php-%s source archive successfully extracted into %s', $lVersion, $BUILD_DIR), 'ok');
    }
}

sub applyPatches
{
    my ($sVersion, $lVersion) = @_;

    print output(sprintf('Applying Debian patches on php-%s source...', $lVersion), 'info');

    # Make quilt aware of patches location
    $ENV{'QUILT_PATCHES'} = "$MAINT_DIR/php$sVersion";

    my ($stdout, $stderr);
    (execute("quilt push -a", \$stdout, \$stderr) == 0) or fatal(sprintf(
        'An error occurred while applying Debian patches on php-%s source: %s', $lVersion, $stderr
    ));
    debug($stdout) if $stdout;
    error($stderr) if $stderr;

    print output(sprintf('Debian patches successfully applied on php-%s source', $lVersion), 'ok');
}

sub install
{
    my ($sVersion, $lVersion) = @_;
    my $target = 'install-php' . $sVersion;
    my $installDir = File::Spec->join($INSTALL_DIR, "php$sVersion");

    print output(sprintf('Executing the %s make target for php-%s...', $target, $lVersion), 'info');

    $ENV{'PHPSWITCHER_BUILD_OPTIONS'} = "parallel=$PARALLEL_JOBS";

    my $stderr;
    (execute("make -f $MAINT_DIR/Makefile PREFIX=$installDir $target", undef, \$stderr) == 0) or fatal(sprintf(
        'An error occurred during php-%s compilation process: %s', $lVersion, $stderr
    ));

    # Copy modules.ini file
    (
        iMSCP::File->new( filename => "$MAINT_DIR/php$sVersion/modules.ini" )->copyFile(
            "$installDir/etc/php/conf.d", { preserve => 'no' }
        ) == 0
    ) or fatal(sprintf(
        'An error occurred during php-%s installation process: Unable to copy the PHP modules.ini file', $lVersion
    ));

    print output(sprintf('%s make target successfully executed for php-%s', $target, $lVersion), 'ok');
}