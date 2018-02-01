#!/usr/local/bin/perl
#/usr/local/bin/Exonmail/eighteen_control.pl
# Created on 16 June, 2009
# Last modified on: 19 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
require "./diff_dirs.pl";
require "$binDir/eighteen_common.pl";
use DBI;

sub MailTheNotification
{
	open (INP, "<$mailtemplate_in_template");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	$mailbody = "";
	for (my $j=0; $j <= $len; $j++)
	{
		$mailbody .= &WSCPReplaceTags($filecontent[$j]);
	}
	$Form_subject_user = "SME: **** Daemons Restarted on $wg_domain";
	&PutHeadersInAckMailFile ($Owner_name, $Owner_email, '', '', $Admin_email, $Form_subject_user);
    $tfilecontent .= "\n--------------The Following is in HTML Format\n";
    $tfilecontent .= "Content-Type: text/html; charset=us-ascii\n";
    $tfilecontent .= "Content-Transfer-Encoding: 7bit\n\n";
    $tfilecontent .= "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\n";
	$tfilecontent .= $mailbody;
    $tfilecontent .= "\n--------------The Following is in HTML Format--\n";
	my $filename = "$tmpDir/sme_$$.tmp";
	open (OUT, ">$filename");
	print OUT $tfilecontent;
	close (OUT);
	if ($Admin_email =~ /.*\@.*\./ && $Admin_email !~ /;/  && $Admin_email !~ /\s/)
	{
		`$mailprogram -f $Owner_email $Admin_email < $filename`;
		$mailerror = $?;
#print "mailerror = $mailerror		`$mailprogram -f $Owner_email $Admin_email < $filename`;\n";
	}
}
sub CheckTheProcesses
{
	#See if processes are running at all.
print "Checking processes...\n";
	#spamd
	$pspamd = `ps -ef | grep /usr/sbin/spamd | grep /usr/bin/perl | grep -v grep`;
print "pspamd = $pspamd\n";
	@pspamd = split (/\n/, $pspamd);
	$len = $#pspamd;
print "len = $len\n";
	if ($len < 0)
	{
		&RestartSpamd;
		print OUT1 "Spamd wasn't running. Restarted\n";
	}

	$psme = `ps -ef | grep eighteen_ | grep -v grep | grep -v eighteen_control`;
	@psme = split (/\n/, $psme);
	$len = $#psme;
	if ($len < 0) # This is teh number of processes. 
	{
		$src='cron';
		&RestartDaemons;
		print OUT1 "One or more daemons was not running. Restarted\n";
		return;
	}
print "Checking sleep times...\n";
	&ConnectToDBase;
	$query = "select cm,fw,al,da,mr,cu from `monitor` where urk=1";
	&execute_query($query);
	@results = &Fetchrow_array(6);
	$dbh->disconnect;
	my $len = $#results;
	for (my $j=0; $j <= $len; $j++)
	{
		$cm = $results[$j++];
		$fw = $results[$j++];
		$al = $results[$j++];
		$da = $results[$j++];
		$mr = $results[$j++];
		$cu = $results[$j];
		last;
	}
	$ct = time();
	$cmt = $ct - $cm;
	$fwt = $ct - $fw;
	$alt = $ct - $al;
	$dat = $ct - $da;
	$mrt = $ct - $mr;
	$cut = $ct - $cu;
#sleep times: cm = 1; fw = 10; al = 10; da = 86400; mr = 60; cu = 10;
#monitorRefreshCycles = 10;
	
#real:
#	if ($cmt > 120 || $fwt > 120 || $alt > 300 || $dat > 86700 || $mrt > 900 || $cut > 120) 
#	if ($cmt > 120 || $fwt > 120 || $alt > 300 || $cut > 120) 
	if ($cmt > 120) 
	{ 
#print "	if ($cmt > 120 || $fwt > 120 || $alt > 300 || $cut > 120)\n"; 

		$src='Cron';
		&RestartDaemons; 
		print OUT1 "One or more daemons was not reporting. Restarted all daemons\n";
	}
#print "	if ($cmt > 120 || $fwt > 120 || $alt > 300 || $dat > 86700 || $mrt > 900 || $cut > 120) { &RestartDaemons; }\n";
#debug:
#	if ($cmt > 3 || $fwt > 3 || $alt > 3 || $dat > 3 || $mrt > 3 || $cut > 3) { &RestartDaemons; }
}
sub RestartSpamd
{
	#spamd
	$pspamd = `ps -ef | grep /usr/sbin/spamd | grep -v grep`;
	@pspamd = split (/\n/, $pspamd);
	$len = $#pspamd;
	for ($j=0; $j <= $len; $j++)
	{
		$pspamdLine = $pspamd[$j];
		$pspamdLine =~ tr/  / /s;
		@fields = split (/ /, $pspamdLine);
		$pid = $fields[1];
		if ($pspamdLine =~ /\/usr\/sbin\/spamd/)
		{
		`kill -TERM $pid`;
		}
	}
	system ('/usr/sbin/spamd &');
#print "		system ('/usr/sbin/spamd &');\n";
}
sub RestartDaemons
{
print "Restarting...\n";	
	&ConnectToDBase;
	$query = "insert into `monitor` (restart) values ('$src:$ProcessTime')";
	&execute_query($query);
	$dbh->disconnect;
	#stop
	$psme = `ps -ef | grep eighteen_ | grep -v grep | grep -v eighteen_control`;
	@psme = split (/\n/, $psme);
	$len = $#psme;
	for ($j=0; $j <= $len; $j++)
	{
		$psmeLine = $psme[$j];
		$psmeLine =~ tr/  / /s;
		@fields = split (/ /, $psmeLine);
		$pid = $fields[1];
		if ($psmeLine =~ /eighteen_/)
		{
		`kill -TERM $pid`;
		}
	}

	#start daemons
	system ("$binDir/eighteen_check_mail.pl &");
	
	$psme = `ps -ef | grep eighteen_ | grep -v grep | grep -v eighteen_control`;
	$messages = "<pre>
One or more IGM daemons was not running on $wg_domain. Restarted at: $ProcessTime

Please investigate if this recurs too often.

Currently running PIDS:
$psme
</pre>
	";
	&MailTheNotification;
#	sleep (60); # Wait for the daemons to update the monitor
}
sub do_main
{
	if ($action eq "cron")
	{
		open (OUT1, ">>eighteen_control.log");
		print OUT1 "$ProcessTime\n";
		&CheckTheProcesses;
		close (OUT1);
		return;
	}

#Manual stop / restart
#	if ($action =~ /stop/i || $action =~ /restart/i)
	if ($action =~ /stop/i)
	{
		$psme = `ps -ef | grep eighteen_ | grep -v grep | grep -v eighteen_control`;
		@psme = split (/\n/, $psme);
		$len = $#psme;
		for ($j=0; $j <= $len; $j++)
		{
			$psmeLine = $psme[$j];
			$psmeLine =~ tr/  / /s;
			@fields = split (/ /, $psmeLine);
			$pid = $fields[1];
			if ($psmeLine =~ /eighteen_/)
			{
print "Stopping $pid\n";
			`kill -TERM $pid`;
			}
		}
	}
	
	# See whether spamd is running
#	$pspamd = `ps -ef | grep /usr/sbin/spamd | grep -v grep`;
#	@pspamd = split (/\n/, $pspamd);
#	$len = $#pspamd;
	if ($action =~ /spamd/i)
	{
		&RestartSpamd;
#		for ($j=0; $j <= $len; $j++)
#		{
#			$pspamdLine = $pspamd[$j];
#			$pspamdLine =~ tr/  / /s;
#			@fields = split (/ /, $pspamdLine);
#			$pid = $fields[1];
#			if ($pspamdLine =~ /\/usr\/sbin\/spamd/)
#			{
#print "Stopping Spamd: $pid\n";
#			`kill -TERM $pid`;
#			}
#		}
#		system ('/usr/sbin/spamd &');
	}
	
	if ($action =~ /start/i || $action =~ /restart/i)
	{
		$src='csme';
		&RestartDaemons;
#print "Starting...\n";	
#		system ('/usr/local/bin/Exonmail/eighteen_check_mail.pl &');
#		system ('/usr/local/bin/Exonmail/eighteen_forward.pl &');
#		system ('/usr/local/bin/Exonmail/eighteen_alert.pl &');
##		system ('/usr/local/bin/Exonmail/eighteen_daily_alert.pl &');
##		system ('/usr/local/bin/Exonmail/eighteen_maillog_reader.pl &');
#		system ('/usr/local/bin/Exonmail/eighteen_create_user.pl &');
		$psme = `ps -ef | grep eighteen_ | grep -v grep | grep -v eighteen_control`;
		print "$psme\n";
	}
#	sleep (1);
}
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
$action = $ARGV[0];
if (!$action) { $action = "restart"; }
$|=1;
&do_main;

