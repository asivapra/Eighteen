#!/usr/local/bin/perl
#
# wsp_reference_transaction.pl - Created on June 22, 2009 - AV Sivaprasad
# Modified on June 22, 2009
# Copyright, 1997-2009 WebGenie Software. All rights reserved.
# Order: http://www.webgenie.com/Order/
# Tech Support: http://www.webgenie.com/support
#--------------------------
require "/usr/local/bin/SecureMyEmail/Eighteen/eighteen_common.pl";

#use Socket;
use DBI;
use LWP;
use LWP::UserAgent;
use Lite;
use PayflowPro qw(pfpro pftestmode pfdebug);
#use Crypt::SSLeay;
$ua = LWP::UserAgent->new;
$ua->agent("MyApp/0.1 ");
# Main body of the script
sub MakeQueryStringReferenceTransaction
{
	my $data = {
	  TRXTYPE=>'S',			# Sale
	  TENDER=>'C',			# credit card
	  PARTNER=>$partner,
	  USER=>$user,
	  VENDOR=>$vendorID,
	  PWD=>$vendorPassword,
	  AMT=> $totPayable,
	  ORIGID=>$paypal_PNREF,
	  INVNUM => $orderNo,
	};
	return $data;
}
sub PayFlowProReferenceTransaction
{
	# This module is used only for testing. Not part of the live CGI.
	#Usage: http://www.speedupmywebsite.com/cgi-bin/wsp_signup.cgi?PayFlowProReferenceTransaction
	pftestmode(1); # 1 = test mode; 0 = live mode
#	$host = "payflowpro.paypal.com";  # v4; Live = payflowpro.paypal.com
	$host = "pilot-payflowpro.paypal.com";  # v4; Live = payflowpro.paypal.com
	$port = 443;
	$vendorID = 'webgenie';
	$user = 'webgenie'; # 
	$vendorPassword = "4webgenie"; 
	$partner = "PayPal";
#$totPayable = "1.00";  # debug
	$data = &MakeQueryStringReferenceTransaction;	
	$res = pfpro($data);
print "--Reference Transaction: Data Sent---------------------\n";
	while (my ($k,$v) = each %{$data}) 
	{
		if ($k eq "PWD") { $v = "******"; }
print" $k => $v\n";
	}
print "--Reference Transaction: Data received---------------------\n";
	while (my ($k,$v) = each %{$res}) 
	{
print" $k => $v\n";
	}
}
sub ExtendSubscription
{
	$ndays = 31;
	$query = "select expiry_date from `admin_users` where urk=$urk";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	$currentexpiry_date = $results[0];

#&debug ("currentexpiry_date = $currentexpiry_date");
	if ($currentexpiry_date)
	{
		$query = "select DATE_ADD(concat(date_format('$currentexpiry_date','%Y-%m-%d'),' 23:59:59'), INTERVAL $ndays DAY)";
	}
	else
	{
		$query = "select DATE_ADD(concat(date_format(now(),'%Y-%m-%d'),' 23:59:59'), INTERVAL $ndays DAY)";
	}
	&execute_query($query);
#&debug ("query = $query");
	@results = &Fetchrow_array(1);
	$expiry_date = $results[0];

	# Set the next reminder date
	$query = "select DATE_ADD(concat(date_format('$expiry_date','%Y-%m-%d'),' 23:59:59'), INTERVAL -1 DAY)";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	$next_billing_date = $results[0];

	$query = "update `admin_users` set expiry_date='$expiry_date', next_billing_date='$next_billing_date',paypal_PNREF='$paypal_PNREF',InvNum='$orderNo' where urk=$urk";
	&execute_query($query);
#&debug ("query = $query");

	# Extend in `users` for active monitoring. Any a/c expired for > 1 month must be removed by setting status=0 in `users_tobeadded` 
	$query = "update `users` set expiry_date='$expiry_date'  where User_email='$User_email'";
	&execute_query($query);
#&debug ("query = $query");
}
sub TransactionDeclined
{
	$Subject ="SecureMyEmail: Transaction Declined";
	$firstLine = "We attempted to extend your subscription to the SpeedupMyWebSite memmbership
	
	However, your credit card was declined
	
	Please login to your account using the details given below and extend the subscription manually.
	";
	$Instructions = "Hi $User_name,
	
$firstLine

To login to your member page, 
please go to $adminURL
";
	$Instructions .= "
Username: $User_email
Password: $Password
";

$Instructions .= "
For technical support, please go to: $supportURL

--
Wilbur Smith

Technical Support, SecureMyEmail.Com.
";
&SendMail;
}

sub SendNotification
{
	$Subject ="SecureMyEmail: Transaction Processed";
	$firstLine = "Thank you for your subscription to the service.

We have charged \$$totPayable and extended your subscription until $expiry_date

To make inquiry about this charge, please quote the following:

1. Member ID: $urk

2. Transaction ID: $orderNo

	";
	$Instructions = "Hi $User_name,
	
$firstLine

To login to your admin page, 
please go to $adminURL
";
	$Instructions .= "
Username: $User_email
Password: $Password
";

$Instructions .= "
For technical support, please go to: $supportURL

--

Sales and Accounting, SpeedupMyWebSite.Com.
";
&SendMail;
}

sub SendMail
{
   ### Create a new multipart message:
   $msg = MIME::Lite->new( 
             From    =>"$Owner_name <$Owner_email>",
             To      =>"$User_name <$User_email>",
             Cc      =>"$Copy_email",
             Bcc      =>"$Bcc_email",
             Subject =>"$Subject",
             Type    =>'multipart/mixed'
             );
#   $zipfile = "$OwnerTemplatesDir/secure_form.zip";
#   $zipfile =~ s/\@/\_/gi;
#&debug ("zipfile = $zipfile");
   ### Add parts (each "attach" has same arguments as "new"):
   $msg->attach(Type     =>'TEXT',   
             Data     =>"$Instructions"
             );  
   ### Format as a string:
   ### Print to a filehandle (say, a "sendmail" stream):
   open MAIL, "| $mail -t";
   $msg->print(\*MAIL);
   close MAIL;
#   unlink ("$tmpDir/$filename");
}
sub do_main
{
	open (OUT, ">>eighteen_reference_transaction.log");
	&ConnectToDBase;
	$query = "select urk,User_email,User_name,Password,paypal_PNREF,unit_price from `admin_users` where next_billing_date < now() and recurring_billing=1 and cancelled=0";
	&execute_query($query);
	my @results = &Fetchrow_array(6);
	my $len = $#results;
print "$query\n";	
print "$len\n";	
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
print "$ProcessTime\n";	
print OUT "$ProcessTime\n";	
	for (my $j=0; $j <= $len; $j++)
	{
		$urk = $results[$j++];
		$User_email = $results[$j++];
		$User_name = $results[$j++];
		$Password = $results[$j++];
		$paypal_PNREF = $results[$j++];
		$totPayable = $results[$j];
		&MakeOrderNumber;
print "urk = $urk; User_email=$User_email; totPayable=$totPayable; paypal_PNREF = $paypal_PNREF\n";	
print OUT "urk = $urk; User_email=$User_email; totPayable=$totPayable; paypal_PNREF = $paypal_PNREF\n";	
		&PayFlowProReferenceTransaction;
		while (my ($k,$v) = each %{$res}) 
		{
			if ($k eq "RESPMSG")
			{
				$RESPMSG = $v;
				if ($RESPMSG ne "Approved")
				{
print OUT "urk = $urk; User_email=$User_email; totPayable=$totPayable; paypal_PNREF = $paypal_PNREF; **** Payment Declined ****\n";	
					&TransactionDeclined;  # Must sent a mail to user and admin
					exit;
				}
			}
			if ($k eq "PNREF")
			{
			  $paypal_PNREF = $v;
			}
			if ($k eq "PPREF")
			{
			  $paypal_PPREF = $v;
			}
			if ($k eq "AUTHCODE")
			{
			  $paypal_AUTHCODE = $v;
			}
			if ($k eq "CORRELATIONID")
			{
			  $paypal_CORRELATIONID = $v;
			}
		}
		&ExtendSubscription; # If payment is approved
		&SendNotification; # Send a mail to the customer
print OUT "urk = $urk; User_email=$User_email; totPayable=$totPayable; paypal_PNREF = $paypal_PNREF; new expiry_date=$expiry_date\n";	
	}
	close (OUT);
	$dbh->disconnect;
}
$adminURL = "http://www.webgenie.com/Software/SecureMyEmail/admin_login.html";
$|=1;
&do_main;
sleep(1);

