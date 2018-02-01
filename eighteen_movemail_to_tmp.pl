#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_movemail_to_tmp.pl
# Created on 15 June, 2009
# Last modified on: 21 June, 2009
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Move the mails from $qmailDir/.../new to $qmailDir/.../tmp
#This is an atomic operation and therefore very quick. 
#This script runs as a daemon at 1 sec intervals
#There is a small risk that a user may download the mails from /.../new before 
#it has been moved. This can result in downloading spam that may even be virus.
#Probability of it depends on the frequency of mail downloads.
#If the auto download is set at 10min, the probability of a spam downloaded is 1:600 mails received
#Assuming 3% spam is virus, the probability of a virus being downloaded is: 1:20,000
#If an average user gets 100 mails a day, one spam per 6 days and 1 virus in 200 days
#One spam in 6 days is not too bad, but 1 virus in 200 days is still bad
#To prevent this, the virus check must be moved up to the MTA level and mail dropped.
#--------------------------------------
use DBI;
sub ConnectToDBase
{
   $driver = "mysql";
   $database = "securemyemail";
   $hostname = "localhost";
   $user="admin";
   $dbpassword="2kenooch";
   $dsn = "DBI:$driver:database=$database;host=$hostname";
   $input;
   $dbh = DBI->connect($dsn, $user, $dbpassword);
   $drh = DBI->install_driver("mysql");
}

sub execute_query
{
#return;	
#&debug ("query = $query");	
	$sth=$dbh->prepare($query);
	$rv = $sth->execute or die "can't execute the query: $sth->errstr";
}

sub Fetchrow_array
{
   $tablerows = $_[0];
   my @results = ();
   while(@entries = $sth->fetchrow_array)
   {
	   for ($jj=0; $jj < $tablerows; $jj++)
	   {
		   push (@results, $entries[$jj]);
	   }
   }
   my $numreturned = scalar(@results)/$tablerows;
   return @results;
}
sub GetUsersList
{
	@users = ();
	$query = "select Raw_email,Clean_email,challenge,alert,urk,sharedUrk from `users` where cancelled=0";
	&execute_query($query);
	@results = &Fetchrow_array(6);
	my $len = $#results;
#print "query = $query; len = $len\n";
	for (my $j=0; $j <= $len; $j++)
	{
		$user = "$results[$j]\|$results[$j+1]\|$results[$j+2]\|$results[$j+3]\|$results[$j+4]\|$results[$j+5]";
		$j+=5;
		push (@users, $user);
	}
}
sub CheckMails
{
#print "0. clean_email = $clean_email\n";	
	opendir (DIR, "$newmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
#print "newmailDir = $newmailDir; len = $len\n";
	if ($len > 1) # if even one mail is in there
	{
		`mv $newmailDir/* $tmpmailDir`;  # Move from 'new' to 'tmp'
print "eighteen_movemail_to_tmp:$newmailDir\n";
	}
}
sub do_main
{
	$cycle = 0;  # Check how many cycles covered
	&ConnectToDBase;
	&GetUsersList;
	while (1)
	{
		$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
		$clean_email = "";
#print "$ProcessTime; refreshCycle = $refreshCycle\n";		
		if ($refreshCycle == 0) # Once every 360 cycles (1 hr) refresh the users list
		{
			&GetUsersList;
			$cycle = 0; 
		}
		foreach $user (@users)
		{
			my @fields = split (/\|/, $user);
			$userIn = $fields[0];
			$userOut = $fields[1];
			$challenge = $fields[2];
			$alert = $fields[3];
			$userUrk = $fields[4];
			$sharedUrk = $fields[5];
			my @fields = split (/\@/, $userIn);
			$userIn = $fields[0];
			$domain = $fields[1];
			$newmailDir   = "$qmailDir/$domain/$userIn/Maildir/new";
			$curmailDir   = "$qmailDir/$domain/$userIn/Maildir/cur";  # The mails get transferred to 'cur' after a while. So, check and move from there as well
			$tmpmailDir   = "$qmailDir/$domain/$userIn/Maildir/tmp";
			&CheckMails;   # See if any new mail for the user and, if so, move to a temp dir
		}
		sleep (1);
		$cycle++;
		$refreshCycle = $cycle%$usersRefreshCycles;
	}
	$dbh->disconnect;
}
#-------Globals---------------------------------------------		
$qmailDir = "/var/qmail/mailnames";
$usersRefreshCycles = 2; # How often the users list is refreshed

$|=1;
&do_main;

