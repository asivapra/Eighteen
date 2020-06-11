#!/usr/local/bin/perl
# Mail forward to avs_webgenie_com@me.com
# Created on 04/06/2020
# Modified on: 10/06/2020
# This is run as a cron job to check that a mail sento external address has
# been delivered.
#------------------------------------------------------------------------------

use List::MoreUtils qw(firstidx);
#require "/var/www/vhosts/webgenie.com/cgi-bin/debug.pl";

sub SendMailToOwner
{
	my $Owner_name = "Mail Delivery Monitor";
	my $Owner_email = 'avs2904@webgenie.com';
	$tfilecontent =  "From:$Owner_name <$Owner_email>\n";
	$tfilecontent .=  "To:$Owner_name <$Owner_email>\n";
	$tfilecontent .= "MIME-Version: 1.0\n";                                 # Inactivate this line to send text-only msg
	$tfilecontent .= "Subject:$subject\n";
	$tfilecontent .= "Content-Type: text/html; charset=ISO-8859-1; format=flowed\n";
	$tfilecontent .= "Content-Transfer-Encoding: 7bit\n\n";
	$tfilecontent .= $content;

	my $filename = "$tmpDir/hn_$$.tmp";
	open (OUT, ">$filename");
	print OUT $tfilecontent;
	close (OUT);
	`$mailprogram -t < $filename`;
	$mailerror = $?;
	if(!$mailerror)
	{
		unlink($filename);
	}
}
sub CheckIfDelivered
{
=pod
Jun 10 20:42:51 zulu282 qmail: 1591785771.138809 starting delivery 293: msg 76424444 to remote paulsingh@jadoo.com.au
Jun 10 20:42:51 zulu282 qmail-remote-handlers[3882]: from=avs2904@webgenie.com
Jun 10 20:42:51 zulu282 qmail-remote-handlers[3882]: to=paulsingh@jadoo.com.au
Jun 10 20:43:36 zulu282 qmail: 1591785816.273118 delivery 293: success: 103.146.112.32_accepted_message./Remote_host_said:_250_OK_id=1jiyCl-0004o3-HE/
=cut
	my $len = $#lines;
	$content = "";
	for (my $j0=0; $j0 <= $len; $j0++)
	{
		my $line = $lines[$j0];
		$from_address_ok = 0;
		$to_address_ok = 0;
		$result = "";
		if ($line =~ /starting (delivery \d*):.* to remote (.*)\n$/)
		{
			$delivery = $1;
			$to_address = $2;
			if ($to_address eq 'avs_webgenie_com@me.com') { next; }
			if ($to_address eq 'asivapra@gmail.com') { next; }
			for ($j=$j0+1; $j <= $len; $j++)
			{
				my $line = $lines[$j];
				if ($line =~ /from=/)
				{
					if ($line =~ /from=$from_address1/ || $line =~ /from=$from_address2/)
					{
						$from_address_ok = 1;
					}
					else
					{
						next;
					}
					for ($j++; $j <= $len; $j++)
					{
						my $line = $lines[$j];
						if ($line =~ /to=/)
						{
							if ($line =~ /to=$to_address/)
							{
								$to_address_ok = 1;
								last;
							}
							else
							{
								next;
							}
						}
					}
					if ($from_address_ok && $to_address_ok)
					{
						for ($j++; $j <= $len; $j++)
						{
							my $line = $lines[$j];
							if ($line =~ /$delivery: (.*)\n$/)
							{
								$result = $1;
								$subject = "$delivery to $to_address";
								open (INP, "<$reported_lines");
								@reported_lines = <INP>;
								close(INP);
								$i = firstidx { $_ =~ /$subject/ } @reported_lines;
								if ($i >= 0)
								{
									print "Already Reported: $subject\n";
									next;
								}
								else
								{
									open (OUT, ">>$reported_lines");
									print OUT "$ProcessTime: $subject\n";
									close(OUT);
								}
								print "$subject: $result\n";
								if ($result !~ /success/)
								{
									$failed = 1;
								}
								$result =~ s/success/<font style=\"color:blue; font-weight:bold\">Success<\/font>/gi;
								$result =~ s/_250_/<font style=\"color:blue; font-weight:bold\">_250_<\/font>/gi;

								$result =~ s/failure/<font style=\"color:red; font-weight:bold\">Failure<\/font>/gi;
								$result =~ s/deferral/<font style=\"color:red; font-weight:bold\">deferral<\/font>/gi;

								$content .= "$subject:\n $result<br>\n";
								if ($failed) {	$subject = "Outgoing Mail: Failure - $to_address"; }
								else { $subject = "Outgoing Mail: Success - $to_address"; }
								last;
							}
						}
					}
					else
					{
						last;
					}
				}
			}
		}
	}
	if ($content) { &SendMailToOwner; }
}
sub CheckMailDelivered
{
	open (INP, "<$maillog");
	@filecontent = <INP>;
	close(INP);
	my $len = $#filecontent;

	# Take the last 1000 lines instead of recording the last line. 
	# It takes a max of 1 min from start to finish and hence around 100 lines are sufficient. 
	# But, during spammer attacks there may be more lines. So, take 1000 for safety.
	$idx = $len - 1000;
	if ($idx < 0) { $idx = 0; }
	@lines = splice (@filecontent, $idx, $len);
	$delivered = &CheckIfDelivered;
}

sub do_main
{	
  	  &CheckMailDelivered;
}
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
$maillog = "/usr/local/psa/var/log/maillog";
$archivedir = "/usr/local/apache/sites/webgenie.com/usr/records/AVS/Mails_Delivery_Checked";
#$last_line = "$archivedir/last_line.txt";
$reported_lines = "$archivedir/reported_lines.txt";
$tmpdir = "/tmp";
$checked_mails = "$archivedir/mails_delivered.txt";
$mailprogram = "/usr/sbin/sendmail";
$recipient = 'avs2904@webgenie.com';
$from_address1 = 'avs2904@webgenie.com';
$from_address2 = 'avs@webgenie.com';
$mailfile = "$tmpdir/delivered_mail.txt";
$|=1;
&do_main;
sleep(1);
