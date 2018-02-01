#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_daily_alert.pl
# Created on 11 May, 2009
# Last modified on: 13 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Daily Alert the quarantined mails
#Runs as a cron job or with 86,400 sec sleep
#Checks the quarantine tray for mails held with notify=0 flag
#These are mails that are sent from Env IP that does not match the domain IP country
#i.e. these are spoofs sent from a different country
#--------------------------------------
require "./eighteen_common.pl";
use DBI;
use UTF8;
my $convertor = UTF8->new();
sub MailTheNotification
{
	open (INP, "<$template");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	$mailbody = "";
	for (my $j=0; $j <= $len; $j++)
	{
		$mailbody .= &WSCPReplaceTags($filecontent[$j]);
	}
	&PutHeadersInAckMailFile ($Owner_name, $Enquiry_email, $Enquiry_email, $Enquiry_email, $Alert_email, $Form_subject_user);
    $tfilecontent .= "\n--------------The Following is in HTML Format\n";
#    $tfilecontent .= "Content-Type: text/html; charset=us-ascii\n";
    $tfilecontent .= "Content-Type: text/html; charset=utf-8\n";
    $tfilecontent .= "Content-Transfer-Encoding: 7bit\n\n";
    $tfilecontent .= "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\n";
	$tfilecontent .= $mailbody;
    $tfilecontent .= "\n--------------The Following is in HTML Format--\n";
	my $filename = "$tmpDir/sme_$$.tmp";
	open (OUT, ">$filename");
	print OUT $tfilecontent;
	close (OUT);
	if ($Alert_email =~ /.*\@.*\./ && $Alert_email !~ /;/ && $Alert_email !~ /\s/)
	{
		`$mailprogram -f $Owner_email $Alert_email < $filename`;
		$mailerror = $?;
#print "mailerror = $mailerror		`$mailprogram -f $Owner_email $Alert_email < $filename`;\n";
	}
}
sub ToBeAlerted
{
	$query = "select dailyalert from `users` where (Clean_email='$Alert_email' or Raw_email='$Alert_email')";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	$dailyalert = $results[0];
	if ($dailyalert)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}
sub CheckQuarantine
{
	$query = "select urk,hashcode,senderEmail,recipientEmail,clean_email,sascore,subject from `quarantine` where notified=0 order by clean_email";
	&execute_query($query);
	my @results = &Fetchrow_array(7);
	my $len = $#results;
#print "len = $len\n";
#exit;
#	$messages = "<Table border=0 cellpadding=1 cellspacing=1>\n";
	$prev_clean_email = $results[4];

	$messages = "";
	for (my $j=0; $j <= $len; $j++)
	{
		$urk = $results[$j++]; $msgID = $urk;
		$hashcode = $results[$j++];
		$senderEmail = $results[$j++];
		$recipientEmail = $results[$j++];
			$recipientEmail =~ s/\,/, /gi;
		$Clean_email = $results[$j++];
		$sascore = $results[$j++];
		$subject = $results[$j];
#		&UpdateHistoryTable($dailyalertedcode);
		if ($prev_clean_email ne $Clean_email)
		{
			$Alert_email = $prev_clean_email;
			$prev_clean_email =  $Clean_email;
			$toBeAlerted = &ToBeAlerted;
#			$toBeAlerted = 1; # This is a daily alert and is ON always
#print "toBeAlerted = $toBeAlerted\n";			
			if ($toBeAlerted)
			{
&RecordLogs("1. Sending Daily Alert to $Alert_email\n");				
#print "1. Sending Daily Alert to $Alert_email\n";
#				$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
				$Form_subject_user = "SME: Daily Alert for $ProcessTime";
				$template = $mailtemplate_in_template;
				&MailTheNotification;  # Send the alert only if there is any to be alerted
				$messages = "";
			}
		}
		$messages .= "<tr><td class=\"lines\"><a href=\"$cgiURL?D+$hashcode\">Accept</a> | <a href=\"$cgiURL?B+$hashcode\">Block</a> | <a href=\"$cgiURL?U+$hashcode\">Un-block</a></td><td class=\"lines\">$senderEmail</td><td class=\"lines\">$recipientEmail</td><td class=\"lines\">$subject</td></tr>\n";
	}
	if ($len >= 0)
	{
		$Alert_email = $prev_clean_email;
#print "Sending Alert to $Alert_email; $cgiURL\n";		
		$toBeAlerted = &ToBeAlerted;
#		$toBeAlerted = 1; # This is a daily alert and is ON always
#print "toBeAlerted = $toBeAlerted\n";			
		if ($toBeAlerted)
		{
&RecordLogs("2. Sending Daily Alert to $Alert_email\n");				
#print "2. Sending Daily Alert to $Alert_email\n";
#			$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
			$Form_subject_user = "SME: Daily Alert for $ProcessTime";
			$template = $mailtemplate_in_template;
			&MailTheNotification;  # Send the alert only if there is any to be alerted
			$query = "update `quarantine` set notified=3 where notified=0";
			&execute_query($query);
			$messages = "";
		}
	}
}
sub GetAllLinesFromHistory
{
	$query = "select msgID,senderEmail,recipientEmail,action,subject from `history_temp` where userUrk=$userUrk";
	&execute_query($query);
	@users_history = &Fetchrow_array(5);
}
sub SplitIntoActionCodes
{
	my @actionCodes = split (/,/, $action);
	my $len = $#actionCodes;
	foreach $code (@actionCodes)
	{
		if ($code > 1000) { push (@users_lines, "$code|$msgID|$senderEmail|$recipientEmail|$subject|\n"); }
	}
}

sub GetTodaysStats
{
#	$query = "select sum(inc),sum(spam),sum(vir),sum(rbl),sum(ht),sum(cr),sum(alrt),sum(dalrt),sum(clean),sum(alrt_f),sum(dalrt_f),sum(cr_f),sum(lm_f) from `statistics` where userUrk=$userUrk";
	$query = "select sum(inc),sum(spam),sum(vir),sum(rbl),sum(ht),sum(cr),sum(alrt),sum(dalrt),sum(blk),sum(drprt),sum(clean),sum(alrt_f),sum(dalrt_f),sum(cr_f),sum(lm_f) from `statistics` where userUrk=$userUrk and day = 0";
	&execute_query($query);
	@results = &Fetchrow_array(15);

	$inc 		= $results[0];
	$spam		= $results[1];
	$vir 		= $results[2];
	$rbl 		= $results[3];
	$ht 		= $results[4];
	$cr 		= $results[5];
	$alrt 		= $results[6];
	$dalrt 		= $results[7];
	$blk 		= $results[8];
	$drprt 		= $results[9];
	$clean 		= $results[10];
	$alrt_f 	= $results[11];
	$dalrt_f 	= $results[12];
	$cr_f 		= $results[13];
	$lm_f 		= $results[14];
	$total = $spam + $vir + $alrt + $dalrt + $blk + $drprt + $clean;
	$total_f = $clean + $lm_f + $alrt_f + $cr_f + $dalrt_f;
	if ($results[0]) 
	{ 
		$spamPerc = &Monify($spam/$total*100); 
		$virPerc = &Monify($vir/$total*100);
		$crPerc = &Monify($cr/$total*100);
		$alrtPerc = &Monify($alrt/$total*100);
		$dalrtPerc = &Monify($dalrt/$total*100);
		$drprtPerc = &Monify($drprt/$total*100);
		$blkPerc = &Monify($blk/$total*100);
		$cleanPerc = &Monify($clean/$total*100);
		$alrt_fPerc = &Monify($alrt_f/$total*100);
		$dalrt_fPerc = &Monify($dalrt_f/$total*100);
		$cr_fPerc = &Monify($cr_f/$total*100);
		$lm_fPerc = &Monify($lm_f/$total*100);
		$total_fPerc = &Monify($total_f/$total*100);
	}
	else
	{
		$spamPerc = 0; 
		$virPerc = 0;
		$htPerc = 0;
		$crPerc = 0;
		$alrtPerc = 0;
		$dalrtPerc = 0;
		$drprtPerc = 0;
		$blkPerc = 0;
		$cleanPerc = 0;
		$alrt_fPerc = 0;
		$dalrt_fPerc = 0;
		$cr_fPerc = 0;
		$lm_fPerc = 0;
		$total_fPerc = 0;
	}
}
sub GetTotalStats
{
#	$query = "select sum(inc),sum(spam),sum(vir),sum(rbl),sum(ht),sum(cr),sum(alrt),sum(dalrt),sum(clean),sum(alrt_f),sum(dalrt_f),sum(cr_f),sum(lm_f) from `statistics` where userUrk=$userUrk";
	$query = "select sum(inc),sum(spam),sum(vir),sum(rbl),sum(ht),sum(cr),sum(alrt),sum(dalrt),sum(blk),sum(drprt),sum(clean),sum(alrt_f),sum(dalrt_f),sum(cr_f),sum(lm_f) from `statistics` where userUrk=$userUrk";
	&execute_query($query);
	@results = &Fetchrow_array(15);

	$tot_inc 		= $results[0];
	$tot_spam		= $results[1];
	$tot_vir 		= $results[2];
	$tot_rbl 		= $results[3];
	$tot_ht 		= $results[4];
	$tot_cr 		= $results[5];
	$tot_alrt 		= $results[6];
	$tot_dalrt 		= $results[7];
	$tot_blk 		= $results[8];
	$tot_drprt 		= $results[9];
	$tot_clean 		= $results[10];
	$tot_alrt_f 	= $results[11];
	$tot_dalrt_f 	= $results[12];
	$tot_cr_f 		= $results[13];
	$tot_lm_f 		= $results[14];
	$tot_total = $tot_spam + $tot_vir + $tot_alrt + $tot_dalrt + $tot_blk + $tot_drprt + $tot_clean;
	$tot_total_f = $tot_clean + $tot_lm_f + $tot_alrt_f + $tot_cr_f + $tot_dalrt_f;
	if ($results[0]) 
	{ 
		$tot_spamPerc = &Monify($tot_spam/$tot_total*100); 
		$tot_virPerc = &Monify($tot_vir/$tot_total*100);
		$tot_crPerc = &Monify($tot_cr/$tot_total*100);
		$tot_alrtPerc = &Monify($tot_alrt/$tot_total*100);
		$tot_dalrtPerc = &Monify($tot_dalrt/$tot_total*100);
		$tot_drprtPerc = &Monify($tot_drprt/$tot_total*100);
		$tot_blkPerc = &Monify($tot_blk/$tot_total*100);
		$tot_cleanPerc = &Monify($tot_clean/$tot_total*100);
		$tot_alrt_fPerc = &Monify($tot_alrt_f/$tot_total*100);
		$tot_dalrt_fPerc = &Monify($tot_dalrt_f/$tot_total*100);
		$tot_cr_fPerc = &Monify($tot_cr_f/$tot_total*100);
		$tot_lm_fPerc = &Monify($tot_lm_f/$tot_total*100);
		$tot_total_fPerc = &Monify($tot_total_f/$tot_total*100);
	}
	else
	{
		$tot_spamPerc = 0; 
		$tot_virPerc = 0;
		$tot_htPerc = 0;
		$tot_crPerc = 0;
		$tot_alrtPerc = 0;
		$tot_dalrtPerc = 0;
		$tot_drprtPerc = 0;
		$tot_blkPerc = 0;
		$tot_cleanPerc = 0;
		$tot_alrt_fPerc = 0;
		$tot_dalrt_fPerc = 0;
		$tot_cr_fPerc = 0;
		$tot_lm_fPerc = 0;
		$tot_total_fPerc = 0;
	}
}
sub GetStatistics
{
	&GetTodaysStats;
	&GetTotalStats;
	$statistics_display = "
<Table Border=0 width=80%>
	<tr><td class=captions colspan=5>Statistics for: $Raw_email on $ProcessTime</td></tr>
	<tr><td class=lines colspan=5><hr></td></tr>
	<tr><td class=captions align=left>&nbsp;</td><td bgcolor=\"#804040\" align=center colspan=2>Today</td>
		<td bgcolor=\"#C8B9A4\" align=center colspan=2>Total</td></tr>
<!--
		<tr><td class=captions align=left>Total emails</td><td class=captions align=right>
		$total</td><td class=captions align=right>(100.00%)</td><td class=captions align=right>
		$tot_total</td><td class=captions align=right>(100.00%)</td></tr>
-->
	<tr><td class=captions align=left>Total delivery</td><td class=captions align=right>
		$total_f</td><td class=captions align=right>($total_fPerc%)</td><td class=captions align=right>
		$tot_total_f</td><td class=captions align=right>($tot_total_fPerc%)</td></tr>
	<tr><td class=lines align=left>Accepted and forwarded as in whitelist</td><td class=lines align=right>
		$clean</td><td class=lines align=right>($cleanPerc%)</td><td class=lines align=right>
		$tot_clean</td><td class=lines align=right>($tot_cleanPerc%)</td></tr>
	<tr><td class=lines align=left>Alerted (or direct delivery in training mode)</td><td class=lines align=right>
		$alrt</td><td class=lines align=right>($alrtPerc%)</td><td class=lines align=right>
		$tot_alrt</td><td class=lines align=right>($tot_alrtPerc%)</td></tr>
	<tr><td class=lines align=left>Deleted as Spam</td><td class=lines align=right>
		$spam</td><td class=lines align=right>($spamPerc%)</td><td class=lines align=right>
		$tot_spam</td><td class=lines align=right>($tot_spamPerc%)</td></tr>
	<tr><td class=lines align=left>Deleted as Virus</td><td class=lines align=right>
		$vir</td><td class=lines align=right>($virPerc%)</td><td class=lines align=right>
		$tot_vir</td><td class=lines align=right>($tot_virPerc%)</td></tr>
	<tr><td class=lines align=left>Deleted as in blacklist</td><td class=lines align=right>
		$blk</td><td class=lines align=right> ($blkPerc%)</td><td class=lines align=right>
		$tot_blk</td><td class=lines align=right> ($tot_blkPerc%)</td></tr>
	<tr><td class=lines align=left>Included in daily alert</td><td class=lines align=right>
		$dalrt</td><td class=lines align=right>($dalrtPerc%)</td><td class=lines align=right>
		$tot_dalrt</td><td class=lines align=right>($tot_dalrtPerc%)</td></tr>
	<tr><td class=lines align=left>Included in daily report</td><td class=lines align=right>
		$drprt</td><td class=lines align=right>($drprtPerc%)</td><td class=lines align=right>
		$tot_drprt</td><td class=lines align=right>($tot_drprtPerc%)</td></tr>
	<tr><td class=captions align=left>Total incoming</td><td class=captions align=right>$total</td><td class=captions align=right>(100.00%)</td><td class=captions align=right>
		$tot_total</td><td class=captions align=right>(100.00%)</td></tr>
	<tr><td class=lines align=left>Challenges Sent</td><td class=lines align=right>
		$cr</td><td class=lines align=right>($crPerc%)</td><td class=lines align=right>
		$tot_cr</td><td class=lines align=right>($tot_crPerc%)</td></tr>
	<tr><td class=lines align=left>Accepted from challenge</td><td class=lines align=right>
		$cr_f</td><td class=lines align=right>($cr_fPerc%)</td><td class=lines align=right>
		$tot_cr_f</td><td class=lines align=right>($tot_cr_fPerc%)</td></tr>
	<tr><td class=lines align=left>Accepted from alert</td><td class=lines align=right>
		$alrt_f</td><td class=lines align=right>($alrt_fPerc%)</td><td class=lines align=right>
		$tot_alrt_f</td><td class=lines align=right>($tot_alrt_fPerc%)</td></tr>
	<tr><td class=lines align=left>Accepted from daily alert</td><td class=lines align=right>
		$dalrt_f</td><td class=lines align=right>($dalrt_fPerc%)</td><td class=lines align=right>
		$tot_dalrt_f</td><td class=lines align=right>($tot_dalrt_fPerc%)</td></tr>
	<tr><td class=lines align=left>Delivered in training mode</td><td class=lines align=right>
		$lm_f</td><td class=lines align=right>($lm_fPerc%)</td><td class=lines align=right>
		$tot_lm_f</td><td class=lines align=right>($tot_lm_fPerc%)</td></tr>
	<tr><td class=lines colspan=5><hr></td></tr>
	</Table>

";
}

sub InsertSubTitle
{
	my $code = $_[0]-1000;
	my $end = $_[1];
	my @Titles = ('',
'Possibly legitimate emails (Alerted)',
'Less likely to be legitimate emails',  # In Daily Alert; notify = 0
'Likely to be spam but not deleted',    # In Daily Report; notify = -1
'Challenge sent to sender',
'Sender is on accepted list. Mail forwarded',
'Mostly legitimate emails. Forwarded in training mode',
'Accepted from Alert. Mail forwarded',
'Accepted from Challenge. Mail forwarded',
'Sender is in black list. Deleted',
'Mail contained a virus. Deleted',
'Mail above Spam Threshold. Deleted',
'Invalid email address. Deleted',
'Invalid HELO in header. Deleted',
'Foreign Origin Spam. Deleted',
	);
	$messages .= "<tr><td class=\"captions\" colspan=3><b>$Titles[$code]</b></td></tr>\n";
	$summary .= "<tr><td class=\"captions\" colspan=3><b>$Titles[$code]</b></td>\n";
	if ($n_lines)
	{
		if (!$end)
		{
#			$summary .= "<td class=\"captions\"><b>$n_lines</b></td></tr>\n<tr><td class=\"captions\" colspan=2><b>$Titles[$code]</b></td>";	
			$summary .= "<td class=\"captions\"><b>$n_lines</b></td></tr>\n";	
		}
		else
		{
			$summary .= "<td class=\"captions\"><b>$n_lines</b></td></tr>\n";	
			$summary .= "<td class=\"lines\"  colspan=3>&nbsp;</td></tr>\n";	
		}
	}
	else
	{
		if (!$end)
		{
			$summary .= "<tr><td class=\"captions\" colspan=2><b>$Titles[$code]</td></b>";	
		}
	}
}
sub MakeAcceptLink
{
	my $msgID = $_[0];
	$query = "select hashcode,delivered from `quarantine` where urk=$msgID";
#print "$baseURL\n";
	&execute_query($query);
	@results = &Fetchrow_array(2);
	$hashcode  = $results[0];
	$delivered = $results[1];
	if ($delivered < 2)
	{
#print "		if ($code == 1002) # UCEs\n";
		if ($code == 1002) # UCEs
		{
			$clickLink = "<a href=\"$baseURL$cgiURL?A+$hashcode\">Accept</a> | <a href=\"$baseURL$cgiURL?B+$hashcode\">Block</a>";
		}
		else
		{
			$clickLink = "<a href=\"$baseURL$cgiURL?A+$hashcode\">Accept</a>";
		}
	}
	else
	{
		$clickLink = "Delivered | <a href=\"$baseURL$cgiURL?B+$hashcode\">Block</a>";
	}
}
sub MakeDeleteLink
{
	my $msgID = $_[0];
	$query = "select hashcode,delivered from `quarantine` where urk=$msgID";
#print "$code. $query\n";
	&execute_query($query);
	@results = &Fetchrow_array(2);
	$hashcode  = $results[0];
	$delivered = $results[1];
	$clickLink = "<a href=\"$baseURL$cgiURL?D+$hashcode\">Delete</a>";
}
sub MakeBlockLink
{
	my $msgID = $_[0];
	$query = "select hashcode,delivered from `quarantine` where urk=$msgID";
#print "$code. $query\n";
	&execute_query($query);
	@results = &Fetchrow_array(2);
	$hashcode  = $results[0];
	$delivered = $results[1];
	$clickLink = "<a href=\"$baseURL$cgiURL?B+$hashcode\">Block</a>";
}
sub DisplayLinesForUser
{
	$messages = "";
	$clickLink = "";
	$n_lines = 0;
	my $len = $#users_lines;
	for (my $j=0; $j <= $len; $j++)
	{
		@fields = split (/\|/, $users_lines[$j]);
		$code = $fields[0];
		$msgID = $fields[1];
		$senderEmail = $fields[2];
		$recipientEmail = $fields[3];
		$subject = $fields[4];
		if ($subject =~ /\=\?/)
		{
			$subject = $convertor->smart_convert($subject,"", $subject.$subject);
		}
		else
		{
			$subject = $convertor->convert_charset($subject, "GB2312", "UTF-8");	# When a char encoding is not on the line, assume that it is Chinese Spam. This is not always correct, and the chars will look broken
		}
		if (!$senderEmail && !$subject) { next; } 
if ($Raw_email ne $recipientEmail) { next; } # This will reduce the no. of alerted emails
		if ($code != $previous_code)
		{
			$previous_code = $code;
			if ($n_lines)
			{
				if ($n_lines > $dr_threshold)
				{
					$messages .= "<tr><td class=\"lines\" nowrap><a href=\"$baseURL$cgiURL?Login+$userUrk\">More...</a>&nbsp;</td><td class=\"lines\">&nbsp;</td><td class=\"lines\"></td><td class=\"lines\"></td></tr>\n";
				}
				else
				{
					$messages .= "<tr><td class=\"lines\" nowrap>&nbsp;</td><td class=\"lines\"></td><td class=\"lines\"></td></tr>\n";
				}
			}
			&InsertSubTitle ($code);
			$clickLink = "";
			$n_lines = 0;
			$limitReached = 0;
		}
		if ($code > 1000 && $code <= 1004)
		{
			&MakeAcceptLink ($msgID);
		}
		if ($code  == 1005)
		{
			&MakeDeleteLink ($msgID);
		}
		if ($code  >= 1006 && $code <= 1008)
		{
			&MakeBlockLink ($msgID);
		}
		$n_lines++;
		if ($n_lines > $dr_threshold)
		{
			if ($limitReached) { next; }
			else
			{
				$limitReached = 1;
			}
		}
		else
		{
			$messages .= "<tr><td class=\"lines\" nowrap>$n_lines. $clickLink&nbsp;</td><td class=\"lines\">$senderEmail</td><td class=\"lines\">$subject</td></tr>\n";
		}
#		$messages .= "<tr><td class=\"lines\"><a href=\"$cgiURL?D+$hashcode\">Accept</a> | <a href=\"$cgiURL?B+$hashcode\">Block</a> | <a href=\"$cgiURL?U+$hashcode\">Un-block</a></td><td class=\"lines\">$senderEmail</td><td class=\"lines\">$recipientEmail</td><td class=\"lines\">$subject</td></tr>\n";
	}
	&InsertSubTitle (1000,'1');
#print "$summary\n ";
#exit;
}
sub DailyReport
{
	$query = "drop table if exists `history_temp`";
	&execute_query($query);

	$query = "select DATE_ADD(concat(date_format(now(),'%Y-%m-%d'),' 00:00:00'), INTERVAL -1 DAY)";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	$startdate = $results[0];
#$startdate = '2009-07-11 00:00:00';
	$query = "select now()";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	$enddate = $results[0];

	$query = "create table `history_temp` as select * from `history` where created_date >= '$startdate' and  created_date < '$enddate'";
	&execute_query($query);
#print "$query\n";
	$query = "replace into `history_archive` select * from `history_temp`";
	&execute_query($query);
#	$query = "delete from `history` where created_date >= '$startdate' and  created_date < '$enddate'";
#	&execute_query($query);
#print "$query\n";
#exit;
	$query = "select urk,Raw_email,Clean_email from `users` where dailyalert=2 and cancelled=0 and expiry_date > now() order by urk";
	&execute_query($query);
	my @users_list = &Fetchrow_array(3);
	my $len = $#users_list;
	for (my $j=0; $j <= $len; $j++)
	{
		$userUrk = $users_list[$j++];
		$Raw_email = $users_list[$j++];
		$Clean_email = $users_list[$j];
			$Alert_email = $Clean_email;
		if ($userUrk)
		{
			&GetStatistics; # Get the total stats for the user so far
			&GetAllLinesFromHistory;
			@users_lines = ();  # This is where all lines belonging to the user are held
			my $len = $#users_history;
			for (my $k=0; $k <= $len; $k++)
			{
				$msgID = $users_history[$k++];
				$senderEmail = $users_history[$k++];
				$recipientEmail = $users_history[$k++];
				$action = $users_history[$k++];
				$subject = $users_history[$k];
				&SplitIntoActionCodes;
			}
			@users_lines = sort (@users_lines);
			&DisplayLinesForUser;
#print "Alert_email = $Alert_email\n";			
#$Alert_email = 'avs2904@webgenie.com';	
			$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
			$Form_subject_user = "SME: Daily Report for $ProcessTime";
			$template = $daily_report_in_template;
#			$messages = "<tr><td colspan=\"4\">$statistics_display</tr>\n$summary</tr>\n$messages";
			$messages = "<tr><td colspan=\"4\" align=center>$statistics_display</tr>\n$messages";
			$summary = "";
			&MailTheNotification;
#print "\n@users_lines\n";	
		}
	}
}
#-------------------------------------------------------------------------------
# Main body of the script
sub do_main
{
#	while (1)
	{
		&ConnectToDBase;
#		&CheckQuarantine; # This sends the daily alert of mails marked as notify=0
		&DailyReport; # This sends a comprehensive report of all mails, inc. those marked as notify=0 or notify=-1
		&UpdateMonitorTable("da");
		$dbh->disconnect;
#		sleep (86400); # 1 day
	}
}
$|=1;
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
&do_main;
#CREATE TABLE `whiteaddresses` (  `urk` int(11) NOT NULL auto_increment,  `userUrk` int(11) default '0',    `senderEmail` varchar(100) NOT NULL,  PRIMARY KEY  (`urk`,`senderEmail`))

