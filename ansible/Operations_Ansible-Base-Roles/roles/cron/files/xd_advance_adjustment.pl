#!/usr/bin/env perl
use strict;
use DBI;
use Mail::Send;
use Getopt::Long;


my(%options) = ();
GetOptions (\%options,
            "mode=s",
            );

my($mode) = $options{mode};
usage() unless (defined $mode);

my($DSN, $passwd, $login, $dbh);
if ($mode eq 'testing')
{
    $DSN = 'dbname=xras_test_xdcdb;host=xdcdb-test.xsede.org';
    $login = 'tgam';
    $passwd = '';   # set this (or put it in ~/.pgpass)
}
elsif ($mode eq 'production')
{
    $DSN = 'dbname=teragrid;host=tgcdb.xsede.org';
    $login = 'tgam';
    $passwd = '';   # set this (or put it in ~/.pgpass)
}
else
{
    usage();
}

$dbh = DBI->connect("dbi:Pg:$DSN", $login, $passwd, {PrintError=>1, RaiseError=>1});
$dbh->do("select xras_acct.advance_adjustment()");
$dbh->disconnect;


sub usage
{
    die "Usage: $0 -mode <testing|production>\n";
}
