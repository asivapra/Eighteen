#!/usr/local/bin/perl
# Mail forward to avs_webgenie_com@me.com
# Created on 04/06/2020
# Modified on: 10/06/2020
# This is run as a cron job to check that a mail sento external address has
# been delivered.
#------------------------------------------------------------------------------

use List::MoreUtils qw(firstidx);
require "/var/www/vhosts/webgenie.com/cgi-bin/debug.pl";

sub SendMailToOwner
{
	my $Owner_name = "Mail Delivery Monitor";
	my $Owner_email = 'avs2904@webgenie.com';
#	$filecontent = $content;
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
#	my @filecontent = $_[0];
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
					if ($line =~ /from=$from_address/)
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
#								&debug ("$delivery to $to_address");
								$subject = "$delivery from $from_address to $to_address";
								print "$subject: $result\n";
								$result =~ s/success/<font style=\"color:green; font-weight:bold\">Success<\/font>/gi;
								$content .= "$subject:\n $result<br>\n";
								$subject = "Outgoing Mail Delivered";
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
	chdir ($archivedir);
	open (INP, "<$maillog");
	@filecontent = <INP>;
	close(INP);
	my $len = $#filecontent;

	# We must skip upto and including the line previously recorded.
#	open (INP, "<$last_line");
#	$check_line = <INP>;
#	close(INP);
	
#	$idx = firstidx { $_ eq $check_line } @filecontent;
#	my @lines = ();
	# Take the last 200 lines instead of recording the last line. The latter can occassionally miss a delivery.
	$idx = $len - 500;
	if ($idx < 0) { $idx = 0; }
	@lines = splice (@filecontent, $idx, $len);
#	if ($idx >= 0) 
#	{
#		$idx++; # Skip the prev line.
		# Found this line. Now, splice the array
#		$check_line = $filecontent[$len];
#		@lines = splice (@filecontent, $idx, $len);

#		@lines = splice (@filecontent, $idx, $len);
#		print "@lines\n";
#		$len = $#lines;
#		open (OUT, ">$last_line");
#		print OUT "$check_line";
#		close(OUT);
#	}
#	else
#	{
#		# The previous line is not in maillog. This will happen when maillog is rotated at 6:25am
#		@lines = @filecontent;
#		$check_line = $filecontent[$len];
#		open (OUT, ">$last_line");
#		print OUT "$check_line";
#		close(OUT);
#	}
	$delivered = &CheckIfDelivered;

}

sub do_main
{	
  	  &CheckMailDelivered;
}
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
$mail = "/usr/sbin/sendmail";
$maillog = "/usr/local/psa/var/log/maillog";
$archivedir = "/usr/local/apache/sites/webgenie.com/usr/records/AVS/Mails_Delivery_Checked";
$last_line = "$archivedir/last_line.txt";
$tmpdir = "/tmp";
$checked_mails = "$archivedir/mails_delivered.txt";
$mailprogram = "/usr/sbin/sendmail";
$recipient = 'avs2904@webgenie.com';
$from_address = 'avs2904@webgenie.com';
$mailfile = "$tmpdir/delivered_mail.txt";
$mailprogram = "/usr/sbin/sendmail";
$|=1;
&do_main;
sleep(1);
