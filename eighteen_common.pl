require "./diff_dirs.pl";
use Mail::SPF;
use Net::Whois::IP qw(whoisip_query);
use IP::Country::Fast;
use Geo::IP;
use Socket;
sub reformat
{
  local($tmp) = $_[0] ;
  $tmp =~ s/\+/ /g ;
  while ($tmp =~ /%([0-9A-Fa-f][0-9A-Fa-f])/)
  {
   $num = $1;
   $dec = hex($num);
   $chr = pack("c",$dec);
   $chr =~ s/&/^/g;  # Replace if it is the & char.
   $tmp =~ s/%$num/$chr/g;
  }
  return($tmp);
}
sub debug
{
  $line = $_[0];
  $exit = $_[1];
  if (!$headerAdded) { print "Content-type: text/html\n\n"; $headerAdded = 1; }
  print "$line<br>\n";
  if ($exit) { exit; }
}
sub TimeLapse
{
	my $N = $_[0];
	$ct1 = time();
	$et = $ct1 - $ct0;
	$ct0 = $ct1;
	return $et;
}
sub Monify
{
   $in = $_[0];
   if (!$in) { $in = 0.00; } 
   if ($in !~ /\d/) { return $in; }      # It is a non-digit (e.g. UPS)
   if ($in =~ /\.00$/) { return $in; }      # It already has zero cents
   if ($in !~ /\./) { return "$in.00"; }  # Add two zeros for cents

   # Truncate the cents to two digits; Must round up if necessary
   else
   {
      @in = split (/\./, "$in");
      $dollars = @in[0];
      $cents = ".@in[1]" * 100;
      @cents = split (/\./, "$cents");
      $cents = @cents[0];

      # see if the next digit is >= 5 to round up
      $nextDigit = ".@cents[1]" * 10;
      @nextDigit = split (/\./, "$nextDigit");
      $nextDigit = @nextDigit[0];
      if ($nextDigit >= 5) { $cents++; }
      if ($cents == 100) { $cents = "00"; $dollars++; }
      if ($cents <= 9) { $cents = "0$cents"; }

      return "$dollars.$cents";
   }
}
sub ConnectToDBase
{
   $driver = "mysql";
#   $database = "exonmail"; on EM server
#   $database = "securemyemail"; # on WG server
   $hostname = "localhost";
#   $dbuser="admin";
#   $dbpassword="ca8d2d65";
   $dsn = "DBI:$driver:database=$database;host=$hostname";
   $input;
   $dbh = DBI->connect($dsn, $dbuser, $dbpassword);
   $drh = DBI->install_driver("mysql");
}

sub execute_query
{
#return;	
#&debug ("query = $query");	
	$sth=$dbh->prepare($query);
	$rv = $sth->execute or die "can't execute the query: $sth->errstr";
#&RecordLogs("Err = $sth->errstr\n");	
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
sub debugEnv
{
   print "Content-type:text/html\n\n";
   print "<Pre>\n";
   foreach $item (%ENV)
   {
      print "$item\n";
   }
   exit;
}
#-----Notifications.pl
sub WSCPReplaceTags
{
      my ($line) = $_[0];
      if ($line !~ /\$/) { return $line; }
      $line =~ s/\n//gi;
      $line .= "\n";
      $line =~ s/\$ProcessTime/$ProcessTime/i;
      $line =~ s/\$hashcode/$hashcode/i;
      $line =~ s/\$Alert_email/$Alert_email/i;
      $line =~ s/\$Raw_email/$Alert_email/i;
      $line =~ s/\$recipientEmail/$recipientEmail/i;
      $line =~ s/\$messages/$messages/i;
      $line =~ s/\$cgiURL/$cgiURL/i;
      $line =~ s/\$urk/$urk/i;
      $line =~ s/\$acceptedMessage/$acceptedMessage/i;
      $line =~ s/\$mailheaders/$mailheaders/i;
      $line =~ s/\$subject/$subject/i;
      $line =~ s/\$senderEmail/$senderEmail/i;
	  return $line;
}
sub PutHeadersInAckMailFile
{
  local ($From_name)       = $_[0];
  local ($From_mail)       = $_[1];
  local ($To_mail)         = $_[4];
  local ($subject)         = $_[5];
	$tfilecontent = "";
	$tfilecontent .=  "From: $From_name <$From_mail>\n";
    $msgID = &GetRandomChars(40);
    $msgID = "<$msgIDprefix-" . $msgID . "\@localhost" . "." . $$ . ">";
	$tfilecontent .=  "Message-Id: $msgID\n";
	$tfilecontent .= "To: $To_mail\n";
	if (!$textMail)
	{
		$tfilecontent .=  "MIME-Version: 1.0\n";                                 # Inactivate this line to send text-only msg
		$tfilecontent .= "Subject: $Form_subject_user\n";
		$tfilecontent .= "Content-Type: multipart/alternative; boundary=\"------------The Following is in HTML Format\"\n";
	}
	else
	{
		$tfilecontent .= "Subject: $Form_subject_user\n\n";
	}
#    $tfilecontent .= "Content-Type: text/plain; charset=us-ascii\n";
#    $tfilecontent .= "\n--------------The Following is in HTML Format\n";
#	$tfilecontent .= $textmailbody;
}

sub GetRandomChars
{
	$n = $_[0];
	$alphanumeric = '1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
	@alphanumeric = split (//, $alphanumeric);
	$randomString = "";
	for (my $j=0; $j <= $n; $j++)
	{
		srand;  # Seed the random number
		$i = int (rand (62));  # Get a random start position
		$randomString .= $alphanumeric[$i];
	}
	return $randomString;
}

sub AntiVirusCheck
{
	$virus = 0;
#$pid = $$;	
#print "pid = $pid; $mailfile\n";	
#&RecordLogs("2c. In AntiVirusCheck: $pid; $mailfile\n");
#	$result = `clamscan -r $mailfile`;
	$result = `clamdscan --fdpass $mailfile`;
	@result = split (/\n/, $result);
	foreach $line (@result)
	{
		if ($line =~ /^Infected files/)
		{
#&RecordLogs("2c1. In virus = $line\n");
			my @fields = split (/: /, $line);
			$virus = $fields[1];
			if ($virus) { `rm $mailfile`; } # Delete the mail containing virus.
			last;
		}
	}
	$viruses += $virus;
#&RecordLogs("2d. In virus = $virus\n");
#	return $virus;
#exit;
}

sub SendMailViaLite
{
   ### Create a new multipart message:
   $msg = MIME::Lite->new( 
             From    =>"$Owner_name <$Owner_email>",
             To      =>"$User_name <$User_email>",
             Cc      =>"$Copy_email",
             Bcc      =>"$Bcc_email",
             Subject =>"$zipfileSubject",
             Type    =>'multipart/mixed'
             );
   ### Add parts (each "attach" has same arguments as "new"):
   $msg->attach(Type     =>'TEXT',   
             Data     =>"$Instructions"
             );  
   if (-f "$zipfile")  # Check that the file exists
   {
      $msg->attach(
                Type     =>"application/octet-stream",
                Path     =>"$zipfile",
                Filename =>"$zipfileAttachment",
                Disposition => 'attachment'
                );
   }
   ### Format as a string:
   ### Print to a filehandle (say, a "sendmail" stream):
   open MAIL, "| $mailprogram -t";
   $msg->print(\*MAIL);
   close MAIL;
}
sub AlterMessage_ID
{
	open (INP, "<$mailfile");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	my $msgIdAltered = 0;
	for ($ka=0; $ka <= $len; $ka++)
	{
		# Exit at header boundary
		if ($filecontent[$ka] eq "\n")
		{
			last;
		}
		if ($filecontent[$ka] =~ /^Message-ID:/i)
		{
			$filecontent[$ka] =~ s/^Message-ID: \</Message-ID: \<$msgIDprefix-/gi;
			$msgIdAltered = 1;
			last;
		}
	}
	if ($msgIdAltered)
	{
		open (OUT, ">$mailfile");
		print OUT @filecontent;
		close (OUT);
#	&RecordLogs("*** AlterMessage_ID: $filecontent[$ka]\n");				
	}
}
sub DeliverToCleanMailbox
{
#&RecordLogs("2a. In ForwardCleanMails\n");
	&AntiVirusCheck; # Put through CLAMAV. This comes before clean mail delivery. 
#&RecordLogs("2b. In virus2 = $virus\n");
	if ($virus)
	{
		# Discard the mail
		`rm $mailfile`; # Delete this for security
		&RecordLogs("File contains a Virus. Deleted: $virus\n");				
#print "File contains a Virus. Deleted: $virus\n";
		$Clean_email = "";  # Blank it out so that it takes the right one again
		return;
	}
	&AlterMessage_ID; # This is to alter the MsgID in the mailfile by adding $msgIDprefix
	# Send to alt email first, if set (i.e. to send to BlackBeryy)
#print "Alt_Clean_email= $Alt_Clean_email userOut=$userOut\n";
	if ($Alt_Clean_email =~ /.*\@.*\./ && $userOut !~ /$Alt_Clean_email/i) # If this is an email address
	{
		`$mailprogram -f $Raw_email $Alt_Clean_email < $mailfile`;
		$mailerror = $?;
#print "mailerror = $mailerror;	`$mailprogram $Alt_Clean_email < $mailfile`;\n";
	}
#print "$calledfrom	if ($Clean_email =~ /.*\@.*\./ && $Clean_email !~ /$Raw_email/i) # If this is an email address\n";
#&RecordLogs("2b. In ForwardCleanMails\n");
	if ($Clean_email =~ /.*\@.*\./ && $Clean_email !~ /$Raw_email/i) # If this is an email address
	{
#print "	2. 	`$mailprogram -f $Raw_email $Clean_email < $mailfile`;\n";
		`$mailprogram -f $Raw_email $Clean_email < $mailfile`;
		$mailerror = $?;
#		`rm $mailfile`;
	}
	else
	{
		$curMailDir = "$qmailDir/$domain/$userIn/Maildir/cur";
		my @fields = split (/,/, $mailfile);
		$mailsize = $fields[1];  # Take the size
		$ct = time();
		$Clean_email = "$curMailDir/$userUrk-$ct,$mailsize:2,S";
		`mv $mailfile $Clean_email`; 
	}
	&RecordLogs(">>>>>Clean mail forwarded to: $Clean_email ($senderEmail => $recipientEmail) \n");				
#print ">>>>>Clean mail forwarded to: $Clean_email >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
	$clean_forwarded++;
	my $safeSubject = $subject;
	$safeSubject =~ s/\'/\\\'/gi;
	$safeSubject =~ s/\"/\\\"/gi;
	$query = "update `subjects` set delivered=1 where subject='$safeSubject'";
	&execute_query($query);
}

sub RblCheck
{
#!/usr/bin/perl								
#- Copyright (C) 2003 Marcin Gondek <drixter@e-utp.net>
#-
#- This program is free software; you can redistribute it and/or modify
#- it under the terms of the GNU General Public License as published by
#- the Free Software Foundation; either version 2, or (at your option)
#- any later version.
#-
#- This program is distributed in the hope that it will be useful,
#- but WITHOUT ANY WARRANTY; without even the implied warranty of
#- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#- GNU General Public License for more details.
#-
#- You should have received a copy of the GNU General Public License
#- along with this program; if not, write to the Free Software
#- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

# Setting output buffer

	# Loading libraries.
	
	use Net::DNS;
	use Term::ANSIColor qw(:constants);
	
	# About
	
	 my $ver="0.0.1.1";
	 my $verbose="no";
	# print "RBL Lookup v.$ver\n";
	# print "Copyright (c) 2003 Marcin Gondek <drixter\@e-utp.net>\n";
	# print "\n";
	
	# Sorting IP/DNS
#AVS
	$iaddr = $_[0];
	$iaddr =~ s/\]//gi;
#print "2. ipaddr = $iaddr\n";	
#	@iaddr = split (/\./, $iaddr);
#	 @iaddr = gethostbyname($ARGV[0]);
	 @iaddr = gethostbyname($iaddr);
	 if ( ! defined @iaddr ) {die "Network Error / Wrong IP/HOST";}
	 if ( defined @iaddr ) {($a,$b,$c,$d) = unpack('C4', @iaddr[4]);}
	
	 if ($ARGV[1] eq "-v") {$verbose="yes";}
	 
	#print "Checking $a.$b.$c.$d...\n";
	
	# Main
	
	# Numbers of servers
	
	my @servers_no=(0,75,15,13,3);
	
	# RBL servers
	
#	my @serversA = ("zen.spamhaus.org","blacklist.spambag.org","blackholes.five-ten-sg.com","blackholes.intersil.net","block.blars.org","bl.spamcop.net","blackholes.easynet.nl","wpb.bl.reynolds.net.au","mail-abuse.blacklist.jippg.org","blackhole.compu.net","spamguard.leadmon.net","3y.spam.mrs.kithrup.com","dnsbl.njabl.org","xbl.selwerd.cx","spam.wytnij.to","t1.bl.reynolds.net.au","ricn.bl.reynolds.net.au","rmst.bl.reynolds.net.au","ksi.bl.reynolds.net.au ","rbl.rope.net","rbl.ntvinet.net","no-more-funn.moensted.dk","list.dsbl.org","unconfirmed.dsbl.org","ipwhois.rfc-ignorant.org","in.dnsbl.org","spam.dnsrbl.net","blackholes.uceb.org","sbbl.they.com","rsbl.aupads.org","hil.habeas.com","bl.deadbeef.com","intruders.docs.uu.se","bl.technovision.dk","spam.exsilia.net","mail.people.it","blocklist.squawk.com","blocklist2.squawk.com","rbl.fnidder.dk","bl.borderworlds.dk","dnsbl.delink.net","blocked.hilli.dk","blacklist.sci.kun.nl","rbl.schulte.org","forbidden.icm.edu.pl","msgid.bl.gweep.ca","dnsbl.sorbs.net","spam.dnsbl.sorbs.net","vox.schpider.com","query.trustic.com","dnsbl.isoc.bg","satos.rbl.cluecentral.net","spamsources.dnsbl.info","blacklist.woody.ch","all.spamblock.unit.liu.se","lbl.lagengymnastik.dk","rbl.firstbase.com","bl.tolkien.dk","reject.the-carrot-and-the-stick.com","ip.rbl.kropka.net","all.rbl.kropka.net","psbl.surriel.com","dnsbl.antispam.or.id","map.spam-rbl.com","probes.bl.reynolds.net.au","cbl.abuseat.org","dnsbl.solid.net","will-spam-for-food.eu.org","dnsbl.jammconsulting.com","spamsources.yamta.org","rbl-plus.mail-abuse.org","fresh.dict.rbl.arix.com","stale.dict.rbl.arix.com","fresh.sa_slip.rbl.arix.com","blackholes.alphanet.ch");
#	my @serversA = ("zen.spamhaus.org","bl.spamcop.net","dnsbl.njabl.org","dnsbl.sorbs.net");
	my @serversA = ("zen.spamhaus.org","bl.spamcop.net","dnsbl.sorbs.net","dnsbl.njabl.org");
	
	# Open Relay servers
	
#	my @serversB = ("relays.mail-abuse.org","relays.ordb.org","dev.null.dk","omrs.bl.reynolds.net.au","osrs.bl.reynolds.net.au","multihop.dsbl.org","orvedb.aupads.org","relays.nether.net","unsure.nether.net","relays.bl.gweep.ca","smtp.dnsbl.sorbs.net","or.rbl.kropka.net","relays.bl.kundenserver.de","relays.visi.com","relaywatcher.n13mbl.com");
	
	# Open Proxy servers
	
#	my @serversC = ("proxies.relays.monkeys.com","proxies.exsilia.net","proxy.bl.gweep.ca","proxies.blackholes.easynet.nl","op.rbl.kropka.net","opm.blitzed.org","owps.bl.reynolds.net.au","ohps.bl.reynolds.net.au","osps.bl.reynolds.net.au","http.dnsbl.sorbs.net","socks.dnsbl.sorbs.net","misc.dnsbl.sorbs.net","pss.spambusters.org.ar");
	
	# Open FormMail servers
	
#	my @serversD = ("web.dnsbl.sorbs.net","formmail.relays.monkeys.com","form.rbl.kropka.net");
	
	# Setting results
	
	my @result_ok = (0,0,0,0,0);
	my @result_fail = (0,0,0,0,0);
	my @result_total = (0,0,0,0,0);
	
	# Initializing main variables
	
	my $total_server_list=5;
	my $current=0;
	my $ok=0;
	my $fail=0;
	my $collection=1;
	
	# DNS Timeouts
	
	$tcp_timeout=10;
	$udp_timeout=10;
	
	# Query All by one connect (1=true, 0=false)
	
	$persistent_tcp=1;
	
	# Show status
	
	 my $dns  = Net::DNS::Resolver->new;
	 @nameservers = $dns->nameservers;
	#print "Name server    : ",$nameservers[0],"\n";
	#print "TCP timeout    : ",$tcp_timeout, "\n";
	#print "UDP timeout    : ",$udp_timeout, "\n";
	 if ($persistent_tcp=="1")
	 {
	#print "Persistent mode: True\n";
	 } 
	 if ($persistent_tcp=="0")
	 {
	#print "Persistent mode: False\n";
	 } 
	
	
	while ($total_server_list>$collection)
	{
	#  if ($collection==1){print "\nRBL Scan...\n";}
	#  if ($collection==2){print "\nOpen Relay Scan...\n";}
	#  if ($collection==3){print "\nOpen Proxy Scan...\n";}
	#  if ($collection==4){print "\nOpen FormMail Scan...\n";}
	 while ($current<$servers_no[$collection])
	 { 
	   if ($verbose eq "yes")
	   {
	#    if ($collection==1){print $serversA[$current],"...";}
	#    if ($collection==2){print $serversB[$current],"...";}
	#    if ($collection==3){print $serversC[$current],"...";}
	#    if ($collection==4){print $serversD[$current],"...";}
	   }
	#   if ($verbose eq "no"){print ".";} 
	   my $res  = Net::DNS::Resolver->new;
	   $res->tcp_timeout($tcp_timeout);
	   $res->udp_timeout($udp_timeout);
	   $res->persistent_tcp($persistent_tcp);
	   if ($collection==1)
	   {
	   	   if ($serversA[$current]) # AVS
	   	   {
	   	   	   $query = $res->query("$d.$c.$b.$a.@serversA[$current]", "A");
#$answer = 0;
#if ($query) { $answer = $query->answer; }
#$ret = $_;
#&RecordLogs( "RBL Checking: $d.$c.$b.$a.@serversA[$current]: current = $current; answer = $answer\n");
	   	   }
	   }
	#   if ($collection==2)
	#   {$query = $res->query("$d.$c.$b.$a.@serversB[$current]", "A");}
	#   if ($collection==3)
	#   {$query = $res->query("$d.$c.$b.$a.@serversC[$current]", "A");}
	#   if ($collection==4)
	#   {$query = $res->query("$d.$c.$b.$a.@serversD[$current]", "A");}
	   if ($query)
	   {
		  foreach $rr (grep { $_->type eq 'A' } $query->answer)
		  {
		  	 if ($verbose eq "yes")
			 {
	#	      print "[",BOLD, RED, "LISTED", CLEAR, "]\n";
			 }
			 $fail++
		  }
	   }
	   else 
	   {
	#      if ($verbose eq "yes"){print "[", BOLD, GREEN, "clean", CLEAR,"]\n";}
		  $ok++
	   }
	  $current++
	 }
	
	# Saving results
	
	@result_ok[$collection]=$ok;
	@result_fail[$collection]=$fail;
	@result_total[$collection]=$current;
	
	# Seting variables
	
	$collection++;
	$ok=0;
	$fail=0;
	$current=0;
	}
	
	# Printing results
#	print "$result_fail[1]\n";
#AVS
#&RecordLogs( "RBL result_fail = @result_fail;\n");
	return $result_fail[1];
	#print "\nRBL status:  ( OK / Listed / Total )\n";
	#print $result_ok[1], " ", $result_fail[1], " ", $result_total[1], "\n";
	#print "\nOpen Relay status:  ( OK / Listed / Total ) \n";
	#print $result_ok[2], " ", $result_fail[2], " ", $result_total[2], "\n";
	#print "\nOpen Proxy status: ( OK / Listed / Total )\n";
	#print $result_ok[3], " ", $result_fail[3], " ", $result_total[3], "\n";
	#print "\nOpen FormMail status: ( OK / Listed / Total )\n";
	#print $result_ok[4], " ", $result_fail[4], " ", $result_total[4], "\n";
	
	# END 
}
sub FailedSPFcheck
{
    my $spf_server  = Mail::SPF::Server->new();
#print "FailedSPFcheck : ip = $ip\n";    
    my $request     = Mail::SPF::Request->new(
        versions        => [1, 2],              # optional
        scope           => 'mfrom',             # or 'helo', 'pra'
        identity        => "$senderEmail",
        ip_address      => $ip
    );
#print("FailedSPFcheck: $request\n");
#        helo_identity   => 'mta.example.com'    # optional,
                                                #   for %{h} macro expansion
    
    my $result      = $spf_server->process($request);
    my $result_code     = $result->code;        # 'pass', 'fail', etc.
    
#    print("$result\n");
#    my $local_exp       = $result->local_explanation;
#    my $authority_exp   = $result->authority_explanation;
#    my $spf_header      = $result->received_spf_header;
	if ($result_code =~ /fail/i && $result_code !~ /softfail/i)  # This is used only in determining whether to notify=0 or 1. Hence, only a positive value is needed 
	{
		$da_reason = "SPF Failed";
		return 1;
	}
	return 0;
}
sub SelfSpoofCheck
{
#&RecordLogs( "1. SelfSpoofCheck:IP = $ip;\n");
	# Checking for self spoof when the IP = 0.0.0.0 is meaningless. So, pass it for other tests
	if ($ip == '0.0.0.0') 
	{
		if ($senderEmail =~ /avs\@webgenie.com/i)
		{
			return 1;
		}
		return 0; 
	}
	# See if this domain has is in 'selfspoofcheck' 
	$query = "select isp from `selfspoofcheck` where senderDomain='$senderDomain'";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	my $isp = $results[0];
	if ($isp) 
	{ 
# Check if from known ISP
		$iaddr = inet_aton($ip); 
		$name  = gethostbyaddr($iaddr, AF_INET);
		if($name =~ /$isp/i) { return 0; }
		$da_reason = "Self Spoof";
		return 1; 

		#Check whether the IP matches
#		$query = "select count(*) from `selfspoofcheck` where senderDomain='$senderDomain' and (two_octets = '$two_octets')";
#		&execute_query($query);
#		@results = &Fetchrow_array(1);
#		if ($results[0]) { 	return 0; } # This means the knownuser will be set as 1
#		else 
#		{ 
#			$da_reason = "Self Spoof";
#			return 1; 
#		}
	}
	else { return 0; }
}

sub ChecksenderEmailAndIPinWhiteList
{
	@senderEmail = split (/\@/, $senderEmail);
	$senderDomain = "\*\@" . $senderEmail[1];
	# First, check an unconditional whiteaddresses list. These are addresses never spoofed with, but could be coming from different IPs
	# Adding a domain to the list may be considered.
#	$query = "select count(*) from `whiteaddresses` where senderEmail='$senderEmail' and (userUrk=$userUrk or userUrk=$sharedUrk)";
	$query = "select count(*) from `whiteaddresses` where (senderEmail='$senderEmail' or senderEmail='$senderDomain') and (userUrk=$userUrk or userUrk=$sharedUrk);";

	&execute_query($query);
	@results = &Fetchrow_array(1);
	if (!$results[0])
	{
		$senderDomain = $senderEmail[1];
		#Check for an email/IP match or domain/IP match
		$query = "select count(*) from `whitelist` where (senderEmail='$senderEmail' or senderEmail='$senderDomain') and two_octets = '$two_octets' and (userUrk=$userUrk or userUrk=$sharedUrk)";
		&execute_query($query);
		@results = &Fetchrow_array(1);
		if (!$results[0])
		{
			#Check for a manually added email address. Thsi will have a null IP
			$query = "select count(*) from `whitelist` where senderEmail='$senderEmail' and ip = '' and (userUrk=$userUrk or userUrk=$sharedUrk)";
			&execute_query($query);
			@results = &Fetchrow_array(1);
			if ($results[0])
			{
				$query = "update `whitelist` set senderDomain = '$senderDomain', ip='$ip', three_octets='$three_octets', two_octets = '$two_octets' where senderEmail='$senderEmail' and ip = '' and (userUrk=$userUrk or userUrk=$sharedUrk)";
				&execute_query($query);
			}
			else
			{
				# Check if it is a known email address to any user and from any IP
				$query = "select count(*) from `whitelist` where senderEmail='$senderEmail'";  
				&execute_query($query);
				@results = &Fetchrow_array(1);
				if ($results[0])
				{
					if (&SelfSpoofCheck) { $results[0] = 0; }  # This is a self spoof
#&RecordLogs( "2. SelfSpoofCheck:results[0] = $results[0];\n");
				}
			}
		}
	}
#print "Result = $results[0]\n";
	return $results[0];  # Check the DB before returning
}
sub UpdateMonitorTable
{
#return;	
	$column = $_[0];
	$monitorrefreshCycle = $monitorcycle%$monitorRefreshCycles;
	$monitorcycle++;
#	if ($monitorrefreshCycle == 0 || $column eq "da") 
	if ($monitorrefreshCycle == 0) 
	{
		$ct = time();
		$query = "update `monitor` set $column=$ct where urk=1";
#print "query = $query\n";
		&execute_query($query);
		$monitorcycle = 0; 
	}
}

sub UpdateHistoryTable
{
	$this_action = $_[0];
	$query = "select action from `history` where msgID='$msgID'";
#&RecordLogs ("0-1. $query\n");
	&execute_query($query);
	@results = &Fetchrow_array(1);
	$action = $results[0];
	if ($action)
	{
		$action .= ",$this_action";
		$query = "update `history` set action='$action' where msgID='$msgID'";
#&RecordLogs ("0-2. $query\n");
		&execute_query($query);
#&RecordLogs ("0-2-a. $query\n");
	}
}
sub MakeOrderNumber
{
	$ct = time();
	@Email = split (/@/, "$User_email");
	$orderNo = "$Email[0]$ct";
	$orderNo =~ s/\W//gi;
}
sub RecordLogs
{
	my $logline = $_[0];
	open (OUT, ">>$logFile");
	print OUT "$logline";
	close (OUT);
}
sub GetMailHeader
{
	open (INP, "<$mailfile");
	my @filecontent = <INP>;
	close (INP);
	$len = $#filecontent;
#print "mailfile = $mailfile; len = $len\n";	
	for (my $j=0; $j <= $len; $j++)
	{
		$mailheaders .= $filecontent[$j];
		if ($filecontent[$j] eq "\n") { last; }
	}
	$mailheaders =~ s/\n/<br>\n/gi;
#print "mailheaders = $mailheaders\n";	
}
sub SendChallenge
{
	&GetMailHeader;
	
	$textmailbody = "Your email sent to $recipientEmail needs confirmation before delivery. 
The mail you sent (see below) has not yet been delivered.

Subject: $subject
From: $senderEmail
To: $recipientEmail

Our apologies for sending this verification to you if you did not send the above mail in the first instance.

You may either just ignore this notification or let us know that your email address is being used for 'spoofing' by spammers. We shall
promptly mask future challenge mails sent to your address.

Otherwise, just for once, please click the link below to let the system accept your address and deliver the mail.

$cgiURL?S+$hashcode

Thank you for your co-operation.

Mail Header Lines: 
$mailheaders 
";
	open (INP, "<$challenge_template");
	my @filecontent = <INP>;
	close (INP);
	my $len = $#filecontent;
	$mailbody = "";
	for (my $j=0; $j <= $len; $j++)
	{
		$mailbody .= &WSCPReplaceTags($filecontent[$j]);
	}
	$Form_subject_user = "Re: $subject";
	&PutHeadersInAckMailFile ($Owner_name, $noreplyEmail, $noreplyEmail, $noreplyEmail, $senderEmail, $Form_subject_user);
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
	`$mailprogram -f $noreplyEmail $senderEmail < $filename`;
	$mailerror = $?;
print("SendChallenge:mailerror = $mailerror;	`$mailprogram -f $noreplyEmail $senderEmail < $filename`;\n");
#   	unlink ($filename);
}
sub SkipToEnd
{
	for ($jj; $jj <= $len; $jj++)
	{
		if ($ThreeLinesContent[$jj] == '>') { $jj++; return; }
	}
}
sub GetThreeLines
{
	$ThreeLinesContent = "";
	open (INP, "<$mailfile");
	@ThreeLinesContent = <INP>;
	close (INP);
	$len = $#ThreeLinesContent;
	$jj=0;
	for ($jj=0; $jj <= $len; $jj++)
	{
#Content-Type: multipart/alternative; boundary="MIMEBoundary58e8a269587628d00336c6914ca128ad"

		if ($ThreeLinesContent[$jj] =~ /boundary/i)
		{
			my @fields = split (/=/, $ThreeLinesContent[$jj]);
			$boundary = $fields[1];
			$boundary =~ s/\"//gi;
			$boundary =~ s/\n//gi;
			$boundary =~ s/\s//gi;
		}
		if ($ThreeLinesContent[$jj] eq "\n") { last; }
	}
	if ($boundary)
	{
		for ($jj; $jj <= $len; $jj++)
		{
			if ($ThreeLinesContent[$jj] =~ /$boundary/) { last; }
		}
		for ($jj; $jj <= $len; $jj++)
		{
			if ($ThreeLinesContent[$jj] eq "\n") { last; }
		}
	}
	for ($jj++; $jj <= $len; $jj++)
	{
		$ThreeLinesContent .= $ThreeLinesContent[$jj];
	}
	$ThreeLinesContent =~ s/\n/ /gi;
	@ThreeLinesContent = split (//, $ThreeLinesContent);
	$len = $#ThreeLinesContent;
	$ThreeLinesContent = "";
	$jk = 0;
	for ($jj=0; $jj <= $len; $jj++)
	{
		if ($ThreeLinesContent[$jj] eq "<") { &SkipToEnd; }
#print "$jj. $ThreeLinesContent[$jj]\n";
		$ThreeLinesContent .= $ThreeLinesContent[$jj];
#		$jk++;
#		if ($jk >= 600) { last; }
	}
	$ThreeLinesContent =~ s/=3D//gi;
	@ThreeLinesContent = split (//, $ThreeLinesContent);
	$len = $#ThreeLinesContent;
	for ($jj=60; $jj <= $len; $jj++)
	{
		$ThreeLinesContent[$jj] = "";
	}
	$ThreeLinesContent = join ("", @ThreeLinesContent);
	$ThreeLinesContent .= "...";
	$ThreeLinesContent =~ s/\n/ /gi;
	$ThreeLinesContent =~ s/\'/ /gi;
}
sub AlertAndChallenge_0
{
	if ($notify > 0)
	{
		&GetThreeLines; # Take the first 3 lines of text in the body
		&UpdateHistoryTable($alertedcode);
		$query = "update `statistics` set alrt=alrt+1 where userUrk=$userUrk and day=0";
		&execute_query($query);
	}
	if ($notify == 0)
	{
		&UpdateHistoryTable($dailyalertedcode);
		$query = "update `statistics` set dalrt=dalrt+1 where userUrk=$userUrk and day=0";
		&execute_query($query);
	}
	if ($notify < 0)
	{
		&UpdateHistoryTable($dailyreportcode);
		$query = "update `statistics` set drprt=drprt+1 where userUrk=$userUrk and day=0";
		&execute_query($query);
#print "$query\n";
	}
	if ($lmode)
	{
		if ($notify > 0)
		{
			$query = "select Raw_email,Clean_email,Alt_Clean_email from `users` where urk=$userUrk";
			&execute_query($query);
			my @results = &Fetchrow_array(3);
			$Raw_email = $results[0];
			$Clean_email = $results[1];
				$userOut = $Clean_email;
			$Alt_Clean_email = $results[2];
			my @fields = split (/\@/, $Raw_email);
			$userIn = $fields[0];
			$domain = $fields[1];
			$query = "update `statistics` set lm_f=lm_f+1 where userUrk=$userUrk and day=0";
			&execute_query($query);
			&DeliverToCleanMailbox;
			&UpdateHistoryTable($forwardedinlmodecode);
			$query = "update `quarantine` set sascore=$sascore, notified=4, accept_method='L', delivered=2 where urk=$urk"; # This will be alerted
			&execute_query($query);
			if ($knownuser <= 0)
			{
				$query = "insert into `whitelist` (senderEmail,userUrk,senderDomain,ip,three_octets,two_octets,accept_method) 
				values ('$senderEmail',$userUrk,'$senderDomain','$senderIP','$three_octets','$two_octets','L')";
				&execute_query($query);
			}
		}
	}
	else
	{
		$query = "update `quarantine` set sascore=$sascore, notified=$notify, threelines ='$ThreeLinesContent' where urk=$urk"; 
		&execute_query($query);
		if ($alert)
		{
			&execute_query($query);
			$query = "select urk from `ignoredlist` where senderEmail='$senderEmail' and userUrk=$userUrk";
			&execute_query($query);
			@results = &Fetchrow_array(1);
			$ignoredID = $results[0];
			#Put this address in ignoredlist and take off if the user accepts the sender. Then, if the count exceeds threshold, the mail can be left out of alerts
			if ($ignoredID)
			{
				if ($notify > 0)
				{
					$query = "update `ignoredlist` set notified=notified+1, ignored=ignored+1 where urk=$ignoredID"; 
				}
				else
				{
					$query = "update `ignoredlist` set ignored=ignored+1 where urk=$ignoredID"; 
				}
				
			}
			else
			{
				$query = "insert into `ignoredlist` (senderEmail,recipientEmail,userUrk,notified,ignored) values ('$senderEmail','$recipientEmail',$userUrk,$notify,1)";
			}
			&execute_query($query);
		}
		if ($challenge) # No challenge and No alert if EnvIP != mxIP. There may be a risk here. Perhaps a daily alert is needed
		{
			if ($notify > 0)
			{
				&UpdateHistoryTable($challengedcode);
				$query = "update `statistics` set cr=cr+1 where userUrk=$userUrk and day=0";
				&execute_query($query);
				&SendChallenge;
			}
		}
	}
}
sub AntiSpamCheck
{
#$ct0 = time();
	$rbl_sender = &RblCheck($senderIP);  # e.g. SBL blocked IPs: 200.51.92.92, 200.51.95.76, 190.177.83.11
#$et = &TimeLapse;
#&RecordLogs("RBL Check: $senderIP = $rbl_sender - $et sec\n");
	if ($rbl_sender > 0) 
	{ 
		$sascore = 10.11; # Just say that this is more than threshold. 
		return $sascore; # Don't do spamassasin.
	} 
   $sascore = 0;
   eval
   {
	 local $SIG{ALRM} = sub {die "query timeout\n"};
	 alarm 60;
		$result = `spamc -c < $mailfile`;
		@result = split (/\//, $result);
		$sascore = $result[0];
		return $sascore;
	 alarm 0;
   };

   if ($@ =~ "query timeout\n")
   {
&RecordLogs("Timeout: AntiSpamCheck - $urk\n");				
	return $sascore;
   }
}

sub EnvIPLine
{
	my $envIPLine = "";
#Received: from cpe-236.246.115.200.in-addr.arpa (HELO g9d71g1) (200.115.246.236)
#Received: from balder554.startdedicated.com (mail.webgenie.com [209.239.112.110])
#Received: from webbox734.server-home.net (195.137.212.174)
#Received: from webbox734.server-home.net (postfix@195.137.212.174)
# Get the last line corresponding to any format above
	for ($k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
#		if ($filecontent[$k] =~ /Received: from .*\(\d*\.\d*\.\d*\.\d*\)/) { $envIPLine = $filecontent[$k]; }	
		if ($filecontent[$k] =~ /Received: from .*\(.*\d*\.\d*\.\d*\.\d*.*\)/) { $envIPLine = $filecontent[$k]; } 
	}
#&RecordLogs("envIPLine = $envIPLine\n");
	return $envIPLine;
}

sub EnvIPLine_0
{
	if ($filecontent[$k] =~ /Received: from .*\(\d*\.\d*\.\d*\.\d*\)/) { return 1; }	# e.g Received: from webbox734.server-home.net (195.137.212.174)
	if ($filecontent[$k] =~ /Received: from .*\(\D*\d*\.\d*\.\d*\.\d*\)/) {	return 1; } # e.g Received: from webbox734.server-home.net (postfix@195.137.212.174)
	return 0;
}

sub NextIPLine
{
	if ($filecontent[$k] =~ /$ip/) { return 0; }
	if ($filecontent[$k] =~ /Received: from .*\[\d*\.\d*\.\d*\.\d*\]/) { return 1; } 
	if ($filecontent[$k] =~ /Received: from .*\(\d*\.\d*\.\d*\.\d*\)/) { return 1; } 
	return 0;
}

sub GetEnvIP
{
	$ip = "EIGHTEEN_LOOKINGFORIT"; # This is a random string to make sure that this line, $filecontent[$k] !~ /$ip/, doesn't match a blank
	# Get Env ip
	if ($envIPLine = &EnvIPLine)
	{
#print "\n------------------------------------------------------------------------------\nGetEnvIP: $filecontent[$k]";
#Received: from cpe-124-178-247-177.static.sa.bigpond.net.au (HELO ?10.0.0.6?) (124.178.247.177)
		
		$envIPLine =~ s/\n//gi;
		$envIPLine =~ s/\r//gi;
		$envIPLine =~ s/\(//gi;
		$envIPLine =~ s/\)//gi;
		$envIPLine =~ s/\[//gi;
		$envIPLine =~ s/\]//gi;
		my @fields = split (/ /, $envIPLine);
		my $len = $#fields;
		
		$heloField = 0;
		$ipField = $fields[$len];
		$heloField = $fields[$len-1];
#&RecordLogs( "envIPLine = $envIPLine\n");
#&RecordLogs( "ipField = $ipField\n");
#&RecordLogs( "heloField = $heloField\n");
#ipField = p2-pen4.ad.prodcc.net [10.252.0.104])

		if ($ipField =~ /\d*\.\d*\.\d*\.\d*/)
		{
			$ip = $ipField;
		}
		else
		{
			$ip = '0.0.0.0';
		}
#&RecordLogs( "GetEnvIP:IP = $ip\n");
#		@ip = split (/\./, $ip);
#		$three_octets = "$ip[0].$ip[1].$ip[2]";
#		$two_octets = "$ip[0].$ip[1]";
#		last;
		if ($heloField && $heloField !~ /HELO.*\./ || $heloField =~ /\@/ || $heloField =~ /_/ || ($heloField =~ /HELO\s*\d*\.\d*\.\d*\.\d*\)/))
		{
#			$invalidHelo = 1;
#			return;
		}
	}
	else
	{
		$ip = '0.0.0.0';
	}
	$ip =~ s/\@//gi; # e.g. @194.158.206.78 
	@ip = split (/\./, $ip);
	$three_octets = "$ip[0].$ip[1].$ip[2]";
	$two_octets = "$ip[0].$ip[1]";
}
sub GetEnvIP_0
{
	$ip = "EIGHTEEN_LOOKINGFORIT"; # This is a random string to make sure that this line, $filecontent[$k] !~ /$ip/, doesn't match a blank
	# Get Env ip
	if ($envIPLine = &EnvIPLine)
	{
#print "\n------------------------------------------------------------------------------\nGetEnvIP: $filecontent[$k]";
#Received: from cpe-124-178-247-177.static.sa.bigpond.net.au (HELO ?10.0.0.6?) (124.178.247.177)
		my @fields = split (/\(/, $envIPLine);
		$heloField = 0;
		$ipField = $fields[2];
		if ($ipField)
		{
			$heloField = $fields[1];
		}
		else
		{
			$ipField = $fields[1];
		}
#&RecordLogs( "envIPLine = $envIPLine\n");
#&RecordLogs( "ipField = $ipField\n");
#ipField = p2-pen4.ad.prodcc.net [10.252.0.104])

if ($ipField =~ /\)/)
{
		@fields = split (/\)/, $ipField);
}
		$ip = $fields[0];
		$ip =~ s/^\D*//gi; 
		$ip =~ s/\[//gi; 
		$ip =~ s/\]//gi; 
#&RecordLogs( "IP = $ip\n");
		@ip = split (/\./, $ip);
		$three_octets = "$ip[0].$ip[1].$ip[2]";
		$two_octets = "$ip[0].$ip[1]";
#		last;
		if ($heloField && $heloField !~ /HELO.*\./ || $heloField =~ /\@/ || $heloField =~ /_/ || ($heloField =~ /HELO\s*\d*\.\d*\.\d*\.\d*\)/))
		{
			$invalidHelo = 1;
#			return;
		}
	}
}
sub GetNextIP
{
#&RecordLogs("GetNextIP:  (EnvIP: $ip)\n");				
#print "GetNextIP:  (EnvIP: $ip)\n";
#if ($ip =~ /EIGHTEEN_LOOKINGFORIT/)
#{
#	`cp $mailfile $quarantinemailDirTmp/$$`;
#	exit;  # debug;
#}
	for ($k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		
#		if ($filecontent[$k] !~ /$ip/ && ($filecontent[$k] =~ /Received:.*\[\d*\.\d*\.\d*\.\d*\]/ || $filecontent[$k] =~ /Received:.*\(\d*\.\d*\.\d*\.\d*\)/))
		if ($nextIPLine = &NextIPLine)
		{
			if ($filecontent[$k] =~ /Received:.*\[.*\]/)
			{
				my @fields = split (/\[/, $filecontent[$k]);
				@fields = split (/\]/, $fields[1]);
				$ip = $fields[0];
				@ip = split (/\./, $ip);
				$three_octets = "$ip[0].$ip[1].$ip[2]";
				$two_octets = "$ip[0].$ip[1]";
				last;
			}
			if ($filecontent[$k] =~ /Received:.*\(.*\)/)
			{
				my @fields = split (/\(/, $filecontent[$k]);
				if ($fields[1] =~ /\d*\.\d*\.\d*\.\d*\)/)
				{
					$ipField = $fields[1];
				}
				else
				{
					$ipField = $fields[2];
				}
				@fields = split (/\)/, $ipField);
				$ip = $fields[0];
				@ip = split (/\./, $ip);
				$three_octets = "$ip[0].$ip[1].$ip[2]";
				$two_octets = "$ip[0].$ip[1]";
				last;
			}
		}
	}
}
sub GetsenderEmailAndIP
{
	$calledFrom = $_[0];
&RecordLogs("\n--$calledFrom-------------------$ProcessTime------------------------\n");				
#&RecordLogs("mailfile = $mailfile\n");
	open (INP, "<$mailfile");
	@filecontent = <INP>;
	close (INP);
	$len = $#filecontent;
	$ip = "";
	$invalidHelo = 0;
	$heloIsIP = 0;
	&GetEnvIP;
	if ($ip =~ /EIGHTEEN_LOOKINGFORIT/)
	{
		$ip = "";
	}
	if (!$ip && !$invalidHelo) { &GetNextIP; }
	# Get senderEmail
	for (my $k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^From:/)
		{
			my @fields = split (/:/, $filecontent[$k]);
			if ($fields[1] =~ /</)
			{
				@fields = split (/</, $fields[1]);
				@fields = split (/>/, $fields[1]);
				$senderEmail = $fields[0];
				$senderEmail =~ s/\s//gi;
				$senderEmail =~ s/\'//gi;
				$senderEmail =~ s/\\//gi;
			}
			else
			{
				$senderEmail = $fields[1];
				$senderEmail =~ s/\s//gi;
				$senderEmail =~ s/\'//gi;
				$senderEmail =~ s/\\//gi;
			}
			last;
		}
	}
#&RecordLogs("\n---------------------------------------------\n");				
&RecordLogs("Sender = $senderEmail; ");				
#print "senderEmail = $senderEmail\n";
	# Get recipientEmail
	for (my $k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^To:/)
		{
			my @fields = split (/:/, $filecontent[$k]);
# To: Arapaut Sivaprasad <asivapra@gmail.com>
# To: asivapra@gmail.com
			if ($fields[1] =~ /</)
			{
				@fields = split (/</, $fields[1]);
				@fields = split (/>/, $fields[1]);
				$recipientEmail = $fields[0];
				$recipientEmail =~ s/\s//gi;
				$recipientEmail =~ s/\'//gi;
				$recipientEmail =~ s/\\//gi;
			}
			else
			{
				$recipientEmail = $fields[1];
				$recipientEmail =~ s/\s//gi;
				$recipientEmail =~ s/\'//gi;
				$recipientEmail =~ s/\\//gi;
			}
			last;
		}
	}
&RecordLogs("Recipient = $recipientEmail; ");				
#print "recipientEmail = $recipientEmail\n";
	my @recipientEmail = split (/\@/, $recipientEmail);
	my $recipientDomain = $recipientEmail[1];
	if ($localdomains !~ /\|$recipientDomain\|/i)
	{
#		&GetNextIP;  # This is to make sure that the IP used is the original and that of gmail.com
	}
&RecordLogs("IP = $ip\n");				
#print "ip = $ip\n";
	for (my $k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^Subject:/)
		{
			my @fields = split (/Subject:/, $filecontent[$k]);
			$subject = $fields[1];
			$subject =~ s/\n//gi;
			last;
		}
	}
	for (my $k=0; $k <= $len; $k++)
	{
		# Exit at header boundary
		if ($filecontent[$k] eq "\n")
		{
			last;
		}
		if ($filecontent[$k] =~ /^Message-ID:/i)
		{
			my @fields = split (/:/, $filecontent[$k]);
			$Message_ID = $fields[1];
			$Message_ID =~ s/\n//gi;
			$Message_ID =~ s/ //gi;
			$Message_ID =~ s/\<//gi;
			$Message_ID =~ s/\>//gi;
			$Message_ID =~ s/\'//gi;
			last;
		}
	}
#	if (!$Message_ID) { $Message_ID = "<" . $senderEmail . "\@" . $ip . ">"; }
	if (!$Message_ID) { $Message_ID = "<" . $senderEmail . "_" . $subject . ">"; }
&RecordLogs("Subject = $subject; ");				
#&RecordLogs("Message_ID = $Message_ID\n");				
#print "subject = $subject\n";
#&RecordLogs("To: SafeSubject.\n");				
$safeSubject = &SafeSubject($subject);
#&RecordLogs("From: SafeSubject: $safeSubject.\n");				
#	$safeSubject = $subject;
#	$safeSubject =~ s/\'/\\\'/gi;
#	$safeSubject =~ s/\"/\\\"/gi;
	$query = "insert into subjects (subject) values ('$safeSubject')";
#&RecordLogs("query:  $query.\n");				
	&execute_query($query);
}
sub SafeSubject
{
	my $safeSubject = $_[0];
	$safeSubject =~ s/\\/\\\\/gi;
	$safeSubject =~ s/\'/\\\'/gi;
	$safeSubject =~ s/\"/\\\"/gi;
	return $safeSubject;
}
sub GetLocation
{
	my $IP = $_[0];
	my ($response) = whoisip_query($IP);
	while (my ($k,$v) = each %{$response}) 
	{
		if ($k =~ /country/i)
		{
			$Country = $v;
			return $Country;
		}
	}
	$Country = "Unknown";
	return $Country;
}
sub CheckIfBlockedSubject
{
#	$query = "select count(*) from `subjects_blocked` where subject = ' $subject'";
	$query = "select urk from `subjects_blocked` where subject like '%$subject'";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	return $results[0];  # Check the DB before returning
}
sub CheckIfBannedCountry
{
	my $tlds = "|com|gov|org|net|biz|au|nz|uk|us|de|fr|sg|ca|";
	my @fields = split (/\./, $senderEmail);
	my $len = $#fields;
	my $tld = $fields[$len];
	if($tlds =~ /\|$tld\|/i) { return 0; }
	return 1;
}
sub GetCountry
{
	my $ip = $_[0];
	my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);
	my $country = $gi->country_code_by_addr($ip);
	return $country;
}
sub CountryCheck
{
	if(!$ip || $ip eq "0.0.0.0") { return 0; }
	my @allowed_countries = qw(AU AE AT BE BH CA CH DE DK ES FI FR GB GU IL IN IS IT JP KW LU NL NO NZ OM QA SA SE SG US VA ZA);
	my $country = &GetCountry($ip);	
	if(!$country || $country =~ /\*/) { return 0; }
	if($country ~~ @allowed_countries) { return 0; }
	else { return 1; }
}
sub CheckIfForeignLanguage
{
#	if ($subject =~ /=\?.*\?.*\?/ && $subject !~ /utf-8/i)
	if ($subject =~ /=\?GB2312\?/i) { return 1; }  			# Chinese
	if ($subject =~ /=\?BIG5\?/i) { return 1; }  			# Chinese

	if ($subject =~ /=\?koi8-r\?/i) { return 1; }  			# Russian
	if ($subject =~ /=\?koi8-u\?/i) { return 1; }  			# Russian
	if ($subject =~ /=\?ISO-8859-5\?/i) { return 1; }  		# Russian
	if ($subject =~ /=\?Windows-1251\?/i) { return 1; }  	# Russian

	if ($subject =~ /=\?ISO-2022-KR\?/i) { return 1; }  	# Korean
	if ($subject =~ /=\?utf-8\?B\?/i) { return 1; }  	# Unknown but not valid
	return 0;
}
sub CheckEnvCountryAlone
{
	if ($senderIP =~ /\D/) { return 1; } # Temp measure to fix the IP issue where the IP gets chars
	$EnvCountry = &GetLocation($senderIP);
	
	# We need to handle situations like Env = NZ, MX = US
	# This can result in some spam going into Alerts but will avoid the FP caused by situations like
	# an expatriate using a local SMTP server but using US-based domain name
	if ($EnvCountry =~ /RU/i) { return -2; } # Russia
	if ($EnvCountry =~ /RO/i) { return -2; } # Romania
	if ($EnvCountry =~ /CN/i) { return -2; } # China
	if ($EnvCountry =~ /KR/i) { return -2; } # Korea
	if ($EnvCountry =~ /NG/i) { return -2; } # Nigeria
	if ($EnvCountry =~ /BR/i) { return -2; } # Brazil
	if ($EnvCountry =~ /AR/i) { return -2; } # Argentina
	if ($EnvCountry =~ /PK/i) { return -2; } # Pakistan
	return 1; 
}
sub CheckBannedSubject # Dont include if something like 'Delivery Status Notification' or words in spam list
{
	if ($subject =~ /Delivery Status Notification/i) { return 1; }
	if ($subject =~ /Returned mail: see transcript for details/i) { return 1; }
	if ($subject =~ /Attn: Beneficiary/i) { return 1; }
	if ($subject =~ /Degree/i) { return 1; }
	if ($subject =~ /bidstakes/i) { return 1; }
	if ($subject =~ /Undeliverable: Facebook Support /i) { return 1; }
	if ($subject =~ /Why go to/i) { return 1; }
	if ($subject =~ /My name is/i) { return 1; }
	if ($subject =~ /Stop paying so much/i) { return 1; }
	if ($subject =~ /see attached file/i) { return 1; }
	if ($subject =~ /How much would you pay /i) { return 1; }
	if ($subject =~ /Hello/i) { return 1; }
	return 0;
}
sub CheckTooManySubjectLines
{
	my @subject = split (//, $subject);
	my $nchars = $#subject;
	if ($nchars < 5) { return 0; } # It is dangerous to compare small subject lines
	$query = "select count(*) from subjects where subject like '\%$subject\%'";
	&execute_query($query);
	my @results = &Fetchrow_array(1);
	if ($results[0] > 10) { return 1; }
	return 0;
}
sub CheckBannedDetails
{
	if ($senderIP =~ /^\d*\.\d*\.\d*\.\d*$/)
	{
#$ct0 = time();		
#		$rbl_sender = &RblCheck($senderIP);  # e.g. SBL blocked IPs: 200.51.92.92, 200.51.95.76, 190.177.83.11
#$et = &TimeLapse;
#&RecordLogs("$senderIP = $rbl_sender - $et sec\n");
	}
#print "rbl_sender = $rbl_sender; senderIP = $senderIP\n";
#exit;
	if ($rbl_sender > 0) { return 1; }

#	$notignored = &CheckIgnoredList('CheckBannedDetails');
#print "notignored = $notignored\n";
#	if (!$notignored) { return 1; }

	$result = &CheckEnvCountryAlone;  # See whether the sender IP comes from the same country as sender Domain's MX record
	if ($result < 0) { $bannedCountry = 1;}
	if ($bannedCountry) { return 1; }

	$foreignSubj = &CheckIfForeignLanguage;  # Drop if subject is Foreign language
	if ($foreignSubj && !$keepForeignSubject) { return 1; }

	$bannedSubj = &CheckBannedSubject;  
	if ($bannedSubj) { return 1; }

	$toomanySubj = &CheckTooManySubjectLines;  
	if ($toomanySubj) { return 1; }

	return 0;
}
sub CheckIgnoredList_0
{
	if ($knownuser == -1) { return 1; }  # This must be SA checked
	$query = "select notified,ignored from `ignoredlist` where senderEmail='$senderEmail' and userUrk=$userUrk";
#&RecordLogs("1. $query\n");
	&execute_query($query);
	@results = &Fetchrow_array(2);
	$n_notified = $results[0];
	$n_ignored = $results[1];
#&RecordLogs("$n_notified >= $n1_ignored_threshold && $n_ignored >= $n2_ignored_threshold\n");
	if ($n_notified >= $n1_ignored_threshold && $n_ignored >= $n2_ignored_threshold) # Don't alert at all
	{
		$da_reason = "IGNORED_LIST_NO_ALERT_$n_ignored";
#&RecordLogs("1. $da_reason\n");
		return 0;
	}
	elsif ($n_ignored >= $n2_ignored_threshold) # No Alert if self-spoof; or Push to Daily Alert
	{
		if ($senderEmail eq $recipientEmail)
		{
#&RecordLogs("2. $da_reason\n");
			return 0;
		}
		else
		{
			$da_reason = "IGNORED_LIST_$n_ignored";
#&RecordLogs("3. $da_reason\n");
			return 0;
		}
	}
#	elsif ($n_ignored >= $n1_ignored_threshold) # Push to Daily Alert
#	{
#		$da_reason = "IGNORED_LIST_$n_ignored";
##&RecordLogs("4. $da_reason\n");
#		return 0;
#	}
	return 1;
}

sub CheckIgnoredList
{
	my $calledfrom = $_[0];
	$query = "select notified,ignored from `ignoredlist` where senderEmail='$senderEmail' and userUrk=$userUrk";
#&RecordLogs("1. $query\n");
	&execute_query($query);
	@results = &Fetchrow_array(2);
	$n_notified = $results[0];
	$n_ignored = $results[1];
	if ($calledfrom eq "CleanItViaGmail" && $n_ignored > 3) # Sent to Gmail 3 times
	{
		$da_reason = "IGNORED_LIST_NO_ALERT_$n_ignored";
		return 0;
	}
	if ($calledfrom eq "CheckGmailPassedMails" && $n_notified > 3) # Alerted 3 times
	{
		$da_reason = "IGNORED_LIST_NO_ALERT_$n_ignored";
		return 0;
	}
	if ($calledfrom eq "CheckBannedDetails" && $n_notified > 3) # Alerted 3 times
	{
		$da_reason = "IGNORED_LIST_NO_ALERT_$n_ignored";
		return 0;
	}
	return 1;
}
sub IncrementNotified
{
	# Make a note that this has been notified. Then, if the user has ignored the sender too many times, dont alert it
	&execute_query($query);
	$query = "select urk from `ignoredlist` where senderEmail='$senderEmail' and userUrk=$userUrk";
	&execute_query($query);
	@results = &Fetchrow_array(1);
	$ignoredID = $results[0];
	#Put this address in ignoredlist and take off if the user accepts the sender. Then, if the count exceeds threshold, the mail can be left out of alerts
	if ($ignoredID)
	{
		$query = "update `ignoredlist` set notified=notified+1 where urk=$ignoredID"; 
	}
	else
	{
		$query = "insert into `ignoredlist` (senderEmail,recipientEmail,userUrk,notified,ignored) values ('$senderEmail','$recipientEmail','$userUrk','1','1')";
	}
#&RecordLogs("$query\n");
	&execute_query($query);
}

#--Global Variables-----------------------------
#$gmailaddress = 'asivapra@gmail.com';
#$gmailCleanAddress = 'gmail@webgenie.com';
#$noreplyEmail = 'noreply@webgenie.com	';
#$binDir = "/usr/local/bin/SecureMyEmail/Eighteen"; # WG server
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
$logFile = "$binDir/logFile.txt";
$subscribeUrl = "$baseURL/member_subscribe.html";
$memberAdminUrl = "$baseURL/admin_login.html";
$Brand_name = "ExonMail";
$tagline1 = "ExonMail - Complete Email Security & Deliverability. No Spam, No False Positives!";
$tagline2 = "New Generation Email Authentication Technology";
$bgColor = "#FFFFFF";
$challenge_template = "$baseDir/challenge_template.html";
$daemonURL = "$baseDir/securemyemail.pl";
$mailprogram = "/usr/sbin/sendmail";
$mailpurge = 30; # Mail purging after
$mailtemplate_in_template = "$baseDir/mailtemplate_in.html";
$daily_report_in_template = "$baseDir/daily_report_in.html";
$accept_acknowledgment_template = "$baseDir/accept_acknowledgment.html";
$varqmail = '/var/qmail';
$qmailUsersDir = "/var/qmail/users";
$qmailDir = "/var/qmail/mailnames";
$qmailuserslist = '/var/qmail/users/assign';
$quarantine_pl = "$baseDir/eighteen_quarantine.pl";
$eighteen_check_mail_2 = "$baseDir/eighteen_check_mail_2.pl";
$quarantinemailDir = "$qmailDir/quarantine";
$quarantinemailDirTmp = "$qmailDir/quarantine/tmp";
$saThreshold = 7;  # Default SA score to reject mails
$n1_ignored_threshold = 3; # UCEs ignored. Push to Daily Alert
$n2_ignored_threshold = 6; # UCEs ignored. Don't alert at all
$tmpDir = "/tmp";     # Temp mail files and cookies
$n_evaluationDays = 7; 
$n_learnModeDays = 30;
$monitorcycle = 0;
$monitorRefreshCycles = 10; # update the `monitor` table to say that I am alive
$subjectThreshold = 3; # max number of Subject lines before sending to Daily Alert
$dr_threshold = 50; # Max lines to be included in any category in daily_report.
#action Codes
$incomingcode	=	1000	;	#	Every incoming mail gets it

$alertedcode	=	1001	;	#	'More possibly legitimate emails',
$dailyalertedcode	=	1002	;	#	'Likely to be legitimate emails',
$dailyreportcode	=	1003	;	#	'Likely to be spam, but could not be discarded.',
$challengedcode	=	1004	;	#	'Challenge sent to sender',
$cleanmailcode	=	1005	;	#	'Sender is on accepted list. Mail forwarded',
$forwardedinlmodecode	=	1006	;	#	'Mostly legitimate emails. Forwarded in training mode',
$forwardedbyAlertcode	=	1007	;	#	'Accepted from Alert. Mail forwarded',
$forwardedbyChallengecode	=	1008	;	#	'Accepted from Challenge. Mail forwarded',
$blacklistcode	=	1009	;	#	'Sender is in black list. Deleted',
$viruscode	=	1010	;	#	'Mail contained a virus. Deleted',
$spamassasincode	=	1011	;	#	'Mail above Spam Threshold. Deleted',
$invalidSenderEmailcode	=	1012	;	#	'Invalid email address. Deleted',
$invalidHelocode	=	1013	;	#	'Invalid HELO field in header. Deleted',
$foreignSubjectcode	=	1014	;	#	'Foreign subject Spam. Deleted',
$deletedByHeuristicscode	=	1015	;	#	'Deleted by heuristics',

#$quarantinecode	=	1015	;	#	Added to Quarantine Tray
$blockedSubjectcode = 1016;

#$localDomains = '|webgenie.com|winiger.com|';
1;

