#!/usr/local/bin/perl
# Track when a sent mail is opened by the recipient
# Created on 11/06/2020
# Modified on: 11/06/2020
# This is run as a cron job to check that a mail sento external address has
# been opened.
#------------------------------------------------------------------------------

require "/var/www/vhosts/webgenie.com/cgi-bin/debug.pl";

sub ReadTheAccessLog
{
	open (INP, "<$accesslog");
	@filecontent = <INP>;
	close(INP);
	$len = $#filecontent;
}

sub FindTheSentLine
{
}

sub do_main
{	
	&ReadTheAccessLog;
	&FindTheSentLine;
	&CheckMailOpened;
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
#CREATE TABLE `mails` (`id` int(4) NOT NULL AUTO_INCREMENT,  `user_id` varchar(30) NOT NULL DEFAULT '', `recipient` varchar(50) NOT NULL DEFAULT '', `sent_time` varchar(30) NOT NULL DEFAULT '', `opened_time` varchar(30) NOT NULL DEFAULT '',  `ip` varchar(15) NOT NULL DEFAULT '', `status` int(1) DEFAULT '1',  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,  PRIMARY KEY (`id`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

