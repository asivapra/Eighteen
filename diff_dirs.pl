# diff_dirs.pl for the webgenie.com (209.239.112.110)
$gmailaddress = 'asivapra@gmail.com';
$gmailCleanAddress = 'gmail@webgenie.com';
$noreplyEmail = 'noreply@webgenie.com	';
$binDir = "/usr/local/bin/SecureMyEmail/Eighteen"; # WG server
$msgIDprefix = "209.239.112.136"; # This gets added to the beginning of Message-Id of clean mails. It will be used by Gmail to keep the mail in Inbox

$cgiURL = "/cgi-bin/SecureMyEmail/securemyemail.cgi"; 
$baseDir = "/usr/local/bin/SecureMyEmail/Eighteen";
$Owner_name    = "WebGenie Software Pty Ltd";
$baseURL = "http://www.webgenie.com";

$Owner_email='support@webgenie.com';
$Enquiry_email = 'support@webgenie.com';
$Admin_email = 'avs@webgenie.com'; # Gets the notifications from control.pl
$noreplyEmail = 'noreply@webgenie.com';
$simulateRecipientEmail = 'avs@webgenie.com';
$simulatesenderEmail = 'avs@webgenie.com';

$database = "securemyemail"; # on WG server
$dbuser="avs";
$dbpassword="2Kenooch";
$simulateHelo = 'webgenie.com';
$digProgram = "/usr/bin/dig";
$whoisProgram = "/usr/bin/whois";
$nslookupProgram = "/usr/bin/nslookup";
$wg_domain = "webgenie.com";
$wg_mbox = "gmail";
#$pleskURL = "https://balder554.startdedicated.com:8443/";
#$mailFwdhelpURL = "http://www.webgeniemail.com/help/";
#$mxdomain = "smtp.webgeniemail.com";
#$webmail_URL = "http://webmail.webgeniemail.com/horde/imp/login.php";
$Reseller = "WebGenie";  # DEfault
$tagline1 = "SecureMyEmail - Complete Email Security & Deliverability. No Spam, No False Positives!";
$tagline2 = "New Generation Email Authentication Technology";

#cpan installations required
#Net::Telnet
#Net::Whois::IP
#Net::DNS::Resolver

#Daemons to be manually started
#/usr/sbin/spamd&  (Run this once or as  "./eighteen_control.pl spamd')
#/usr/bin/clamscan (no need to run this in daemon mode. It is called when needed)
#/usr/bin/spamc (no need to run this in daemon mode. It is called when needed)
#/usr/bin/freshclam -d --quiet
#External programs to be installed
#spamd
#clamav
#	apt-get update
#	apt-get install clamav

#---------------------------------------
#Explanation of codes
#quarantine: notify=0 means put into daily alert
#quarantine: notify=1 means put into normal alert
#quarantine: notify=2 means normal alerted
#quarantine: notify=3 means daily alerted
#quarantine: notify=4 means forwarded as in Training Mode (also set accept_method=L, delivered=2)
#quarantine: notify=5 means accepted and forwarded (alse set delivered=2)

#---------------------------------------
#Logics
#CheckIPlocations
#If a known user, but wrong IP: knownuser = -1
#If knownuser = -1 and sascore < threshold, there is no CheckIPlocations. The notify=1
#If Env and MX are in separate countries, check &WeedOutSpam. Returns notify = -1 if the Env country is listed (RU, RO, etc)

#CheckDomainValidity
#Inavlid domains are not alerted. notify = -1
1;

