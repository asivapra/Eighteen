#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_quarantine.pl
# Created on 29 April, 2009
# Last modified on: 19 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Check the mails from unknown senders for...
#Spam check: and drop if above threshold and from unknown sender
#If no spam and known sender but no IP match, set notify=1. These could be those sending from hotels
#If no spam but unknown sender, check the Country for Env IP and Domain IP
#If they differ, set notify=0. No challenge sent. These will go into daily alert
#If Env IP and Domain IP are from same country, set notify=1 and send challenge
#--------------------------------------
require "./eighteen_common.pl";
use DBI;
#use Net::Whois::IP qw(whoisip_query);
use Net::DNS;
use Socket;
sub GetLocation_LACNIC
{
	$IP = $_[0];
	$whois = `$whoisProgram -h whois.lacnic.net $IP`;
	@whois = split (/\n/, $whois);
	$Country = "Unknown";
	foreach $line (@whois)
	{
		if ($line =~ /^Country/i)
		{
			$Country = $line;
			$Country =~ s/\n//gi;
			$Country =~ s/Country://gi;
			$Country =~ s/\s//gi;
			last;
		}
	}
	return $Country;
}
sub GetMXip
{
	my $senderDomain = $_[0];
	$mxIP = 0;
	$digResult = `$digProgram mx $senderDomain`;
	@digResult = split (/\n/, $digResult);
	my $len = $#digResult;
	for (my $j=0; $j <= $len; $j++)
	{
		if ($digResult[$j] =~ /;; ANSWER SECTION:/)
		{
			$line = $digResult[$j+1];
			last;
		}
	}
	my @fields = split (/ /, $line);
	$len = $#fields;
	$mxDomain = $fields[$len];
	if ($mxDomain !~ /.*\..*/)
	{
		return 0;
	}
	$mxIPResult = `$nslookupProgram $mxDomain`;

	@mxIPResult = split (/\n/, $mxIPResult);
	my $len = $#mxIPResult;
	for (my $j=0; $j <= $len; $j++)
	{
		if ($mxIPResult[$j] =~ /Name:/)
		{
			$line = $mxIPResult[$j+1];
			last;
		}
	}
	my @fields = split (/ /, $line);
	$len = $#fields;
	$mxIP = $fields[$len];
	if ($mxIP !~ /\d*\.\d*\.\d*\.\d*/)
	{
		return 0;
	}
	return $mxIP;
}
sub GetDomainIP
{
  my $domain_name = $_[0];
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->search($domain_name);
  if ($query) 
  {
      foreach my $rr ($query->answer) 
	  {
          next unless $rr->type eq "A";
		  $IP = $rr->address;
		  return $IP;
      }
  } 
  else 
  {
	  return "";
  }
}
sub GetMXdomain
{
  my $domain_name = $_[0];
  my $res  = Net::DNS::Resolver->new;
  my @mx   = mx($res, $domain_name);
  if ($mx[0]) { $mxDomain = $mx[0]->exchange; }
  return $mxDomain;
}
sub WeedOutSpam
{
	#This applies only when the Env and MX countries do no match
	#Logic is that a mail generally originates from the same server where the MX record is pointing to
	#If coming from an IP in a country other than that of the MX record means spoofed spam
	#Exceptions:
	#1. A company having their MX record redirected to an Anti-spam service such as Spamarrest
	#2. A traveler sending from an SMTP server in another country
	# The following list are countries most likely sending spam
	# Do not include in there countries where companies redirecting MX 
	#to third party AS servers, but using own SMTP server for outbound
	if ($EnvCountry =~ /RU/i) { return -2; } # Russia
	if ($EnvCountry =~ /RO/i) { return -2; } # Romania
	if ($EnvCountry =~ /CN/i) { return -2; } # China
	if ($EnvCountry =~ /KR/i) { return -2; } # Korea
	if ($EnvCountry =~ /NG/i) { return -2; } # Nigeria
	if ($EnvCountry =~ /BR/i) { return -2; } # Brazil
#	if ($EnvCountry =~ /ES/i) { return -1; } # Spain
#	if ($EnvCountry =~ /IN/i) { return -1; } # India
	return -1; # This must be 0 to be safe. -1 will block all inter-country mailing
}
sub GetMxIPnumber
{
	my $mxIP = 0;
	# Firstly, check with my own code. It is faster
	$mxIP = &GetMXip($senderDomain);
	# If no result try using Net::DNS
	if (!$mxIP)
	{
		$mxDomain = &GetMXdomain($senderDomain);
		if ($mxDomain)
		{
			$mxIP = &GetDomainIP($mxDomain);
		}
		else
		{
			$mxIP = 0;
		}
	}
	return $mxIP;
}
sub CheckKnownIps
{
	$query = "select count(*) from `whiteips` where (userUrk=$userUrk or userUrk=0) and two_octets = '$two_octets'"; # May have to be more stringent than 2-octets here
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	if (!$results[0])
	{
		$query = "select count(*) from `whitelist` where two_octets = '$two_octets'"; # May have to be more stringent than 2-octets here
		&execute_query($query);
		my @results = &Fetchrow_array(1);
	}
	return $results[0];  # Check the DB before returning
}
sub CheckDomainValidity
{
#list@en.ucc.xe.net
#	$tlds = "|com|org|net|edu|gov|info|name|club|game|keyword|firm|gen|ind|sch|ebiz|asn|phone|mobi|web|rec|per|store|other|gen|geek|school|maori|nom|asso|biz|waw|";
#    $senderDomain = $_[0];
	$mxIP = &GetMxIPnumber;
	if ($mxIP =~ /\d*\.\d*\.\d*\.\d*/)
	{
		return 1;
	}
	else
	{
		$packed_ip = gethostbyname($senderDomain);
		if (defined $packed_ip) 
		{
			return 1; # Domain name is valid
		}
		else
		{
			$da_reason = "Domain Invalid";
			return -2;
		}
	}
}
sub CheckSubjects
{
	my @chars = split (//, $subject);
	my $len = $#chars;
	if ($len < 3) { return 1; }
	
	# Set notify=0 if there are too many subject lines that are not delivered
	$query = "select count(*) from `subjects` where subject='$subject' and delivered=0";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	if ($results[0] > $subjectThreshold) 
	{ 
		$da_reason = "IGNORED_SUBJECTS_$results[0]";
		return 0; 
	}
	return 1;
}
sub BackScatterControl
{
	$smtpIP = 0;
	my $j;
	open (INP, "<$mailfile");
	@mailfilecontent = <INP>;
	close (INP);
	my $len = $#mailfilecontent;
	#skip header
	for ($j=0; $j <= $len; $j++)
	{
		if ($mailfilecontent[$j] eq "\n") { last; }
	}
	
	#Get the IP from the "Received: from" line in the body of DFN
	for ($j++; $j <= $len; $j++)
	{
		if ($mailfilecontent[$j] =~ /^Received: from/) 
		{ 
			if ($mailfilecontent[$j] =~ /\[/)
			{
				my @fields = split (/\[/, $mailfilecontent[$j]);
				if ($fields[1])
				{
					my @fields = split (/\]/, $fields[1]);
					$smtpIP = $fields[0];
				}
				last; 
			}
			if ($mailfilecontent[$j] =~ /\(/)
			{
				my @fields = split (/\(/, $mailfilecontent[$j]);
				if ($fields[2])
				{
					my @fields = split (/\)/, $fields[2]);
					$smtpIP = $fields[0];
				}
				last; 
			}
		}
	}

	if ($smtpIP)
	{
		# Check whether this user has backscatter control
		$query = "select count(*) from `smtpips` where userUrk='$userUrk'";
		&execute_query($query);
		my @results = &Fetchrow_array(1);
		if ($results[0])
		{
			# Initially set the notify=0, assuming that the IP does not match
			$notify = 0;
			my @ip = split (/\./, $smtpIP);
			my $three_octets = "$ip[0].$ip[1].$ip[2]";
			my $two_octets = "$ip[0].$ip[1]";
			
			# Check whether the smtpIP is in user's backscatter control
			$query = "select count(*) from `smtpips` where two_octets='$two_octets' and userUrk='$userUrk'";
			&execute_query($query);
			my @results = &Fetchrow_array(1);
			if ($results[0])
			{
				$notify = 1;
			}
		}
	}
}
sub AddToBeIgnored
{
	# Make a note that this has been notified. Then, if the user has ignored the sender too many times, dont alert it
	&execute_query($query);
	$query = "select urk from `ignoredlist` where senderEmail='$senderEmail' and userUrk=$userUrk";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	$ignoredID = $results[0];
	#Put this address in ignoredlist and take off if the user accepts the sender. Then, if the count exceeds threshold, the mail can be left out of alerts
	if ($ignoredID)
	{
		$query = "update `ignoredlist` set ignored=ignored+1 where urk=$ignoredID"; 
	}
	else
	{
		$query = "insert into `ignoredlist` (senderEmail,recipientEmail,userUrk,ignored) values ('$senderEmail','$recipientEmail',$userUrk,1)";
	}
	&execute_query($query);
}
sub CleanItViaGmail
{
	if ($notify > 0)
	{
# Interim measure to stop the mail with "Hello" as subject. This is being bounced by Gmail		
#$bannedSubj = &CheckBannedSubject;  
#if ($bannedSubj) { return; }
#		$notignored = &CheckIgnoredList('CleanItViaGmail');
#		&AntiVirusCheck; # Put through CLAMAV. This comes before clean mail delivery
		if (!$virus && $sascore <= $saThreshold)
		{
#			&AddToBeIgnored;
			if (!$notignored)
			{
				`$mailprogram -f $noreplyEmail $gmailaddress < $mailfile`;
				&RecordLogs("CleanItViaGmail: ($gmailaddress): $subject - $senderEmail\n");	
				$query = "update `quarantine` set sent_to_clean=1 where urk=$urk"; 
				&execute_query($query);
			}
			else
			{
				&RecordLogs("CleanItViaGmail: Not Sent. IgnoredList: $da_reason\n");	
			}
		}
	}
	if ($notify == 0)
	{
		&UpdateHistoryTable($dailyalertedcode);
		$query = "update `statistics` set dalrt=dalrt+1 where userUrk=$userUrk and day=0";
		&execute_query($query);
	}
	if ($notify < 0)
	{
		&UpdateHistoryTable($dailyreportcode);
		$query = "update `statistics` set drprt=drprt+1 where userUrk=$userUrk and day=0";
		&execute_query($query);
	}
}
sub CheckRecipientMail
{
	if (!$recipientEmail || $recipientEmail =~ /undisclosed-recipient/i) 
	{ 
		$da_reason = "No Recip Mail or Undisclosed";
		return -2; 
	}
	else { return 1; }
}

sub CheckMails
{
	$urk = $ARGV[0]; $msgID = $urk;
	$knownuser = $ARGV[1];
	$lmode = $ARGV[2];
	&ConnectToDBase;
	$query = "select quarantinedMail,challenge,alert,senderEmail,recipientEmail,subject,userUrk,ip,hashcode from `quarantine` where urk=$urk";
	&execute_query($query);
	my @results = &Fetchrow_array(9);
	$mailfile = $results[0];
	$challenge = $results[1];
	$alert = $results[2];
	$senderEmail = $results[3];
	my @fields = split (/\@/, $senderEmail);
	$senderDomain = $fields[1];
	$recipientEmail = $results[4];
	my $Enquiry_email = $recipientEmail;  # This is probably not required
	$subject = $results[5];
	$userUrk = $results[6];
	$senderIP = $results[7];
	$ip = $senderIP;
	@ip = split (/\./, $senderIP);
	$three_octets = "$ip[0].$ip[1].$ip[2]";
	$two_octets = "$ip[0].$ip[1]";
	$hashcode = $results[8];
	$notify = 1;
#	$notify = &CheckIgnoredList; # If this is to be ignored, no need to SA check it. Simply qurantine it.
	if ($knownuser == 0)
	{
		if ($notify > 0)
		{
			if (&SelfSpoofCheck) { $notify = -2; } # This is a self spoof
			if ($notify > 0)
			{
				$notify = &CheckRecipientMail; # See if it is 'undisclosed' 
				if ($notify > 0)
				{
					#If still notify=1
					$notify = &CheckDomainValidity;  # See whether the sender domain has a DNS record
					if ($notify > 0)
					{
						#Check whether the Env IP and Domain IP are related
						$notify = &CheckEnvCountryAlone;  # See whether the sender IP comes from the same country as sender Domain's MX record
						if ($notify > 0)
						{
#								$notify = &CheckSubjects;  # See if this subject line appears more than threshold
						}
					}
				}
			}
		}
	}
	if ($notify == -2) # This is experimental. Deleting all hard spam without SA checking
	{
		&UpdateHistoryTable($deletedByHeuristicscode);
		$query = "update `statistics` set spam=spam+1 where userUrk=$userUrk and day=0";
		&execute_query($query);
		&RecordLogs("Self spoof, EnvCountry_banned, No Recip Mail or Undisclosed, Invalid Domain or SPF failed.\n");				
		return;
	}
	$sascore = 0;  # default
	if ($notify > 0) # Check only if going to be alerted
	{
#		&AntiSpamCheck; # Use this as a step to cut down the no. of mails sent to Gmail for cleaning. Put through ctasd or spamassasin. This means known users will not be affected
		if ($sascore > $saThreshold)
		{
			$notify = 0;
			&UpdateHistoryTable($spamassasincode);
			$query = "update `statistics` set spam=spam+1 where userUrk=$userUrk and day=0";
			&execute_query($query);
#			&RecordLogs("Mail is Spam: $sascore. $da_reason $senderEmail\n");				
			return;
		}
	}
	if ($sascore < 0)  # These are accredited domains. Put them in Instant alert without further check
	{
		$notify = 1;
	}
# If pushing to Daily Alert:
	if ($notify <= 0)
	{
		$query = "insert into `dailyalerted` (senderEmail,recipientEmail,subject,da_reason,userUrk) values ('$senderEmail','$recipientEmail','$subject','$da_reason',$userUrk)";
		&execute_query($query);
	}
}
sub do_main
{
	&CheckMails;
	&CleanItViaGmail;
	if (!$sascore || $rbl_sender) { $sascore = "NA"; }	
	&RecordLogs("SA Score: $sascore (RBL:$rbl_sender). notify:$notify; $da_reason | $senderEmail | $recipientEmail\n"); # | Env: $EnvCountry | MX: $MxCountry\n");				
	$dbh->disconnect;
}
$|=1;
&do_main;

