#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_check_deliver_hold.pl
# Created on 16 June, 2009
# Last modified on: 21 June, 2009
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------

require "/usr/local/bin/SecureMyEmail/Eighteen/eighteen_common.pl";
use UTF8;
my $convertor = UTF8->new();
sub do_main
{
	$subject = "=?GB2312?B?uaSzp82zs++/2NbGzOXPtbTy1Ow=?=";
	$subject = "You've received a greeting ecard";
#print "1. $subject\n";
	$subject = $convertor->smart_convert($subject,"", $subject.$subject);
&debug ( "2. $subject");
}
$|=1;
&do_main;

