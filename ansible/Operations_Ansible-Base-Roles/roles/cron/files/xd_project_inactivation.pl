#!/usr/bin/env perl
use strict;
use DBI;
use Mail::Send;
use Getopt::Long;

my($TEST) = 0;

my($DSN) = 'dbname=teragrid;host=tgcdb.xsede.org';
$DSN = 'dbname=teragrid;host=tgcdb.xsede.org;port=3333' if ($TEST);

my($dbh, $sth, $sql);
my($data);
my($allocation_id, $account_id, $resource_id, $grant_num, $resource_name, $amie_name, $pops_name, $title);
my($allocation, $remaining_allocation, $used, $days_remaining, $percent_remaining);
my($start_date, $end_date);
my($reason, $notify);
my($first_name, $last_name, $email, $e, $cc);
my($charge_num);
my($type, $type_id, $level);
my($system);
my(%info);
my($passwd) = '**REMOVED**';
my(%options) = ();

GetOptions (\%options,
            "-ip"
	    );

$dbh = DBI->connect("dbi:Pg:$DSN",
		    'xdcdb_cron',$passwd,
	            {PrintError=>1, RaiseError=>1}
		   );

$dbh->do("select acct.prune_project_notifications()");

$sql = "
select distinct
	email,
	nullif(trim(both ',' from replace((
		select trim(array_to_string(array_agg(distinct e.email), ','))
		from acct.emailv e
			join acct.account_roles ar on ar.person_id = e.person_id
			join acct.roles r on ar.role_id = r.role_id
		where ar.account_id = nv.account_id
			and r.role_name in ('allocation_manager', 'co_pi')
		group by ar.account_id
	), email, '')), '') as cc,
	account_id,
    resource_id,
    allocation_id,
    resource_name,
    amie_name,
    pops_name,
    grant_number,
    project_title,
    charge_number,
    start_date,
    end_date,
    days_remaining,
    base_allocation,
    remaining_allocation::numeric(38,0),
    percent_remaining,
    first_name,
    last_name,
    notify,
    level,
    type_id,
    type,
    reason
from acct.project_notices_view nv
";

$sth = $dbh->prepare ($sql);
$sth->execute;

while ($data = $sth->fetchrow_hashref)
{
    $account_id           = $data->{account_id};
    $resource_id          = $data->{resource_id};
    $allocation_id        = $data->{allocation_id};
    $resource_name        = $data->{resource_name};
    $amie_name            = $data->{amie_name};
    $pops_name            = $data->{pops_name};
    $grant_num            = $data->{grant_number};
    $title                = $data->{project_title};
    $charge_num           = $data->{charge_number};
    $start_date           = $data->{start_date};
    $end_date             = $data->{end_date};
    $days_remaining       = $data->{days_remaining};
    $allocation           = $data->{base_allocation};
    $remaining_allocation = $data->{remaining_allocation};
    $percent_remaining    = $data->{percent_remaining};
    $first_name           = $data->{first_name};
    $last_name            = $data->{last_name};
    $email                = $data->{email};
    $cc                   = $data->{cc};
    $notify               = $data->{notify};
    $level                = $data->{level};
    $type                 = $data->{type};
    $type_id              = $data->{type_id};
    $reason               = $data->{reason};

    undef $email unless ($notify);

    if ($email)
    {
    	$system = (split /\./,$resource_name)[0];
    	$used = $allocation - $remaining_allocation;

    	$info{'grant_num'}  = $grant_num;
        $info{'title'}      = $title;
    	$info{'charge_num'} = $charge_num;
    	$info{'system'}     = $system;
    	$info{'site'}       = $amie_name;
    	$info{'allocation'} = $allocation;
    	$info{'remaining'}  = $remaining_allocation;
    	$info{'used'}       = $allocation - $remaining_allocation;
    	$info{'%used'}      = 100 - $percent_remaining;
    	$info{'days'}       = $days_remaining;
    	$info{'end_date'}   = $end_date;

    	if ($type eq 'funding')
    	{
    	    mail($email, $cc, "Allocation funds low", funding_msg ());
    	}

    	if ($type eq 'expiring')
    	{
    	    mail($email, $cc, "Allocation nearing expiration", expiring_msg ());
    	}

    	if ($type eq 'out-of-funds')
    	{
    	    mail($email, $cc, "Project out of funds", nofunds_msg ());
    	}

    	if ($type eq 'expired')
    	{
    	    mail($email, $cc, "Allocation expired", expired_msg ());
    	}
    }

    unless ($TEST)
    {
       $e = $dbh->quote($email);
       $dbh->do ("insert into acct.project_notification_messages (allocation_id, type_id, level, email)
	    values ($allocation_id, $type_id, $level, $e)");
    }

}

$sth->finish;

$dbh->do("select acct.inactivate_projects()") if option_flag('ip');

$dbh->disconnect;


sub option_flag
{
    my($opt) = shift;
    my($x) = $options{$opt};
    $x || 0;
}

sub mail
{
    my($to, $cc, $subject, @body) = @_;
    my($fh, $msg);

    if ($TEST)
    {
    	print "To: $to\ncc: $cc\nSubject: XSEDE $subject\n@body\n";
    	return;
    }


    $msg = new Mail::Send;
    $msg->to($to);
    $msg->cc($cc) unless $cc =~ /^\s*$/;
    $msg->subject("XSEDE $subject");
    $msg->set('From', 'XSEDE allocations <allocations@xsede.org>');
    $msg->set('Reply-To', 'allocations@xsede.org');


    $fh = $msg->open('sendmail');
    map { print $fh "$_\n"} @body;
    $fh->close;
}

sub expiring_msg
{
    my($days) = $info{days};
    my($s) = $days == 1 ? "" : "s";
    return compose("Your project noted below will expire in $days day$s");
}

sub expired_msg
{
    return compose("Your project noted below has expired");
}

sub funding_msg
{
    my($p) = $info{'%used'};
    return compose("Your project noted below has used $p% of its allocation");
}

sub nofunds_msg
{
    return compose("Your project noted below has used all of its allocation");
}

sub compose
{
    my($body) = shift;
    my($site) = $info{site};
    $site = defined($site)? "($site)" : "";
    my($org, $email) = qw (XSEDE xsede.org);
    my($msg) = <<EOF;

Dear $org Investigator:

$org policy is that a project either at 100% use or at its expiration date,
whichever is first, will no longer be able to charge compute time.

$body

  Project:    $info{grant_num}
  Title:      $info{title}
  System:     $info{system}
  Allocation: $info{allocation}
  Used:       $info{used}
  Remaining:  $info{remaining}
  End Date:   $info{end_date}

If you have any questions, please email allocations\@$email.

Please note that some sites may choose to continue providing you with
access to your project on their resource(s), independent of $org.
Please check with the respective sites to determine what access you retain.

Sincerely,

$org Allocations

EOF

    return $msg;
}
