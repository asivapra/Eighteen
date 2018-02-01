#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_userlist_generator.pl
# Created on 24 June, 2009
# Last modified on: 24 June, 2009
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Check the qmail users list and update the `users`
#Runs with 600 sec sleep
#--------------------------------------
require "./eighteen_common.pl";
use DBI;

sub GetAllAccountPasswords
{
#	&ConnectToDBase;
	$query = "SELECT accounts.id, mail.mail_name, accounts.password, domains.name FROM domains LEFT JOIN mail ON domains.id = mail.dom_id LEFT JOIN accounts ON mail.account_id = accounts.id";
	&execute_query($query);
	@accounts = &Fetchrow_array(4);
	$len_ac = $#accounts;
print "@accounts\n";	
#	$dbh->disconnect;
}
sub GetTheUserPassword
{
	$accounts_id = 0;
	$mail_name = "";
	$Password = "UNASSIGNED";
	$domain_name = "";
	for (my $j=0; $j <= $len_ac; $j++)
	{
		$accounts_id = $accounts[$j++];
		$mail_name = $accounts[$j++];
		$Password = $accounts[$j++];
		$domain_name = $accounts[$j];
#print "		if ($user eq $mail_name && $domain eq $domain_name)\n";
		if ($user eq $mail_name && $domain eq $domain_name)
		{
			return;
		}
	}
}
sub CheckQmailUsersList
{
	$filedate = `ls -l $qmailuserslist`;
print "filedate = $filedate\n";	
	if ($prevFiledate ne $filedate)
	{
		$query = "use psa";
		&execute_query($query);
		&GetAllAccountPasswords;
		$query = "use securemyemail";
		&execute_query($query);
		$prevFiledate = $filedate;
#=4-avs:popuser:110:31:/var/qmail/mailnames/webgenie.com/avs:::
		open (INP, "<$qmailuserslist");
		@filecontent = <INP>;
		close (INP);
		$len = $#filecontent;
		@users = ();
print "prevFiledate = $prevFiledate\n";	
		for (my $j=0; $j <= $len; $j++)
		{
			$line = $filecontent[$j];
			if ($line =~ /^=/)
			{
				my @fields = split (/:/, $line);
				$user   = $fields[0];
				$user   =~ s/^=\d*-//gi;
				$domain = $fields[4];
				@fields = split (/\//, $domain);
				$domain = $fields[4];
				$owner  = $fields[5];
				if ($user eq $owner)
				{
					&GetTheUserPassword;
					my $User_email = "$user\@$domain";

					$query = "select count(*) from `users_test` where Raw_email='$User_email'";
					&execute_query($query);
					my @results = &Fetchrow_array(1);
					if (!$results[0])
					{
print "User_email = $User_email; password = $Password; ID = $accounts_id; domain = $domain_name\n";	
						$query = "insert into `users_test` (urk,User_email,Raw_email,Password,wg_domain,alertFrequency,created_date) values ($accounts_id,'$User_email','$User_email','$Password','$domain_name',60,now())";
#						&execute_query($query);
						$query = "insert into `statistics` (userUrk) values ($accounts_id)";
#						&execute_query($query);
					}

#					push (@users, $User_email);
#print "$j. user = $user; domain = $domain; owner = $owner; User_email = $User_email; password = $Password; ID = $accounts_id; domain = $domain_name\n";	
				}
			}
			else
			{
				next;
			}
		}
		return 1;
	}
	return 0;
}
#-------------------------------------------------------------------------------
# Main body of the script
sub do_main
{
	$onceonly = $ARGV[0];
#	while (1)
	{
		&ConnectToDBase;
		$action = &CheckQmailUsersList;
		$dbh->disconnect;
		if ($onceonly) { last; }
		sleep (1); # 
	}
}
$qmailuserslist = '/var/qmail/users/assign';
$|=1;
&do_main;

