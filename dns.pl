#!/usr/local/bin/perl
use Net::DNS;
use Net::Whois::IP qw(whoisip_query);
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
sub GetDomainIP
{
  my $domain_name = $_[0];
#print "domain_name = $domain_name\n";  
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->search($domain_name);
  if ($query) 
  {
      foreach my $rr ($query->answer) 
	  {
          next unless $rr->type eq "A";
		  $IP = $rr->address;
#		  &GetLocation($mxIP);
#          print $rr->address, "\n";
		  return $IP;
      }
  } 
  else 
  {
      warn "query failed: ", $res->errorstring, "\n";
	  return "";
  }
#return;  
#print "query = $query\n";  
#	while (my ($k,$v) = each %{$query}) 
#	{
##		if ($k =~ /country/i)
#		{
#print " $k => $v\n";
#		}
#	}
#exit;	
#  if ($query) 
#  {
#      foreach my $rr ($query->answer) 
#	  {
#          next unless $rr->type eq "A";
##print $rr->address, "\n";
#		  return $rr->address;
#      }
#  } 
#  else 
#  {
##warn "query failed: ", $res->errorstring, "\n";
#	  return "No A Record";
#  }
}
sub GetMXdomain
{
  my $domain_name = $_[0];
  my $res  = Net::DNS::Resolver->new;
  my @mx   = mx($res, $domain_name);
  $mxDomain = $mx[0]->exchange;
#print "mxDomain = $mxDomain\n";
#&GetDomainIP($mxDomain);
  return $mxDomain;
#  if (@mx) {
#      foreach $rr (@mx) {
##          print $rr->preference, " ", $rr->exchange, "\n";
#          print $rr->exchange, "\n";
#      }
#  } else {
#      warn "Can't find MX records for $domain_name: ", $res->errorstring, "\n";
#  }
#exit;  
#print "mx = @mx\n";  
#  my $len = $#mx;
#	while (my ($k,$v) = each %{$mx}) 
#	{
##		if ($k =~ /country/i)
#		{
#print " $k => $v\n";
#		}
#	}
#exit;
#  if ($len < 0)
#  {
#print "No MX Record\n";
#	  return "No MX Record";
#  }
#  else
#  {
#print "mx = $mx[0]\n";	  
#	  return $mx[0];
#  }
}
sub GetHostAddress
{
 use Socket;
 	$tlds = "|com|org|net|edu|gov|info|name|club|game|keyword|firm|gen|ind|sch|ebiz|asn|phone|mobi|web|rec|per|store|other|gen|geek|school|maori|nom|asso|biz|waw|";
    $senderDomain = $_[0];
print "1. senderDomain = $senderDomain\n";
	my @parts = split (/\./, $senderDomain);
	my $len0 = $#parts;
	if ($len0 <= 0) { return 0; }
	$packed_ip = gethostbyname($senderDomain);
print "packed_ip = $packed_ip\n";
    if (defined $packed_ip) 
	{
        $ip_address = inet_ntoa($packed_ip);
		return $ip_address;
    }
	else
	{
		shift @parts;
		my $len = $#parts;
		if ($len <= 0) { return 0; }
		if ($len == 1) 
		{
			my @p1 = split (//, $parts[0]);
			my $len1 = $#p1;
			if ($len1 <= 1) 
			{ 
print "2chars\n";
				return 0; # No domain name can have 2 chars 
			} 
			if ($tlds =~ /\|$parts[0]\|/i && $parts[1] !~ /com/i) 
			{ 
print "tlds\n";
				return 0; 
			}
		}
		$senderDomain = join ("\.", @parts);
print "2. senderDomain = $senderDomain\n";
		if ($senderDomain =~ /.*\./)
		{
			return &GetHostAddress($senderDomain);
		}
	}
	return 0;
exit;
}
sub do_main
{
	$senderDomain = $ARGV[0];
	$senderIP = $ARGV[1];
	$domainIP = &GetHostAddress($senderDomain);
print "domainIP = $domainIP\n";	
exit;
	$EnvCountry = &GetLocation($senderIP);
	
print "senderDomain = $senderDomain\n";	
$ct0 = time();
print "ct0 = $ct0\n";
	$mxDomain = &GetMXdomain($senderDomain);
$ct1 = time();
print "ct1 = $ct1\n";
	$mxIP = &GetDomainIP($mxDomain);
$ct2 = time();
print "ct2 = $ct2\n";
	$MxCountry = &GetLocation($mxIP);
$ct3 = time();
print "ct3 = $ct3\n";
print "mxDomain = $mxDomain; EnvCountry = $EnvCountry; MxCountry = $MxCountry\n";	
}
$|=1;
&do_main;

