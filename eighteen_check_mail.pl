#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_check_mail.pl
# Created on 16 June, 2009
# Last modified on: 4 Jan, 2018 - Edit 1
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------

#Purpose: Analyse the mails in $qmailDir/.../tmp
#This runs as a daemon with 1sec sleep.
#Call 'eighteen_check_mail_2.pl' for each user who has some mails 
#--------------------------------------

require "./eighteen_common.pl";
use DBI;
sub CheckMails
{
	$newmailDir   = "$qmailDir/$domain/$userIn/Maildir/new";
	$tmpmailDir   = "$qmailDir/$domain/$userIn/Maildir/tmp";
	opendir (DIR, "$newmailDir");
	@inputRecords = readdir (DIR);
	closedir (DIR);
	my $len = $#inputRecords;
	if ($len > 1)
	{
		`mv $newmailDir/* $tmpmailDir`;  # Move from 'new' to 'tmp'
		system ("$eighteen_check_mail_2 $user&"); # This is spawned separately, as spamc takes several seconds
	}
}
sub LearnModeCheck
{
	$query = "select count(*) from `users` where learnmode_end_date > now() and urk=$urk";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	return $results[0];
}

sub CreateClean_email
{
	my @fields = split (/\@/, $Raw_email);
	$Clean_email = $fields[0];
	$Clean_email =~ s/\_/\@/gi; # e.g. avs_webgenie.com@exonmail.com => avs@webgenie.com
}
sub GetUsersList
{
	@users = ();
	$query = "select User_email,Raw_email,Clean_email,Alt_Clean_email,challenge,alert,urk,sharedUrk,learnmode_end_date from `users` where cancelled=0 and expiry_date > now()";
	&execute_query($query);
	@results = &Fetchrow_array(9);
	my $len = $#results;
	for (my $j=0; $j <= $len; $j++)
	{
		$Admin_email = $results[$j++];
		$Raw_email = $results[$j++];
		$Clean_email = $results[$j++];
		if ($Clean_email !~ /\@/)
		{
			&CreateClean_email; # If $Clean_email is absent, take the raw email and convert it. This will send the mail back to the original address. It is important that the user has set the filters on their address to keep it in the imbox without forwarding 
		}
		$Alt_Clean_email = $results[$j++];
		$challenge = $results[$j++];
		$alert = $results[$j++];
		$urk = $results[$j++];
		$sharedUrk = $results[$j++];
		$learnmode_end_date = $results[$j];

		$lmode = 0; # Not in LM
		$lmode = &LearnModeCheck;
		$user = "$Admin_email,$Raw_email,$Clean_email,$Alt_Clean_email,$challenge,$alert,$urk,$sharedUrk,$lmode";
		push (@users, $user);
	}
}
#-------------------------------------------------------------------------------
# Main body of the script
sub do_main
{
#&debugEnv;
	$cycle = 0;  # Check how many cycles covered
	$monitorcycle = 0;  # This will update `monitor` at start
	&ConnectToDBase;
	&GetUsersList;
	while (1)
	{
		$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
		$Clean_email = "";
print "Cycle # $cycle: $ProcessTime\n";		
		if ($refreshCycle == 0) # Once every 360 cycles (1 hr) refresh the users list
		{
print "Users List Refreshed: $ProcessTime\n";		
			&GetUsersList;
			$cycle = 0; 
		}
		foreach $user (@users)
		{
			my @fields = split (/\,/, $user);
			$Admin_email = $fields[0];
			$userIn = $fields[1];
				$Raw_email = $userIn;
			$userOut = $fields[2];
				$Clean_email = $userOut;
			$Alt_Clean_email = $fields[3];
			$challenge = $fields[4];
			$alert = $fields[5];
			$userUrk = $fields[6];
			$sharedUrk = $fields[7];
			$lmode = $fields[8];
			my @fields = split (/\@/, $userIn);
			$userIn = $fields[0];
			$domain = $fields[1];
			&CheckMails;   # See if any new mail for the user and, if so, move to a temp dir
		}
#print "UpdateMonitorTable\n";		
		&UpdateMonitorTable("cm");
		sleep (10);
		$cycle++;
		$refreshCycle = $cycle%$usersRefreshCycles;
	}
	$dbh->disconnect;
}
$usersRefreshCycles = 100; # How often the users list is refreshed
$|=1;
&do_main;
#CREATE TABLE `whitelist` (`senderEmail` varchar(100) NOT NULL, urk bigint(11) auto_increment,  `userUrk` bigint(11) default '0', senderDomain varchar(100) NOT NULL, `ip` varchar(15) NOT NULL,  `three_octets` varchar(11) not NULL,  `two_octets` varchar(7) not NULL,  `accept_method` char(1) default '', `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP, PRIMARY KEY  (`urk`,`senderEmail`,`ip`)) ENGINE=MyISAM DEFAULT CHARSET=latin1;
#CREATE TABLE `blacklist` (  `senderEmail` varchar(100) NOT NULL default '', urk bigint(11) auto_increment, `recipientEmail` varchar(100) NOT NULL default '', `userUrk` bigint(11) default '0', PRIMARY KEY  (`urk`, `senderEmail`,`recipientEmail`)) ENGINE=MyISAM DEFAULT CHARSET=latin1;
#CREATE TABLE `ignoredlist` (  urk bigint(11), `senderEmail` varchar(100) NOT NULL default '', `recipientEmail` varchar(100) NOT NULL default '', `userUrk` bigint(11) default '0',`notified` int(2) default '0', `ignored` int(2) default '0', PRIMARY KEY  (`urk`,`senderEmail`,`recipientEmail`)) ENGINE=MyISAM DEFAULT CHARSET=latin1;

#CREATE TABLE `users` (  `urk` bigint(11) NOT NULL auto_increment,  `User_email` varchar(100) NOT NULL default '', `Raw_email` varchar(100) NOT NULL default '', `Clean_email` varchar(100) NOT NULL default '', `Alt_Clean_email` varchar(100) NOT NULL default '',`wg_domain` varchar(100) NOT NULL default '', `User_name` varchar(100) NOT NULL default '',  `Password` varchar(20) default NULL,  `Newsletter` int(1) default '0',  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,  `modified_date` datetime default NULL,  `lastaccess_date` datetime default NULL,  `cancelled` int(1) default '0',  `spamming` int(3) default '0',  `status` int(1) default '1', `challenge` int(1) default '1', `alert` int(1) default '1', `alertFrequency` int(3) default '6', `sharedUrk` bigint(11) default '0',  `learnmode_end_date` datetime default NULL, `expiry_date` datetime default NULL, `dailyalert` int(1) default 1, PRIMARY KEY  (`urk`, `User_email`,`Raw_email`));
#CREATE TABLE `admin_users` (  `urk` bigint(11) NOT NULL auto_increment,  `User_email` varchar(100) NOT NULL default '', `Alternative_Email` varchar(100) NOT NULL default '', `wg_domain` varchar(100) NOT NULL default '', `User_name` varchar(100) NOT NULL default '',  `Password` varchar(20) default NULL,  `Newsletter` int(1) default '0',  `n_boxes` int(4) default '0',  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,  `modified_date` datetime default NULL,  `lastaccess_date` datetime default NULL,  `expiry_date` datetime default NULL,  `next_billing_date` datetime default NULL,  `unit_price` decimal(10,2) default NULL,  `payment_cleared` int(1) default '0',  `paypal_PNREF` varchar(30) default '',  `recurring_billing` int(1) default '0',  `cancelled` int(1) default '0',  `spamming` int(3) default '0',  `Reseller` varchar(30) default NULL,  `status` int(1) default '1',  `confirmed` int(1) default NULL, redirection_method varchar(10) default 'email', PRIMARY KEY  (`urk`,`User_email`));
#CREATE TABLE `admin_domains` (  `urk` bigint(11) NOT NULL auto_increment,  `User_email` varchar(100) NOT NULL default '', `admin_domain` varchar(100) NOT NULL default '', `status` int(1) default '0', `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP, PRIMARY KEY  (`urk`,`User_email`));
#CREATE TABLE `statistics` (  `userUrk` bigint(11) default '0', `day` int(5) default '0',  `inc` bigint(11) default '0',   `spam` bigint(11) default '0',   `vir` bigint(11) default '0', `rbl` bigint(11) default '0',  `ht` bigint(11) default '0', `cr` bigint(11) default '0', `alrt` bigint(11) default '0', `dalrt` bigint(11) default '0',  `clean` bigint(11) default '0',   `alrt_f` bigint(11) default '0', `dalrt_f` bigint(11) default '0', `cr_f` bigint(11) default '0', `lm_f` bigint(11) default '0',  PRIMARY KEY  (`userUrk`,`day`));
#CREATE TABLE `users_tobeadded` (  `urk` bigint(11) NOT NULL auto_increment,  `User_email` varchar(100) NOT NULL default '', `Raw_email` varchar(100) NOT NULL default '', `Clean_email` varchar(100) NOT NULL default '', `Alt_Clean_email` varchar(100) NOT NULL default '',`IGM_domain` varchar(100) NOT NULL default '',  `Reseller` varchar(30) default NULL, `User_name` varchar(100) NOT NULL default '',  `Password` varchar(20) default NULL,  `Newsletter` int(1) default '0',  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,  `modified_date` datetime default NULL,  `lastaccess_date` datetime default NULL,  `status` int(1) default '1',  `expiry_date` datetime default NULL, PRIMARY KEY  (`urk`, `User_email`,`Raw_email`));
#CREATE TABLE `monitor` (  `urk` bigint(11) NOT NULL auto_increment,  `restart` char(35) default '', `cm` int(11) default 0,  `fw` int(11) default 0,  `al` int(11) default 0,  `da` int(11) default 0,  `mr` int(11) default 0,  `cu` int(11) default 0, PRIMARY KEY  (`urk`));
#CREATE TABLE `localdomains` (  `urk` bigint(11) NOT NULL auto_increment,  `localdomain` char(100) default '', `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP, PRIMARY KEY  (`urk`,`localdomain`));
#CREATE TABLE `subjects` (  `urk` bigint(11) NOT NULL auto_increment,  `subject` varchar(255) default '', `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP, `delivered` int(1) default 0, PRIMARY KEY  (`urk`,`subject`));
#CREATE TABLE `dailyalerted` (  `urk` bigint(11) NOT NULL auto_increment, `userUrk` int(6) default '0', `senderEmail` varchar(100) NOT NULL,  `recipientEmail` varchar(100), `subject` varchar(255) default '', `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP, `da_reason` varchar(50) default '', PRIMARY KEY  (`urk`));
#CREATE TABLE `history` (  `urk` bigint(11) NOT NULL auto_increment,  `userUrk` int(6) default '0',  `msgID` bigint(11) default '0',  `senderEmail` varchar(100) NOT NULL,  `subject` varchar(255) default '',  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,  `action` varchar(100) default '',  PRIMARY KEY  (`urk`,`msgID`),  KEY `userUrk_index` (`userUrk`)) ENGINE=MyISAM DEFAULT CHARSET=latin1;
#CREATE TABLE `history_archive` (  `urk` bigint(11) NOT NULL auto_increment,  `userUrk` int(6) default '0',  `msgID` bigint(11) default '0',  `senderEmail` varchar(100) NOT NULL,  `subject` varchar(255) default '',  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,  `action` varchar(100) default '',  PRIMARY KEY  (`urk`,`msgID`),  KEY `userUrk_index` (`userUrk`)) ENGINE=MyISAM DEFAULT CHARSET=latin1;
#CREATE TABLE `whiteips` (urk bigint(11) auto_increment,  `userUrk` bigint(11) default '0', `ip` varchar(15) NOT NULL,  `three_octets` varchar(11) not NULL,  `two_octets` varchar(7) not NULL, `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP, PRIMARY KEY  (`urk`,`ip`)) ENGINE=MyISAM DEFAULT CHARSET=latin1;
#CREATE TABLE `smtpips` (`urk` bigint(11) NOT NULL auto_increment,  `userUrk` bigint(11) default '0',  `ip` varchar(15) NOT NULL,  `three_octets` varchar(11) NOT NULL,  `two_octets` varchar(7) NOT NULL,  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,  PRIMARY KEY  (`urk`,`ip`)) ENGINE=MyISAM AUTO_INCREMENT=5 DEFAULT CHARSET=latin1

#insert into `whitelist` (senderEmail,ip,three_octets,two_octets) values ('avs@webgenie.com','124.178.247.177','124.178.247','124.178');
#Load data infile 'filename' into table tbl_name;
#alter table quarantine add column recipEmail varchar(100) after column senderEmail;
#alter table quarantine change recipEmail recipientEmail varchar(100);
#Allow incoming from 72.3.141.203, 124.178.247.177, 203.97.0.0/8, 203.97.50.113, 203.167.218.26, 221.133.204.174

#CREATE TABLE `quarantine` (  `urk` bigint(11) NOT NULL auto_increment,  `Message_ID` varchar(255) default NULL,  `senderEmail` varchar(100) NOT NULL,  `recipientEmail` varchar(100) default NULL,  `subject` varchar(100) default 'No Subject',  `quarantinedMail` varchar(255) NOT NULL,  `clean_email` varchar(255) default '',  `Alt_Clean_email` varchar(100) NOT NULL default '',  `notified` int(1) default '0',  `delivered` int(1) default '0',  `sascore` varchar(5) default NULL,  `ip` varchar(15) default NULL,  `created_date` timestamp NOT NULL default CURRENT_TIMESTAMP,  `expiry_date` datetime default NULL,  `challenge` int(1) default '1',  `alert` int(1) default '1',  `accept_method` char(1) default '',  `userUrk` bigint(11) default '0',  `hashcode` char(40) default '',  `cr_sent` int(1) default '0',  `alrt_sent` int(1) default '0',  `dalrt_sent` int(1) default '0',  `threelines` text,  `lmode` int(1) default '0',  `sent_to_clean` int(1) default '0',  PRIMARY KEY  (`urk`,`senderEmail`,`quarantinedMail`)) ENGINE=MyISAM AUTO_INCREMENT=99999939837 DEFAULT CHARSET=latin1;


