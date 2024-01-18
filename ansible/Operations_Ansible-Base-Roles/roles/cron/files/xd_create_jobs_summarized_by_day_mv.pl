#!/usr/bin/env perl
use strict;
use DBI;

my($DSN) = 'dbname=teragrid;host=tgcdb.xsede.org';
my($login, $passwd) = qw(xdcdb_cron **REMOVED**);

my($dbh) = DBI->connect("dbi:Pg:$DSN", $login, $passwd, {RaiseError=>1});

$dbh->do("set client_min_messages to ERROR");
$dbh->do("select acct.create_jobs_summarized_by_day_mv()");

$dbh->disconnect;
