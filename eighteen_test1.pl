#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_check_deliver_hold.pl
# Created on 16 June, 2009
# Last modified on: 21 June, 2009
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------

#Purpose: Analyse the mails in $qmailDir/.../tmp
#This runs as a daemon with 1sec sleep.
#Deliver if mail is from known sender and known IP
#Deliver if known sender with no IP recorded. Add the IP
#Drop if unknown sender and invalid HELO, etc.
#Pass to 'quarantine.pl' if unknown sender or known sender with no IP match
#--------------------------------------

require "./eighteen_common.pl";
use DBI;
sub AntiSpamCheck
{
$ct2 = time();	
	$result = `spamc -c < $mailfile`;
	@result = split (/\//, $result);
$ct3 = time();	
	$score = $result[0];
#print "SA Score: $score; $ct0 - $ct1 - $ct2 - $ct3\n";	
	return $score;
}

sub EnvIPLine
{
print "$filecontent[$k]\n";
	if ($filecontent[$k] =~ /Received: from .*\(\d*\.\d*\.\d*\.\d*\)/) { return 1; }	# e.g Received: from webbox734.server-home.net (195.137.212.174)
	if ($filecontent[$k] =~ /Received: from .*\(\D*\d*\.\d*\.\d*\.\d*\)/) {	return 1; } # e.g Received: from webbox734.server-home.net (postfix@195.137.212.174)
	return 0;
}
sub NextIPLine
{
#print "$filecontent[$k]\n";
	if ($filecontent[$k] =~ /$ip/) { return 0; }
	if ($filecontent[$k] =~ /Received: from .*\[\d*\.\d*\.\d*\.\d*\]/) { return 1; } 
	if ($filecontent[$k] =~ /Received: from .*\(\d*\.\d*\.\d*\.\d*\)/) { return 1; } 
	return 0;
}

sub GetEnvIP
{
	# Get Env ip
	$ip = "EIGHTEEN_LOOKINGFORIT";
print "1. ip = $ip\n";

	for ($k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($envIPLine = &EnvIPLine)
#		if ($filecontent[$k] =~ /Received: from .*\(\d*\.\d*\.\d*\.\d*\)/)
		{
print "\n-------------------------------------------------------------------------\nGetEnvIP: $filecontent[$k]";
			my @fields = split (/\(/, $filecontent[$k]);
			$heloField = 0;
			$ipField = $fields[2];
			if ($ipField)
			{
				$heloField = $fields[1];
			}
			else
			{
				$ipField = $fields[1];
			}
			if ($heloField && $heloField !~ /HELO.*\./ || $heloField =~ /\@/ || $heloField =~ /_/ || ($heloField =~ /HELO\s*\d*\.\d*\.\d*\.\d*\)/))
			{
				$invalidHelo = 1;
				return;
			}
			@fields = split (/\)/, $ipField);
			$ip = $fields[0];
$ip =~ s/^\D*//gi; 
			@ip = split (/\./, $ip);
			$three_octets = "$ip[0].$ip[1].$ip[2]";
			$two_octets = "$ip[0].$ip[1]";
			last;
		}
	}
}
sub GetNextIP
{
print "GetNextIP:  (EnvIP: $ip)\n";
	for ($k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		
#		if ($filecontent[$k] !~ /$ip/ && ($filecontent[$k] =~ /Received:.*\[\d*\.\d*\.\d*\.\d*\]/ || $filecontent[$k] =~ /Received:.*\(\d*\.\d*\.\d*\.\d*\)/))
		if ($nextIPLine = &NextIPLine)
		{
			if ($filecontent[$k] =~ /Received:.*\[.*\]/)
			{
				my @fields = split (/\[/, $filecontent[$k]);
				@fields = split (/\]/, $fields[1]);
				$ip = $fields[0];
				@ip = split (/\./, $ip);
				$three_octets = "$ip[0].$ip[1].$ip[2]";
				$two_octets = "$ip[0].$ip[1]";
				last;
			}
			if ($filecontent[$k] =~ /Received:.*\(.*\)/)
			{
				my @fields = split (/\(/, $filecontent[$k]);
				if ($fields[1] =~ /\d*\.\d*\.\d*\.\d*\)/)
				{
					$ipField = $fields[1];
				}
				else
				{
					$ipField = $fields[2];
				}
				@fields = split (/\)/, $ipField);
				$ip = $fields[0];
				@ip = split (/\./, $ip);
				$three_octets = "$ip[0].$ip[1].$ip[2]";
				$two_octets = "$ip[0].$ip[1]";
				last;
			}
		}
	}
}
sub GetsenderEmailAndIP
{
	open (INP, "<$mailfile");
	@filecontent = <INP>;
	close (INP);
	$len = $#filecontent;
	$ip = "";
	$invalidHelo = 0;
	$heloIsIP = 0;
	&GetEnvIP;
	if (!$ip && !$invalidHelo) { &GetNextIP; }
	# Get senderEmail
	for (my $k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^From:/)
		{
			my @fields = split (/:/, $filecontent[$k]);
			if ($fields[1] =~ /</)
			{
				@fields = split (/</, $fields[1]);
				@fields = split (/>/, $fields[1]);
				$senderEmail = $fields[0];
				$senderEmail =~ s/\s//gi;
				$senderEmail =~ s/\'//gi;
				$senderEmail =~ s/\\//gi;
			}
			else
			{
				$senderEmail = $fields[1];
				$senderEmail =~ s/\s//gi;
				$senderEmail =~ s/\'//gi;
				$senderEmail =~ s/\\//gi;
			}
			last;
		}
	}
print "senderEmail = $senderEmail\n";
	# Get recipientEmail
	for (my $k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^To:/)
		{
			my @fields = split (/:/, $filecontent[$k]);
# To: Arapaut Sivaprasad <asivapra@gmail.com>
# To: asivapra@gmail.com
			if ($fields[1] =~ /</)
			{
				@fields = split (/</, $fields[1]);
				@fields = split (/>/, $fields[1]);
				$recipientEmail = $fields[0];
				$recipientEmail =~ s/\s//gi;
				$recipientEmail =~ s/\'//gi;
				$recipientEmail =~ s/\\//gi;
			}
			else
			{
				$recipientEmail = $fields[1];
				$recipientEmail =~ s/\s//gi;
				$recipientEmail =~ s/\'//gi;
				$recipientEmail =~ s/\\//gi;
			}
			last;
		}
	}
print "recipientEmail = $recipientEmail\n";
	my @recipientEmail = split (/\@/, $recipientEmail);
	my $recipientDomain = $recipientEmail[1];
	if ($localdomains !~ /\|$recipientDomain\|/i)
	{
		&GetNextIP;  # This is to make sure that the IP used is the original and that of gmail.com
	}
print "ip = $ip\n";
	for (my $k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^Subject:/)
		{
			my @fields = split (/Subject:/, $filecontent[$k]);
			$subject = $fields[1];
			$subject =~ s/\n//gi;
			last;
		}
	}
print "subject = $subject\n";
	my $safeSubject = $subject;
	$safeSubject =~ s/\'/\\\'/gi;
	$safeSubject =~ s/\"/\\\"/gi;
	$query = "insert into subjects (subject) values ('$safeSubject')";
	&execute_query($query);
}
sub do_main
{
	$infile = $ARGV[0];
	$mailfile = "$quarantinemailDirTmp/$infile";
	&GetsenderEmailAndIP; # Gets SendEmail, RecipEmail, IP, Subject; Records subject in `subjects`
}
$|=1;
&do_main;

