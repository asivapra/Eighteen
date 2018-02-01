#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_forward.pl
# Created on 16 June, 2009
# Last modified on: 13 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------

#Purpose: Forward the mails accepted via Alert or Challenge
#This runs as a daemon with 1sec sleep.
#--------------------------------------

require "./eighteen_common.pl";
use DBI;

sub AddToWhiteList
{
	@senderEmail = split (/\@/, $senderEmail);
	$senderDomain = $senderEmail[1];
	$senderEmail =~ s/\*\@//gi;  # The domain-level address
	if ($ip)
	{
		@ip = split (/\./, $ip);
		$three_octets = "$ip[0].$ip[1].$ip[2]";
		$two_octets = "$ip[0].$ip[1]";
	}
	else
	{
		$ip = "";
		$three_octets = "";
		$two_octets = "";
	}
	$query = "select count(*) from `whitelist` where senderEmail='$senderEmail' and ip='$ip' and userUrk=$userUrk";
	&execute_query($query);
#print "query = $query\n";
	my @results = &Fetchrow_array(1);
	if (!$results[0])
	{
		$query = "replace into `whitelist` (senderEmail,senderDomain,ip,three_octets,two_octets,accept_method,userUrk) values (\"$senderEmail\",'$senderDomain','$ip','$three_octets','$two_octets','$accept_method',$userUrk)";
#print "query = $query\n";
		&execute_query($query);
	}
	#Remove this address from `ignoredlist`
	$query = "delete from `ignoredlist` where senderEmail='$senderEmail' and userUrk=$userUrk";
	&execute_query($query);
}

sub ForwardCleanMails
{
	$query = "select urk,quarantinedMail,clean_email,Alt_Clean_email,senderEmail,recipientEmail,ip,accept_method,userUrk from `quarantine` where delivered=1";
#&RecordLogs("1. In ForwardCleanMails\n");
	&execute_query($query);
	my @results = &Fetchrow_array(9);
	my $len = $#results;
#&RecordLogs("$query. 1a. In ForwardCleanMails; len = $len\n");
	for (my $j=0; $j <= $len; $j++)
	{
		$urk = $results[$j++]; $msgID = $urk;
		$quarantinedMail = $results[$j++];
			$mailfile = $quarantinedMail;
		$Clean_email = $results[$j++];
			$Clean_email = $Clean_email;
			$userOut = $Clean_email;
		$Alt_Clean_email = $results[$j++];
		$senderEmail = $results[$j++];
		$recipientEmail = $results[$j++];
			$Raw_email = $recipientEmail;
			my @fields = split (/\@/, $recipientEmail);
			$userIn = $fields[0];
			$domain = $fields[1];
		$ip = $results[$j++];
		$accept_method = $results[$j++];
		$userUrk = $results[$j];
#print "Clean_email = $Clean_email; Raw_email = $Raw_email;  mailfile = $mailfile\n";
#next;
		$calledfrom = "Forwarder: ";
		if ($accept_method eq "A")
		{
			&UpdateHistoryTable($cleanmailcode);
		}
#&RecordLogs("2. In ForwardCleanMails\n");
		&DeliverToCleanMailbox;
#&RecordLogs("3. In ForwardCleanMails\n");
		my $delivered = 2;  # Successfully forwarded
		if ($mailerror) { $delivered = 3; } # Unsuccessful
		&AddToWhiteList;
#&RecordLogs("4. In ForwardCleanMails\n");
		$query = "update `quarantine` set delivered=$delivered, notified=5 where urk=$urk";
		&execute_query($query);
		
		if ($accept_method eq "A")
		{
			$query = "update `statistics` set alrt_f=alrt_f+1 where userUrk=$userUrk and day=0";
#print "query = $query\n";		
			&execute_query($query);
		}
		if ($accept_method eq "S")
		{
			$query = "update `statistics` set cr_f=cr_f+1 where userUrk=$userUrk and day=0";
#print "query = $query\n";		
			&execute_query($query);
		}
		if ($accept_method eq "D")
		{
			$query = "update `statistics` set dalrt_f=dalrt_f+1 where userUrk=$userUrk and day=0";
#print "query = $query\n";		
			&execute_query($query);
		}
	}
#&RecordLogs("5. In ForwardCleanMails\n");
	#Archive expired

	#Delete expired
	$query = "select urk from quarantine where expiry_date < now()";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	my $len = $#results;
	for (my $j=0; $j <= $len; $j++)
	{
		$urk = $results[$j++];
		$query = "delete from quarantine where urk=$urk";
		&execute_query($query);
		$quarantinedMail = "$quarantinemailDir/$urk";
		&RecordLogs("Fwd: Removing quarantined mail: $quarantinedMail\n");				
#print "Removing quarantined mail: $quarantinedMail\n";
		`rm $quarantinedMail`;
	}
}
#-------------------------------------------------------------------------------
# Main body of the script
sub do_main
{
#&debugEnv;
	$monitorcycle = 0;  # This will update `monitor` at start
	&ConnectToDBase;
#	while (1)
	{
$k++;		
		$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
#print "$k. $ProcessTime\n";		
#`echo "$ProcessTime" >> forward_pl.txt`;		
		&ForwardCleanMails; # Check for delivered=1 and move clean mails
		&UpdateMonitorTable("fw");
#		sleep (10);
	}
	$dbh->disconnect;
}
$|=1;
&do_main;

