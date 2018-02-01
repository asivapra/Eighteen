#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_check_cleang_mail.pl
# Created on 19 Jan, 2010
# Last modified on: 19 Mar, 2010
# Copyright 2009 to 2010 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Check the mails received in gmail@webgenie.com and alert or challenge
#--------------------------------------
require "./eighteen_common.pl";
use DBI;
sub GetMessage_ID
{
	open (INP, "<$mailfile");
	@filecontent = <INP>;
	close (INP);
	$len1 = $#filecontent;
	for (my $k=0; $k <= $len1; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^Message-ID:/i)
		{
			my @fields = split (/:/, $filecontent[$k]);
			$Message_ID = $fields[1];
			$Message_ID =~ s/\n//gi;
			$Message_ID =~ s/ //gi;
			$Message_ID =~ s/\<//gi;
			$Message_ID =~ s/\>//gi;
			$Message_ID =~ s/\'//gi;
			last;
		}
	}
}
sub CheckMails
{
	$newmailDir   = "$qmailDir/$wg_domain/$wg_mbox/Maildir/new";
	$curmailDir   = "$qmailDir/$wg_domain/$wg_mbox/Maildir/cur";
	$tmpmailDir   = "$qmailDir/$wg_domain/$wg_mbox/Maildir/tmp";

	opendir (DIR, "$newmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
	if ($len > 1)
	{
		`mv $newmailDir/* $tmpmailDir`;  # Move from 'new' to 'tmp'
	}
	opendir (DIR, "$curmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
	if ($len > 1)
	{
		`mv $curmailDir/* $tmpmailDir`;  # Move from 'cur' to 'tmp'
	}
	opendir (DIR, "$tmpmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
#print "tmpmailDir = $tmpmailDir; len = $len\n";	
	if ($len > 1)
	{
		for ($j=0; $j <= $len; $j++) # 0 and 1 are . and ..
		{
			$mailfile = "$tmpmailDir/$inputRecords[$j]";
			if (-f $mailfile)
			{
&RecordLogs("CleanG: $mailfile\n");				
				&GetsenderEmailAndIP('check_cleang:CheckMails'); # This gets the $Message_ID as well
#				`rm $mailfile`; # Delete this file from /tmp. Put this line here so that if the program crashes after this point, the mail will not be left dangling
				$query = "select lmode,challenge,urk,userUrk,senderEmail,alert from `quarantine` where Message_ID = '$Message_ID' and delivered = 0";
				&execute_query($query);
				@results = &Fetchrow_array(6);
				my $len = $#results;
#print "1. len=$len;  query = $query\n";
				if ($len < 0)
				{
					# This means the $Message_ID is not in the DB. Maybe it had a null Message_ID previously. So, recreate it
					$Message_ID = "<" . $senderEmail . "_" . $subject . ">";
					$query = "select lmode,challenge,urk,userUrk,senderEmail,alert from `quarantine` where Message_ID = '$Message_ID' and delivered = 0";
					&execute_query($query);
					@results = &Fetchrow_array(6);
					my $len = $#results;
#print "2. len=$len;  query = $query\n";
				}

				$lmode = $results[0];
				$challenge = $results[1];
				$urk = $results[2]; $msgID = $urk;
				$userUrk = $results[3];
				$senderEmail = $results[4];
				$alert = $results[5];
				if ($lmode || (!$alert && !$challenge)) # If in learn mode or BOTH alert and CR are turned off, the mail must be delivered
				{
					#Deliver the mail if lmode =1. No Alert or challenge
					$query = "update quarantine set delivered=1 where Message_ID = '$Message_ID' and delivered = 0";
#print "3. query = $query\n";
					&execute_query($query);
					`rm $mailfile`; # Keep it here so that if the update does not happen, it will be tried at next round
				}
				else
				{
					if ($alert)
					{
						# If lmode = 0, send the Alert. Then, if challenge=1, send challenge
						$query = "update `statistics` set alrt=alrt+1 where userUrk=$userUrk and day=0";
#print "4. query = $query\n";
						&execute_query($query);
						# Set the flag to send alert. To make sure that only one alert is sent, even in cases of repeated settings, set the notified=1 only itf it is zero.
						$query = "update quarantine set notified=1 where Message_ID = '$Message_ID' and notified=0 and delivered = 0"; 
#print "5. query = $query\n";
						&execute_query($query);
						`rm $mailfile`; # Keep it here so that if the update does not happen, it will be tried at next round
#&RecordLogs("$query\n");
#print "Setting Alert\n";
						# Note: There is some error when called from crontab. The update 'history' is happening, but doesn't return from the sub. Shell execution of this script does not have the error.
						# Hence, putting this call after the updating of 'quarantine'
						&UpdateHistoryTable($alertedcode); 
					}
					if ($challenge)
					{
						$query = "update `statistics` set cr=cr+1 where userUrk=$userUrk and day=0";
#print "6. query = $query\n";
						&execute_query($query);
						if ($senderEmail !~ /^$gmailCleanAddress$/i)
						{
							# Send the CR only if the sender is not the same as the address where Gmail forwards clean mails. Otherwise it may result in a loop, though not likely 
							&SendChallenge;
							`rm $mailfile`; # Keep it here so that if the update does not happen, it will be tried at next round
						}
						&UpdateHistoryTable($challengedcode);
					}
				}
			}
		}
	}
}
sub do_main
{
	my $kc;		
#	while (1)
	{
		$kc++;
		print "kc = $kc\n";
	&ConnectToDBase;
		&CheckMails;   # See if any new mail for the user and, if so, move to a temp dir
	$dbh->disconnect;
		sleep(2);
	}
}
$|=1;
&do_main;

