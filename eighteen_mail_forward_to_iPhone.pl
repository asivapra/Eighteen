#!/usr/local/bin/perl
# Mail forward to avs_webgenie_com@me.com
# Created on 27/02/2020
# Modified on: 04/06/2020
# This is run as a cron job to check and forward mails to avs2904@webgenie.com
# to avs_webgenie_com@me.com. This is necessary to avoid an IP block by me.com
# to mails auto-forwarded by the webgenie.com mailserver. This block probably
# resulted from a past server attack by spammers. Changing the mail server IP
# to something other than 188.138.91.26 and 80.86.87.172 may unblock it.
#-------------------------------------------


sub CheckIfAlreadyForwarded
{
	$file = $_[0];
	if (-f "$archivedir/$file")
	{
#		print "Found it: $file\n";
		return 1;
	}
	return 0;
}

sub ForwardTheMail
{
	$file = $_[0];
	`cp $file $archivedir`;
	`cp $file $tmpdir/fwd_mail.txt`;
#	open(OUT, ">>$forwarded_mails");
#	print OUT "$file\n";
#	close(OUT);
	
	open(INP, "<$tmpdir/fwd_mail.txt");
	@filecontent = <INP>;
	close(INP);
	my $len = $#filecontent;
	$changed = 0;
	$reply_to_address = "";
	for (my $j=0; $j <= $len; $j++)
	{
		if ($filecontent[$j] =~ /^Reply-To: /i)
		{
			$reply_to_address = $filecontent[$j];
			last;
		}
	}
	for (my $j=0; $j <= $len; $j++)
	{
		if ($filecontent[$j] =~ /^Errors-To: /)
		{
			$filecontent[$j] = "";
		}
	}
	for (my $j=0; $j <= $len; $j++)
	{
		if ($filecontent[$j] =~ /^Return-Path: /)
		{
			$filecontent[$j] = "";
		}
	}
	for (my $j=0; $j <= $len; $j++)
	{
		if ($filecontent[$j] =~ /^From: (.*)<(.*)>/)
		{
#			print "$filecontent[$j]";
			$name = $1;
			$address = $2;
#			print "$reply_to\n";
			if ($address =~ /anu.edu.au/i || $address =~ /opengeospatial.org/i)
 			{ 
 				print "NOT forwarding mail from: $name <$address>\n";
 				return; 
 			} # This is already being forwarded from Outlook
			$filecontent[$j] =~ s/$address/noreply\@webgenie.com/g;
#			print "$filecontent[$j]";
			$rewritten = $filecontent[$j];
			open(OUT, ">$tmpdir/fwd_mail.txt");
			for (my $k=0; $k <= $j; $k++)
			{
				print OUT "$filecontent[$k]";
			}
			if (!$reply_to_address) 
			{ 
				$reply_to_address = "Reply-To: $name <$address>\n";
				print OUT $reply_to_address; 
			}
			for ($j++; $j <= $len; $j++)
			{
				print OUT "$filecontent[$j]";
			}
			close(OUT);
			print "Forwarding mail from: $name <$address>\n";
			print "$reply_to_address\n";
			`$mailprogram $recipient < $mailfile`;
			$mailerror = $?;
			print "mailerror = $mailerror\n";
			return;
		}
	}
}

sub ForwardNewMails
{
	chdir ($maildir);
	$pwd = `pwd`;
	$dir = `ls -1`;
	@dir = split(/\n/, $dir);
	my $len = $#dir;
#	$len = 3;
	for (my $j=0; $j <= $len; $j++)
	{
		$found = &CheckIfAlreadyForwarded($dir[$j]);
		if (!$found)
		{
			&ForwardTheMail($dir[$j]);
			return; # Forward only one mail per minute via crontab
#			sleep(1);
		}
	}
}

sub do_main
{	
  	  &ForwardNewMails;
}
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
$mail = "/usr/sbin/sendmail";
$maildir = "/var/qmail/mailnames/webgenie.com/avs2904/Maildir/new";
$tmpdir = "/tmp";
$archivedir = "/usr/local/apache/sites/webgenie.com/usr/records/AVS/Mails_Forwarded";
$forwarded_mails = "$archivedir/forwarded_mails.txt";
$mailprogram = "/usr/sbin/sendmail";
$recipient = 'avs_webgenie_com@me.com';
$mailfile = "$tmpdir/fwd_mail.txt";
$|=1;
&do_main;
sleep(1);
