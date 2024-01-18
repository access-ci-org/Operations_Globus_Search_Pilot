#!/usr/bin/env perl
use strict;
use DBI;
use Mail::Send;
use Getopt::Long;


my($TEST) = 0;
my($xras, $xdcdb, $sth, $sql);
my($data, $edate);
my(%options) = ();
my($DSN, $passwd, $login);
my($to, $cc, $subject, $body);

GetOptions (\%options,
            "mode=s",
            );

my($mode) = $options{mode};
usage() unless (defined $mode);

if ($mode eq 'testing')
{
    $TEST = 1;
}
elsif ($mode eq 'production')
{
    $TEST = 0;
}
else
{
    usage();
}

if ($TEST)
{
    $DSN = 'dbname=xras_test_xdcdb;host=xdcdb-test.xsede.org';
    $login = 'xras';
    $passwd = '';   # (put xras passwd in in ~/.pgpass)
}
else
{
    $DSN = 'dbname=teragrid;host=tgcdb.xsede.org';
    $login = 'xras';
    $passwd = '';   # (put xras passwd in in ~/.pgpass)
}

$xras = DBI->connect("dbi:Pg:$DSN", $login, $passwd, {PrintError=>1, RaiseError=>1});

if ($TEST)
{
    $DSN = 'dbname=xras_test_xdcdb;host=xdcdb-test.xsede.org';
    $login = 'tgam';
    $passwd = '';   # (put tgam passwd in in ~/.pgpass)
}
else
{
    $DSN = 'dbname=teragrid;host=tgcdb.xsede.org';
    $login = 'tgam';
    $passwd = '';   # (put tgam passwd in in ~/.pgpass)
}

$xdcdb = DBI->connect("dbi:Pg:$DSN", $login, $passwd, {PrintError=>1, RaiseError=>1});

# delete XSEDE deleted final report actions from XRAS xras_acct.final_report_actions table

$sql = "
  select distinct action_id
    from xras.action_v
   where allocations_process = 'XSEDE'
     and action_type = 'Final Report'
     and action_is_deleted
     ";

$sth = $xras->prepare ($sql);
$sth->execute;

while ($data = $sth->fetchrow_hashref)
{
    $sql = sprintf ('delete from xras_acct.final_report_actions where action_id = %d', $data->{action_id});
    $xdcdb->do($sql);
}

# load all the XSEDE final report actions from XRAS into xras_acct.final_report_actions table
# to avoid reloading the final actions that have already been loaded, only select those with entry_dates that have not yet been loaded

($edate) = $xdcdb->selectrow_array('select max(entry_date) from xras_acct.final_report_actions');

$sql = "
  select distinct action_id, request_number, action_entry_date as entry_date
    from xras.action_v
   where allocations_process = 'XSEDE'
     and action_type = 'Final Report'
     and action_entry_date is not null
     and not action_is_deleted
     ";

$sql .= sprintf(' and action_entry_date >= %s', $xras->quote($edate)) if (defined $edate);
$sth = $xras->prepare ($sql);
$sth->execute;

while ($data = $sth->fetchrow_hashref)
{
    $sql = sprintf ('select xras_acct.set_final_report_action(%d,%s,%s)', 
              $data->{action_id},
              $xdcdb->quote($data->{request_number}),
              $xdcdb->quote($data->{entry_date})
              );
    $xdcdb->do($sql);
}

$sth->finish;
$xras->disconnect;

# now process the notifications
# the final_report_v finds the project that are expired
# it uses the final_report_actions table to suppress projects that have submitted a final report
# it also uses the final_report_notifications table to suppress projects that have already been notified

$sql = 'select * from xras_acct.final_report_v order by end_date desc';
if ($TEST)
{
    $sql .= ' limit 1';
}
else
{
    $sql .= ' limit 100';
}
$sth = $xdcdb->prepare ($sql);
$sth->execute;

while ($data = $sth->fetchrow_hashref)
{
    compose();

    $to = $data->{pi_email};
    $cc = $data->{email_cc};
    $sql = sprintf ('select xras_acct.add_final_report_notification(%s,%s,%s,%s,%s,%s)',
              $xdcdb->quote($data->{request_number}),
              $xdcdb->quote($data->{end_date}),
              $xdcdb->quote($to),
              $xdcdb->quote($cc),
              $xdcdb->quote($subject),
              $xdcdb->quote($body)
              );

    mail($to,$cc,$subject,$body);
    $xdcdb->do($sql);
}

$sth->finish;
$xdcdb->disconnect;

sub compose
{
    my $template = << 'EOF';
Dr. :PILASTNAME:,

Your :ALLOCATIONTYPE: award with grant number :REQUESTNUMBER: has expired, we ask that if you are not planning on extending or renewing this award, that you take a moment and submit a Final Report for this award.

You can submit a Final Report by going to the XSEDE Allocation site: https://portal.xsede.org/group/xup/submit-request#/ , select your award :REQUESTNUMBER: and then select the blue Actions button. There you will see the option to submit a Final Report. Please include in this document a description of the research activities and results. If publications resulted from these research activities we ask that you include these publications on your XSEDE Portal Profile(https://portal.xsede.org/group/xup/profile#/).

We hope your experience was positive and you were able to achieve meaningful results. If you have any questions or concerns, please contact XSEDE HelpDesk at help@xsede.org.

Regards,

XSEDE Allocations
EOF

    my($name) = $data->{pi_last_name};
    my($type) = $data->{allocation_type};
    my($request) = $data->{request_number};
    $subject = "Final Report submission available for $type $request/$name";

    $body    = $template;

    $body =~ s/:PILASTNAME:/$name/g;
    $body =~ s/:REQUESTNUMBER:/$request/g;
    $body =~ s/:ALLOCATIONTYPE:/$type/g;

    1;
}

sub mail
{
    my($to, $cc, $subject, $body) = @_;
    my($fh, $msg);

    if ($TEST)
    {
        print "To: $to\ncc: $cc\nSubject: $subject\n$body\n";
        my($prefix) = "Testing\n";
        $prefix .= "========================================\n";
        $prefix .= "To: $to\n";
        $prefix .= "Cc: $cc\n" if (defined $cc);
        $prefix .= "========================================\n";
        $to = 'shapiro2@illinois.edu';
        undef $cc;
        $body = "$prefix$body";
    }

    $msg = new Mail::Send;
    $msg->to($to);
    $msg->cc($cc) unless $cc =~ /^\s*$/;
    $msg->subject($subject);
    $msg->set('From', 'XSEDE allocations <help@xsede.org>');
    $msg->set('Reply-To', 'help@xsede.org');

    $fh = $msg->open('sendmail');
    print $fh "$body\n";
    $fh->close;
    sleep(1); # this is to slow down email generation to avoid overloading the mail server
}

sub usage
{
    die "Usage: $0 -mode <testing|production>\n";
}
