#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_maillog_reader.pl
# Created on 21 June, 2009
# Last modified on: 13 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Check the maillog for outbound mails and add the recipient address to white list
#Check the maillog every 10min and pick up new recipeints
#Add to whitelist without the IP
#Currently doing for only webgenie.com.
#Must make it generic by taking the local domains from database
#Must also find out and insert the userUrk
#--------------------------------------
require "./eighteen_common.pl";
use DBI;

sub GetAndAddToWhiteList
{
#Jun 21 20:15:01 balder554 qmail-remote-handlers[23099]: from=avs@webgenie.com
#Jun 21 20:15:01 balder554 qmail-remote-handlers[23099]: to=s_unger@yoo-design.com
		for ($j; $j <= $len; $j++)
		{
			if ($filecontent[$j] =~ /qmail-remote-handlers\[\d*\]:\sfrom=.*\@$localDomain/i)
			{
				@fields = split (/\[/, $filecontent[$j]);
				@fields = split (/\]/, $fields[1]);
				$pid = $fields[0];
				if ($pid)
				{
					@fields = split (/=/, $filecontent[$j]);
					$fromEmail = $fields[1];
					$fromEmail =~ s/\n//gi;
					if ($excludedEmails =~ /\|$fromEmail\|/i) { next; }
					for (my $k=$j+1; $k <= $len; $k++)
					{
						if ($filecontent[$k] =~ /\[$pid\]:\sto=.*\@/i)
						{
							@fields = split (/=/, $filecontent[$k]);
							$toEmail = $fields[1];
							$toEmail =~ s/\n//gi;
						}
					}
				}
#print "$j. $fromEmail ==> $toEmail; $pid\n";
				$query = "select count(*) from `whitelist` where senderEmail='$toEmail'";
				&execute_query($query);
				@results = &Fetchrow_array(1);
				if (!$results[0])
				{
					$query = "insert into `whitelist` (senderEmail) values (\"$toEmail\")";
					&execute_query($query);
				}
			}
		}	
}
sub do_main
{
#	while (1)
	{
		open (INP, "<$maillog");
		@filecontent = <INP>;
		close (INP);
		$len = $#filecontent;
#print "len = $len\n";		
		if (!$lastline || $lastline > $len)
		{
			$lastline = 0;
		}
		
		for ($j=$lastline; $j <= $len; $j++)
		{
			&ConnectToDBase;
			&GetAndAddToWhiteList;
			&UpdateMonitorTable("mr");
			$dbh->disconnect;
		}
		$lastline = $len;
#		sleep (60);
	}
}
$maillog = "/usr/local/psa/var/log/maillog";
$localDomain = 'exonmail.com';
$excludedEmails = '|noreply@exonmail.com|support@exonmail.com|';
@localDomains = ('exonmail.com');
$|=1;
&do_main;

