#!/usr/local/bin/perl
  use Net::Whois::IP qw(whoisip_query);
sub do_main
{
	$ip = $ARGV[0];
my $search_options = 'country'; 
#my ($response,$array_of_responses) = whoisip_query($ip,$optional_multiple_flag,$option_array_of_search_options);
my ($response) = whoisip_query($ip);
#print "response = $response\n";

	while (my ($k,$v) = each %{$response}) 
	{
		if ($k =~ /country/i)
		{
print " $k => $v\n";
		}
	}
#foreach (sort keys(%{$response}) ) 
#{ 
#	print "$_ $response->{$_} \n"; 
#}

}
$|=1;
&do_main;

