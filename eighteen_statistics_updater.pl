#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_statistics_updater.pl
# Created on 29 June, 2009
# Last modified on: 29 June, 2009
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------
#Purpose: Updatee the `statistics` every midnight
#--------------------------------------
require "./eighteen_common.pl";
use DBI;
#-------------------------------------------------------------------------------
# Main body of the script
sub do_main
{
	$onceonly = $ARGV[0];
	$thisCycle = 0;
	&ConnectToDBase;
	$query = "select max(day) from `statistics`";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	$today = $results[0]+1;
	$query = "update `statistics` set day=$today where day=0";
	&execute_query($query);
	$query = "select urk from `users` where cancelled=0 and expiry_date > now()";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	my $len = $#results;
	for (my $j=0; $j <= $len; $j++)
	{
		$urk = $results[$j];
		$query = "insert into `statistics` (userUrk) values ($urk)";
		&execute_query($query);
	}
	$dbh->disconnect;
}
$|=1;
&do_main;

