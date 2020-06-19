#!/usr/bin/env perl
# Created on 15 Jun, 2020
# Last edit: 15 Jun, 2020
# By Dr. Arapaut V. Sivaprasad
=pod
This CGI is for creating the Image URL for 'Mail Opened Check'
=cut
# -----------------------------------
require "/var/www/vhosts/webgenie.com/cgi-bin/debug.pl";
use DBI;
use CGI;
$query = new CGI;
sub reformat
{
  local($tmp) = $_[0] ;
  $tmp =~ s/\+/ /g ;
  while ($tmp =~ /%([0-9A-Fa-f][0-9A-Fa-f])/)
  {
   $num = $1;
   $dec = hex($num);
   $chr = pack("c",$dec);
   $chr =~ s/&/and/g;  # Replace if it is the & char.
   $tmp =~ s/%$num/$chr/g;
  }
  return($tmp);
}
sub Get_fields
{
   my @pquery = split(/\&/, $pquery);
   for my $item (@pquery)
   {
           if ($item =~ /(.*)=(.*)/i)
           {
                $$1 = $2; 
           }
   }
}

sub ConnectToDBase
{
$driver = "mysql";
$hostname = "localhost";
$database = "mailopened"; 
$dbuser="avs";
$dbpassword='2Kenooch';
   $dsn = "DBI:$driver:database=$database;host=$hostname";
   $dbh = DBI->connect($dsn, $dbuser, $dbpassword);
   $drh = DBI->install_driver("mysql");
}

sub execute_query
{
	$sth=$dbh->prepare($query);
	$rv = $sth->execute or die "can't execute the query: $sth->errstr";
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

sub CreateImageLink
{
	my $to_address = $_[0];
	$random = &GetRandomChars(9);
	my $img_url = $baseURL . "?" . $random . "+" . $to_address;
	return $img_url;
}

sub Get_Cookie
{
	$theCookie = $query->cookie('MOC');
	my @fields = split(/\|/, $theCookie);
	$User_email = $fields[0];
	$User_ID = $fields[1];
#print $theCookie;	
}
sub Add_Address
{
	&ConnectToDBase;
	$query = "replace into `addresses` (user_id, to_address) values ('$User_ID', '$to_address')";
	&execute_query($query);
	$dbh->disconnect;
}

sub do_main
{
#&debugEnv;	
	# Kill a runaway CGI, if any.
	my $psline = `ps -ef | grep moc.cgi | grep -v grep`;
	my @fields = split (/\s/, $psline);
	$pid = $fields[1];
	my $thispid = $$;
	if ($pid && $pid ne $thispid) { `kill $pid`; }

	my $cl = $ENV{'CONTENT_LENGTH'}; # Method=POST will have a non-zero value.
	$cl //= 0; # Set the value as 0 if $cl is undefined. It won't happen on a well built Apache server.
	if ($cl > 0)
	{
		read(STDIN, $_, $cl);
		$_ .= "&"; # Append an & char so that the last item is not ignored
		$pquery = &reformat($_);
		print "Content-type: text/html\n\n"; $headerAdded = 1;
	}
	else
	{
		$sc_action = $ARGV[0];
		&Get_fields;	# Parse the $pquery to get all form input values
		if (!$sc_action)
		{
			$dumb = 1; # This is a dumb URL with &BBOX=0,0,0,0 added at the end.
			$request_string = $ENV{QUERY_STRING};
			@fields = split (/\&/, $request_string);
			$sc_action = $fields[0];
			@fields = split (/\+/, $sc_action);
			$sc_action = $fields[0];
		}
		if ($sc_action eq "MOC")
		{
			print "Content-type: text/html\n\n"; $headerAdded = 1;
			$pquery = reformat($ARGV[2]);
			$pquery =~ s/\\//gi;
			&Get_fields;	# Parse the $pquery to get all form input values
			&Get_Cookie; # Get the user_email and user_id
			&Add_Address; # Add this address to the 'to_address' column in 'addresses'
			$img_url = &CreateImageLink($to_address);
			print "$img_url\n";
			exit;
		}
		if ($sc_action eq "login")
		{
			$User_email = $ARGV[2];
			$Password = $ARGV[3];
			print "Content-type: text/html\n\n"; $headerAdded = 1;
			&ConnectToDBase;
			$query = "select user_id,firstname,lastname from `users` where user_email='$User_email' and password='$Password' limit 0,1";
			&execute_query($query);
			my @results = &Fetchrow_array(3);
			$user_id = $results[0];
			$firstname = $results[1];
			$lastname = $results[2];
			$dbh->disconnect;
			if ($user_id)
			{
				print "$user_id|$firstname|$lastname|"; 
			}
			else
			{
				print "";
			}
		}
		if ($sc_action eq "addresses")
		{
			$user_id = $ARGV[2];
			print "Content-type: text/html\n\n"; $headerAdded = 1;
			&ConnectToDBase;
			$query = "select to_address from `addresses` where user_id='$user_id'";
			&execute_query($query);
			my @results = &Fetchrow_array(1);
			my $len = $#results;
			$list = "";
			if ($len >= 0) { $list = "<option value=\"\">Type in above or choose an address below</option>\n"; }
			for (my $j=0; $j <= $len; $j++)
			{
				$list .= "<option value=\"$results[$j]\">$results[$j]</option>\n";	
			}
			print $list;
		}
		else
		{
			&debug("Warning: sc_action not found!");
		}
	}
}
$|=1;
$ct0 = time();
$baseURL = "https://www.webgenie.com/img/mail/avs123456789.png";
$ProcessTime = `/bin/date`; $ProcessTime =~ s/\n//g ;
&do_main;
#https://www.webgenie.com/img/mail/avs123456789.png?lZImV8ZRbP+avs_webgenie_com@me.com
#CREATE TABLE `mails` (`id` int(4) NOT NULL AUTO_INCREMENT,  `user_id` varchar(30) NOT NULL DEFAULT '', `rand` varchar(30) NOT NULL DEFAULT '', `to_address` varchar(50) NOT NULL DEFAULT '', `sent_time` bool default null, `opened_time` varchar(30) NOT NULL DEFAULT '',  `ip` varchar(15) NOT NULL DEFAULT '', `status` int(1) DEFAULT '1',  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
#CREATE TABLE `users` (  `id` int(4) NOT NULL AUTO_INCREMENT,  `user_id` varchar(30) NOT NULL DEFAULT '',  `firstname` varchar(30) DEFAULT NULL,  `lastname` varchar(30) DEFAULT NULL,  `user_email` varchar(30) NOT NULL DEFAULT '',  `password` varchar(30) NOT NULL DEFAULT '',  `status` int(1) DEFAULT '1',  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,  PRIMARY KEY (`user_id`),  KEY `id` (`id`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1; 
#CREATE TABLE `addresses` (  `id` int(4) NOT NULL AUTO_INCREMENT,  `user_id` varchar(30) NOT NULL DEFAULT '',  `to_address` varchar(30) NOT NULL DEFAULT '',  `status` int(1) DEFAULT '1',  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,  PRIMARY KEY (`user_id`, `to_address`),  KEY `id` (`id`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1; 

#insert into `users` (user_id, user_email, password) values ('avs123456799', 'avs2904@webgenie.com', 'test12345');
#insert into `mails` (user_id, rand, to_address, opened_time, ip) values ('avs123456789', '123456781', 'avs_webgenie_com@me.com', 'Jun/12/2020:13:20:45', '49.195.91.51');

