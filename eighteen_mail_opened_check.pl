#!/usr/local/bin/perl
# Track when a sent mail is opened by the recipient
# Created on 11/06/2020
# Modified on: 11/06/2020
# This is run as a cron job to check that a mail sento external address has
# been opened.
#------------------------------------------------------------------------------

require "/var/www/vhosts/webgenie.com/cgi-bin/debug.pl";
use List::MoreUtils qw(firstidx);
use DBI;
use Date::Parse;
use DateTime;
use IP::Location;

sub IPlocation
{
	my $ip = $_[0];
	$iplocation = `wget --quiet -O - https://iplocation.com/?ip=$ip`;
#	&d($iplocation);
	@iplocation = split(/\n/, $iplocation);
	my $len = $#iplocation;
	$table_result = "<table class=\"table result-table no-script\">";
	$i = firstidx { $_ =~ /$table_result/ } @iplocation;
	$iplocation_table = "";
	for (my $j=$i; $j <= $len; $j++)
	{
		$iplocation_table .= $iplocation[$j] . "\n";
		if ($iplocation[$j] =~ /<\/table>/i) { last; }
	}
	$iplocation_table =~ s/<a href.*<\/a>//gi;
	$iplocation_table =~ s/<th /<th align=left /gi;
	$iplocation_table =~ s/<th>/<th align=left>/gi;
#	&d($result_table);
}

sub TimeDiff
{
	my $t1 = $_[0];
	my $t2 = $_[1];
#	$t1 = 'Jun/12/2020:13:20:45';
#	$t2 = 'Jun/12/2020:13:26:04';
	my $diff = str2time($t2) - str2time($t1);
	return $diff;
}

sub ConnectToDBase
{
$driver = "mysql";
$hostname = "localhost";
$database = "mailopened"; 
$dbuser="avs";
$dbpassword='2Kenooch';
   $dsn = "DBI:$driver:database=$database;host=$hostname";
   $dbh = DBI->connect($dsn, $dbuser, $dbpassword);
   $drh = DBI->install_driver("mysql");
}

sub execute_query
{
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
sub AddToDatabase
{
	&ConnectToDBase;
	#select user_id, rand, to_address, ip, opened_time from mails where user_id='avs123456789' and rand=123456781 and to_address='avs_webgenie_com@me.com' and ip='49.195.91.51' and status=1;
	$query = "select user_id, to_address, opened_time from mails where user_id='$this_user_id' and rand=$this_rand and to_address='$this_address' and status=1 limit 0,1";
#	&d($query);
	&execute_query($query);
	my @results = &Fetchrow_array(3);
	$user_id = $results[0];
#	$rand = $results[1];
	$to_address = $results[1];
#	$ip = $results[3];
	$mailed_time = $results[2];
#&debug("query = $query; perc = $perc");
	if (!$user_id)
	{
		#insert into `mails` (user_id, rand, to_address, opened_time, ip, sent_time) values ('avs123456789', 123456781, 'avs_webgenie_com@me.com', 'Jun/12/2020:13:20:45', '49.195.91.51', true)
		$query = "insert into `mails` (user_id, rand, to_address, opened_time, ip, sent_time) values ('$this_user_id', '$this_rand', '$this_address', '$this_time', '$this_ip', true)";
#		&d($query);
		&execute_query($query);
	}
	else
	{
		$diff = &TimeDiff($mailed_time, $this_time);
#		&d("diff=$diff");
		if ($diff > 30)
		{
			$query = "select `id` from `mails` where user_id='$this_user_id' and rand=$this_rand and to_address='$this_address' and ip='$this_ip' and opened_time='$this_time' and status=1 limit 0,1";
#			&d($query);
			&execute_query($query);
			my @results = &Fetchrow_array(1);
			$id = $results[0];
			if (!$id)
			{
				$query = "select `user_email` from `users` where user_id='$this_user_id' and status=1 limit 0,1";
				&execute_query($query);
				my @results = &Fetchrow_array(1);
				$user_email = $results[0];
				$query = "insert into `mails` (user_id, rand, to_address, opened_time, ip, sent_time) values ('$this_user_id', '$this_rand', '$this_address', '$this_time', '$this_ip', true)";
				&execute_query($query);
				$subject = "Mail Opened by $this_address";
				&IPlocation($this_ip);
				$content = "
				<table cellspacing=\"1\" style=\"width: 400px; border-left-style: solid; border-left-width: 1px; border-right: 1px solid #C0C0C0; border-top-style: solid; border-top-width: 1px; border-bottom: 1px solid #C0C0C0\">
					<tr>
						<td>Sender ID:&nbsp;</td>
						<td>$user_id&nbsp;</td>
					</tr>
					<tr>
						<td>Sender:&nbsp;</td>
						<td>$user_email&nbsp;</td>
					</tr>
					<tr>
						<td>Recipient:&nbsp;</td>
						<td>$to_address&nbsp;</td>
					</tr>
					<tr>
						<td>Sent at:&nbsp;</td>
						<td>$mailed_time&nbsp;</td>
					</tr>
					<tr>
						<td>Opened at:&nbsp;</td>
						<td>$this_time&nbsp;</td>
					</tr>
					<tr>
						<td colspan=2><hr></td>
					</tr>
					<tr>
						<td colspan=2>
						<b>Location:</b><br>
							$iplocation_table
						</td>
					</tr>
				</table>
				";
				&d("Sending mail");
				&SendMailToOwner;
exit;
			}
		}
#		&d("ip=$ip; this_ip=$this_ip, opened_time=$opened_time; this_time=$this_time; user_id=$user_id; this_user_id=$this_user_id; rand=$rand; this_rand=$this_rand; to_address=$to_address; this_address=$this_address");
	}
	$dbh->disconnect;
}

sub FindTheSentLine
{
	$logLines = `grep "GET /img/mail/" /var/www/vhosts/system/webgenie.com/logs/access_ssl_log`;
	@logLines = split(/\n/, $logLines);
	$len = $#logLines;
#	&d("$len. @logLines");
	for (my $j=0; $j <= $len; $j++)
	{
#		&d("$j. $logLines[$j]");
		$logLines[$j] =~ tr/  / /s;
		@fields = split(/ /, $logLines[$j]);
		$this_ip = $fields[0];
		$time = $fields[3]; #[12/Jun/2020:08:59:51
		$img = $fields[6];
#		&d("$ip; $time; $img");
	
		# Convert the time to a parsable format as Month/Date/Year:Hour:Min:Sec. e.g Jun/12/2020:13:20:45
		@fields = split(/:/, $time); # [12/Jun/2020:13:20:45
		$time = "$fields[1]:$fields[2]:$fields[3]"; # Time part. 13:20:45

		@fields = split(/\//, $fields[0]); # Date part. [12/Jun/2020
		$fields[0] =~ s/\[//g; # 12
		$date = "$fields[1]/$fields[0]/$fields[2]"; # Jun/12/2020
		
		$this_time = "$date:$time"; # Jun/12/2020:13:20:45
#		&d("$ip; $time; $img");

		# Proceed only if the img part is in the right format
		if ($img =~ /\/img\/mail\/(.*)\.png\?(\d*)\+(.*)/) # /img/mail/avs123456789.png?123456781+avs_webgenie_com@me.com
		{
			$this_user_id = $1;
			$this_rand = $2;
			$this_address = $3;
			&AddToDatabase;
		}
	}
}

sub do_main
{
#	my $ip = "49.195.91.51";	
#	&IPlocation ($ip);
#	&TimeDiff;
#	&ReadTheAccessLog;
	&FindTheSentLine;
#	&CheckMailOpened;
}
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
$accesslog = "/var/www/vhosts/system/webgenie.com/logs/access_ssl_log";
$archivedir = "/usr/local/apache/sites/webgenie.com/usr/records/AVS/Mails_Opened_Checked";
$reported_lines = "$archivedir/sent_lines.txt";
$tmpdir = "/tmp";
$mailprogram = "/usr/sbin/sendmail";
$recipient = 'avs2904@webgenie.com';
$from_address = 'avs2904@webgenie.com';
$|=1;
&do_main;
sleep(1);
#CREATE TABLE `mails` (`id` int(4) NOT NULL AUTO_INCREMENT,  `user_id` varchar(30) NOT NULL DEFAULT '', `rand` varchar(30) NOT NULL DEFAULT '', `to_address` varchar(50) NOT NULL DEFAULT '', `sent_time` bool default null, `opened_time` varchar(30) NOT NULL DEFAULT '',  `ip` varchar(15) NOT NULL DEFAULT '', `status` int(1) DEFAULT '1',  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
#CREATE TABLE `users` (  `id` int(4) NOT NULL AUTO_INCREMENT,  `user_id` varchar(30) NOT NULL DEFAULT '',  `firstname` varchar(30) DEFAULT NULL,  `lastname` varchar(30) DEFAULT NULL,  `user_email` varchar(30) NOT NULL DEFAULT '',  `password` varchar(30) NOT NULL DEFAULT '',  `status` int(1) DEFAULT '1',  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,  PRIMARY KEY (`user_id`),  KEY `id` (`id`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1; 

#insert into `users` (user_id, user_email, password) values ('avs123456799', 'avs2904@webgenie.com', 'test12345');
#insert into `mails` (user_id, rand, to_address, opened_time, ip) values ('avs123456789', '123456781', 'avs_webgenie_com@me.com', 'Jun/12/2020:13:20:45', '49.195.91.51');

