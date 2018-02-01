#!/usr/local/bin/perl
sub do_main
{
    use Mail::SPF;
    
    my $spf_server  = Mail::SPF::Server->new();
    
    my $request     = Mail::SPF::Request->new(
        versions        => [1, 2],              # optional
        scope           => 'mfrom',             # or 'helo', 'pra'
        identity        => 'asivapra@hotmail.com',
        ip_address      => '211.85.222.190',
#        helo_identity   => 'mta.example.com'    # optional,
                                                #   for %{h} macro expansion
    );
    
    my $result      = $spf_server->process($request);
    
    print("$result\n");
    my $result_code     = $result->code;        # 'pass', 'fail', etc.
    my $local_exp       = $result->local_explanation;
    my $authority_exp   = $result->authority_explanation
        if $result->is_code('fail');
    my $spf_header      = $result->received_spf_header;
print "$result_code; $local_exp; $authority_exp; $spf_header;";	
}
$|=1;
&do_main;

