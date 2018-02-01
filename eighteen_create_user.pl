#!/usr/local/bin/perl
#/usr/local/bin/SecureMyEmail/Eighteen/eighteen_create_user.pl
# Created on 28 June, 2009
# Last modified on: 13 Jan, 2010
# Copyright 2009 - Arapaut V Sivaprasad and WebGenie Software Pty Ltd.
#--------------------------------------

#Purpose: Create a qmail account for new user
#This runs as a daemon with 1sec sleep.
#--------------------------------------

require "./eighteen_common.pl";
use DBI;
sub GetUsersList
{
	my $status = $_[0];
	@users = ();
	$query = "select User_email,Raw_email,Clean_email,Alt_Clean_email,IGM_domain,Password,hashcode from `users_tobeadded` where status=$status";
	&execute_query($query);
	@results = &Fetchrow_array(7);
	my $len = $#results;
#print "query = $query\n";	
	for (my $j=0; $j <= $len; $j++)
	{
		$User_email = $results[$j++];
		$Raw_email = $results[$j++];
		$Clean_email = $results[$j++];
		$Alt_Clean_email = $results[$j++];
		$IGM_domain = $results[$j++];
		$Password = $results[$j++];
		$hashcode = $results[$j];
		$user = "$User_email,$Raw_email,$Clean_email,$Alt_Clean_email,$IGM_domain,$Password,$hashcode";
		push (@users, $user);
	}
#print "Users = @users\n";
}

sub CheckIfAlreadyAdded
{
	$query = "select count(*) from `users` where Raw_email='$Raw_email' and status = '1'";
	&execute_query($query);
#print "$query\n";
	my @results = &Fetchrow_array(1);
	return $results[0];
}
sub CheckIfAlreadyAddedInAssign
{
	open (INP, "<$qmailUsersDir/assign");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	for (my $j=0; $j <= $len; $j++)
	{
#print "$filecontent[$j]";
		if ($filecontent[$j] =~ /$assign_line/i) { return 1; }
	}
	return 0;
}
sub DeleteQmailUser
{
	open (INP, "<$qmailUsersDir/assign");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	for (my $j=0; $j <= $len; $j++)
	{
		if ($filecontent[$j] =~ /$assign_line/i) 
		{ 
#print "$filecontent[$j]\n";
			$filecontent[$j] = "";
			$deleted = 1; 
		}
	}
#print "deleted = $deleted\n";
	if ($deleted)
	{
#		$filecontent[$len] = "$assign_line\n\.";
		open (OUT, ">$qmailUsersDir/assign");
		print OUT @filecontent;
		close (OUT);
		#Delete the dirs
		chdir "$qmailDir/$IGM_domain";
		`rm -r $user`;
		`/var/qmail/bin/qmail-newu`; # create the ../users/cdb from ../users/assign
		`/etc/init.d/qmail restart`; # restart qmail
		print "Deleted: $OrigRaw_email => $Raw_email => $Clean_email\n";	
	}
	else
	{
#print "Not found: $assign_line\n";		
	}
	#Delete the dirs
#	chdir "$qmailDir/$IGM_domain";
#	`rm -r $user`;
#	`/var/qmail/bin/qmail-newu`; # create the ../users/cdb from ../users/assign
#	`/etc/init.d/qmail restart`; # restart qmail
}
sub CreateQmailUser
{
	open (INP, "<$qmailUsersDir/assign");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
#print "len: $len\n";		
	
	# Add the line at the end, making sure that the last line is a period (.)
	$filecontent[$len] = "$assign_line\n\.";
	open (OUT, ">$qmailUsersDir/assign");
	print OUT @filecontent;
	close (OUT);

#print "2. len: $len\n";		
	#Create the dirs
	chdir "$qmailDir/$IGM_domain";
	`mkdir -p $user/Maildir`;
	`mkdir $user/\@attachments`;
	`mkdir $user/Maildir/new`;
	`mkdir $user/Maildir/cur`;
	`mkdir $user/Maildir/tmp`;
#print "3. len: $len\n";		
	open (OUT, ">$user/.qmail");
	print OUT "\| true\n";
	print OUT "\| /usr/bin/deliverquota ./Maildir\n";
	close (OUT);

#print "4. len: $len\n";		
	chdir "$qmailDir/$IGM_domain";
	`chown -R popuser:popuser $user`;
	`chmod -R 700 $user`;
	`chmod 600 $user/.qmail`;  # do not set the x bit. It gives an error
	`/var/qmail/bin/qmail-newu`; # create the ../users/cdb from ../users/assign
#print "5. len: $len\n";		
	`/etc/init.d/qmail restart`; # restart qmail
#print "6. len: $len\n";		
	print "Added: $OrigRaw_email => $Raw_email => $Clean_email\n";	
}
#-------------------------------------------------------------------------------
# Main body of the script
sub MakeMailMessage
{
	$textmailbody = "
Thank you for evaluating $Brand_name. 

ACCOUNT DETAILS:

Your email address to be protected : $OrigRaw_email 
Incoming mail to be redirected to  : $Raw_email
Clean mails to be downloaded from  : $Clean_email

_________________________________________________________________
INSTRUCTIONS:
(to test and activate the system)

1. Send a mail to $Raw_email 

2. Check that it arrives at : $Clean_email 

3. Set the auto-forwarding from: 
    $OrigRaw_email to $Raw_email 

That is all there to it! You will thereafter get only
spam-free mails delivered to $Clean_email

_________________________________________________________________
Your account will be fully functional for 7 days.

You can manage the settings, add more addresses, etc. 
at: $memberAdminUrl
Username: $User_email
Password: $Password

In order to continue using the system beyond 7 days,
you must subscribe to a low monthly fee.

Please go here to subscribe: 
$subscribeUrl
_________________________________________________________________

--
Support Team,
$tagline1 


	";
	$htmlmailbody = "
<html>
<head>
<style type=\"text/css\">
.style1 {
	background-color: #E3E1C1;
}
.style2 {
	font-size: small;
	text-align: center;
	background-color: #FFFFFF;
}
.style3 {
	font-family: Verdana;
	font-size: small;
	background-color: #FFFFFF;
}
.style4 {
	font-family: Verdana;
	font-size: small;
}
.style5 {
	font-family: Verdana;
	font-size: small;
	font-weight: bold;
	text-align: center;
}
.style6 {
	font-family: Verdana;
	font-size: x-small;
	font-weight: bold;
	background-color: #FFFFFF;
}
.style7 {
	font-family: Verdana;
	font-size: small;
	font-weight: bold;
	background-color: #FFFFFF;
}
.style8 {
	font-family: Verdana;
	font-size: x-small;
}
.style9 {
	font-size: x-small;
	font-weight: bold;
	background-color: #FFFFFF;
}
.style11 {
	font-family: Verdana;
	font-size: x-small;
	font-weight: bold;
}
.style12 {
	font-family: Verdana;
	font-size: xx-small;
	font-weight: bold;
	background-color: #FFFFFF;
}
</style>
</head>
<body>
<table cellspacing=\"1\" class=\"style1\" style=\"width: 578px\">
	<tr>
		<td class=\"style2\" colspan=\"2\"><span class=\"style5\">Thank you for evaluating IGMail. Your account details 
		are given below</span><b><br class=\"style4\" />
		</b></td>
	</tr>
	<tr>
		<td class=\"style6\" style=\"width: 412px\">Incoming address</td>
		<td class=\"style12\">$OrigRaw_email</td>
	</tr>
	<tr>
		<td class=\"style6\" style=\"width: 412px\">Spam redirected to address</td>
		<td class=\"style12\">$Raw_email</td>
	</tr>
	<tr>
		<td class=\"style6\" style=\"width: 412px\">Clean mails go to address</td>
		<td class=\"style12\">$Clean_email</td>
	</tr>
	<tr>
		<td class=\"style7\" style=\"width: 412px\">Instructions to test the system</td>
		<td class=\"style3\">&nbsp;</td>
	</tr>
	<tr>
		<td class=\"style6\" style=\"width: 412px\">1. Send a mail to $Raw_email</td>
		<td class=\"style3\">&nbsp;</td>
	</tr>
	<tr>
		<td class=\"style9\" style=\"width: 412px\"><span class=\"style11\">2. Check 
		that it arrives at:</span><b><br class=\"style8\" />
		</b><span class=\"style11\">&nbsp;&nbsp;&nbsp; $Clean_email</span></td>
		<td class=\"style3\">&nbsp;</td>
	</tr>
	<tr>
		<td class=\"style9\" style=\"width: 412px\"><span class=\"style11\">3. Set the auto-forwarding from:
		</span><b><br class=\"style8\" />
		</b><span class=\"style11\">&nbsp;&nbsp;&nbsp; $OrigRaw_email to 
		$Raw_email</span></td>
		<td class=\"style3\">&nbsp;</td>
	</tr>
</table>
</body>
</html>
";
}
sub SendTextOnlyMailViaSendmail
{
	$Owner_name = $_[0];
	$Owner_email = $_[1];
	$User_name = $_[2];
	$User_email = $_[3];
	$Copy_email = $_[4];
	$Bcc_email = $_[5];
	$Subject = $_[6];
	$textmailbody = $_[7];
	
	$tfilecontent =  "From: $Owner_name <$Owner_email>\n";
	$tfilecontent .= "To: $User_name <$User_email>\n";
	$tfilecontent .= "Subject: $Subject\n";
	$tfilecontent .= "\n";
	$tfilecontent .= $textmailbody;
	my $filename = "$tmpDir/sme_$User_email.tmp";
	open (OUT, ">$filename");
	print OUT $tfilecontent;
	close (OUT);
	
	`$mailprogram -f $Owner_email $User_email < $filename`;
	$mailerror = $?;
	unlink ($filename);
#&debug ("mailerror = $mailerror;	`$mailprogram -f $Owner_email $User_email < $filename`;");
}
sub SendTextPlusHtmlMailViaSendmail
{
	$Owner_name = $_[0];
	$Owner_email = $_[1];
	$User_name = $_[2];
	$User_email = $_[3];
	$Copy_email = $_[4];
	$Bcc_email = $_[5];
	$Subject = $_[6];
	$textmailbody = $_[7];
	$htmlmailbody = $_[8];
	
     $tfilecontent =  "MIME-Version: 1.0\n";                                 # Inactivate this line to send text-only msg
	 $tfilecontent .=  "From: $Owner_name <$Owner_email>\n";
	 $tfilecontent .= "To: $User_name <$User_email>\n";
     $tfilecontent .= "Subject: $Subject\n";
     $tfilecontent .= "Content-Type: multipart/alternative; boundary=\"-----------The Following is in HTML Format\"\n\n\n";

     $tfilecontent .= "-------------The Following is in HTML Format\n";
     $tfilecontent .= "Content-Type: text/plain;\n\tcharset=\"iso-8859-1\"\n";
	 $tfilecontent .= "\n";
	 $tfilecontent .= $textmailbody;
	 $tfilecontent .= "\n";
     $tfilecontent .= "-------------The Following is in HTML Format\n";
     $tfilecontent .= "Content-Type: text/html; charset=us-ascii\n";
     $tfilecontent .= "Content-Transfer-Encoding: 7bit\n\n";
     $tfilecontent .= "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">\n";
     $tfilecontent .= "$htmlmailbody";
	 $tfilecontent .= "\n";
     $tfilecontent .= "-------------The Following is in HTML Format--\n";
	 my $filename = "$tmpDir/sme_$$.tmp";
	 open (OUT, ">$filename");
	 print OUT $tfilecontent;
	 close (OUT);

	`$mailprogram -f $Owner_email $User_email < $filename`;
	 $mailerror = $?;
&debug ("mailerror = $mailerror;	`$mailprogram -f $Owner_email $User_email < $filename`;");
}
sub AddAdminUser
{
	my $status = $_[0];
	$query = "select urk,User_email from `admin_users` where User_email = '$User_email'";
	&execute_query($query);
	my @results = &Fetchrow_array(2);
	if ($results[0])
	{
#		$urk = $results[0];
#		$User_email = $results[1];
#		$query = "update `admin_users` set User_name='$User_name',Password='$Password',n_boxes=5 where urk = $urk";
#		&execute_query($query);
	}
	else
	{
		$query = "insert into `admin_users` (User_email,User_name,IGM_domain,Reseller,Password,n_boxes,status,hashcode) values('$User_email','$User_name','$IGM_domain','$Reseller','$Password',5,$status,'$hashcode')";
		&execute_query($query);
	}
}
sub CreatePsaUser
{
	my $status = $_[1];

	#Add the lines to the 'DB:psa' so that Plesk will manage it.
	$query = "use psa";
	&execute_query($query);
	my $mail_name = $Raw_email;
	$mail_name =~ s/\@$IGM_domain//gi;
	$query = "select id from `mail` where mail_name = '$mail_name'";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	if ($results[0])
	{
#		$urk = $results[0];
#		$User_email = $results[1];
#		$query = "update `admin_users` set User_name='$User_name',Password='$Password',n_boxes=5 where urk = $urk";
#		&execute_query($query);
	}
	else
	{
		# Insert mail_name with default values
		$query = "insert into `mail` (mail_name,postbox,dom_id) values('$mail_name','true','1')";
		&execute_query($query);
		# Now update the perm_id and account_id
		$query = "update `mail` set perm_id=id, account_id=id+1 where mail_name='$mail_name'";
		&execute_query($query);
	}
	
	# Change the DB back to exonmail
	$query = "use securemyemail";
	&execute_query($query);
}
sub DeleteAUser
{
	&GetUsersList(0); # Delete the user if status=0
	foreach $user (@users)
	{
		my @fields = split (/\,/, $user);
		$User_email = $fields[0];
		$Raw_email = $fields[1];
			$OrigRaw_email = $Raw_email;
		$Clean_email = $fields[2];
		$Alt_Clean_email = $fields[3];
		$IGM_domain = $fields[4];
		$Password = $fields[5];
		
		# Convert the incoming mail adddress to IGM_domain
		$Raw_email =~ s/\@/\_/gi;
		$Raw_email .= "\@$IGM_domain";
#			my $alreadyAdded = &CheckIfAlreadyAdded;
#			if ($alreadyAdded)
#			{
			$query = "delete from `users` where (User_email='$User_email' and Raw_email='$OrigRaw_email')";
			&execute_query($query);

#Live
#				$query = "update  `users_tobeadded` set status=-2 where (User_email='$User_email' and Raw_email='$OrigRaw_email')";
#debug
			$query = "delete from  `users_tobeadded` where (User_email='$User_email' and Raw_email='$OrigRaw_email')";
			&execute_query($query);

			$user = $OrigRaw_email;
			$user =~ s/\@/\_/gi;
			$userDomain = $IGM_domain;
			$userDomain =~ s/\./\-/gi; # To be added in /users/assign
			$userDomainID = 1; # This is the domain ID for 'exonmail.com'. Check that it is not changed
			$assign_line = "=$userDomainID-$user\:popuser\:110\:31\:/var/qmail/mailnames/$IGM_domain/$user\:\:\:";
#print "assign_line = $assign_line\n";
#exit;
			my $alreadyAdded = &CheckIfAlreadyAddedInAssign;
			if ($alreadyAdded)
			{
				&DeleteQmailUser;
			}
			else
			{
			}
#			}
	}
}
sub AddAUser
{
	&GetUsersList (-1); # add the user if status = -1. The status = -1 means it has been confirmed by the customer.
	foreach $user (@users)
	{
		my @fields = split (/\,/, $user);
		$User_email = $fields[0];
		$Raw_email = $fields[1];
			$OrigRaw_email = $Raw_email;
		$Clean_email = $fields[2];
		$Alt_Clean_email = $fields[3];
		$IGM_domain = $fields[4];
		$Password = $fields[5];
		$hashcode = $fields[6];
		&AddAdminUser(0);			
		# Convert the incoming mail adddress to IGM_domain
		$Raw_email =~ s/\@/\_/gi;
		$Raw_email .= "\@$IGM_domain";
		my $alreadyAdded = &CheckIfAlreadyAdded;
#			if (!$alreadyAdded)
#			{
#print "2. Raw_email = $Raw_email\n";
			if (!$alreadyAdded) # This is already added if using the admin interface
			{
				$query = "select DATE_ADD(concat(date_format(now(),'%Y-%m-%d'),' 23:59:59'), INTERVAL $n_evaluationDays DAY)";
				&execute_query($query);
				@results = &Fetchrow_array(1);
				$expiry_date = $results[0];

				$query = "select DATE_ADD(concat(date_format(now(),'%Y-%m-%d'),' 23:59:59'), INTERVAL $n_learnModeDays DAY)";
				&execute_query($query);
				@results = &Fetchrow_array(1);
				$learnmode_end_date = $results[0];
#					$query = "insert into `users` (User_email,Raw_email,Clean_email,Alt_Clean_email,Password,learnmode_end_date,expiry_date) values ('$User_email','$Raw_email','$Clean_email','$Alt_Clean_email','$Password','$learnmode_end_date','$expiry_date')";
				$query = "update `users` set status='1' where Raw_email='$Raw_email'";
				&execute_query($query);
#print "Added Raw_email = $Raw_email\n";
#print "query = $query\n";
			}

#				$query = "update  `users_tobeadded` set status=2,expiry_date='$expiry_date' where (User_email='$User_email' and Raw_email='$Raw_email')"; # Set as added
			$query = "update  `users_tobeadded` set status=2,expiry_date='$expiry_date' where hashcode='$hashcode'"; # Set as added
#print "query = $query\n";
			&execute_query($query);
#=wggmail-com-avs:popuser:110:31:/var/qmail/mailnames/wggmail.com/avs:::
			$user = $OrigRaw_email;
			$user =~ s/\@/\_/gi;
			$userDomain = $IGM_domain;
			$userDomain =~ s/\./\-/gi; # To be added in /users/assign
			$userDomainID = 1; # This is the domain ID for 'exonmail.com'. Check that it is not changed
#print "$user\n";
#$user = 'avs';
			# The assign_line requires the userDomainID instead of userDomain to work.
			$assign_line = "=$userDomainID-$user\:popuser\:110\:31\:/var/qmail/mailnames/$IGM_domain/$user\:\:\:";
#				$assign_line = "=$userDomain-$user\:popuser\:110\:31\:/var/qmail/mailnames/$IGM_domain/$user\:\:\:";
#print "Adding: $assign_line\n";
			my $alreadyAdded = &CheckIfAlreadyAddedInAssign;
			if (!$alreadyAdded)
			{
#print "alreadyAdded = $alreadyAdded. Creating the user\n";
				&CreateQmailUser;
#print "Created QmailUser\n";
				&CreatePsaUser;					
#print "MakeMailMessage\n";
				&MakeMailMessage;
#print "MakeMailMessage - Return\n";
				$Subject = "SME: User account has been created for $OrigRaw_email";
				$User_email = $User_email; # To the admin
				&SendTextOnlyMailViaSendmail ($Owner_name,$Owner_email,$User_name,$User_email,$Copy_email,$Bcc_email,$Subject,$textmailbody,$htmlmailbody);
				$User_email = $OrigRaw_email; # To the forwarded address
				&SendTextOnlyMailViaSendmail ($Owner_name,$Owner_email,$User_name,$User_email,$Copy_email,$Bcc_email,$Subject,$textmailbody,$htmlmailbody);
				$User_email = $Raw_email; # To the received address
				&SendTextOnlyMailViaSendmail ($Owner_name,$Owner_email,$User_name,$User_email,$Copy_email,$Bcc_email,$Subject,$textmailbody,$htmlmailbody);
				$User_email = $Clean_email; # To the clean address
				&SendTextOnlyMailViaSendmail ($Owner_name,$Owner_email,$User_name,$User_email,$Copy_email,$Bcc_email,$Subject,$textmailbody,$htmlmailbody);
			}
			else
			{
#print "alreadyAdded = $alreadyAdded. Not adding the user\n";
			}
#			}
	}
}
sub do_main
{
#&debugEnv;
	$monitorcycle = 0;  # This will update `monitor` at start
	&ConnectToDBase;
	while (1)
	{
		$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
print "$ProcessTime\n";		
		&AddAUser; # This will check if there is any entry in `users_tobeadded` with status = -1 and add them
		&DeleteAUser; # This will check if there is any entry in `users_tobeadded` with status = 0 and delete them
		&UpdateMonitorTable("cu");
		sleep (2);
	}
	$dbh->disconnect;
}
$|=1;
&do_main;

