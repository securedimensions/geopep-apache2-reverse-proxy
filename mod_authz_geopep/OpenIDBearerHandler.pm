# Secure Dimensions licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright 2017-2018 Secure Dimensions GmbH

package SD::OpenIDBearerHandler;

use strict;
use warnings;

use Apache2::Request();
use Apache2::RequestRec();
use Apache2::RequestUtil();
use Apache2::Log();
use APR::Table ();
use Apache2::Const -compile => qw(OK AUTH_REQUIRED HTTP_INTERNAL_SERVER_ERROR FORBIDDEN);
use HTTP::Request::Common;
#use LWP::UserAgent;
use WWW::Curl::Easy;
use JSON qw( decode_json );
use MIME::Base64 qw(decode_base64 encode_base64);
use URI::Escape qw(uri_escape uri_unescape);
use LWP::Protocol::https;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );

use Cache::Memcached;
use Data::Dumper;

my $cache = new Cache::Memcached {
    'servers' => ["127.0.0.1:11211"],
    'debug' => 0,
    'compress_threshold' => 10_000,
};

sub handler {

	my $r = Apache2::Request->new(shift);
	my $log = $r->log;
	no strict 'refs';
	
	#client_id and secret for appliction 
	my $client_id        = $r->dir_config('ClientId');
	my $client_secret    = $r->dir_config('ClientSecret');
	my $validate_url     = $r->dir_config('ValidateURL');
	my $userinfo_url     = $r->dir_config('UserinfoURL');
	$log->debug("ClientId ", $client_id);
	$log->debug("ClientSecret ", $client_secret);
	$log->debug("ValidateURL ", $validate_url);
	$log->debug("UserinfoURL ", $userinfo_url);
		
	# Keep Apache 2.4 mod_authz_core happy
	$r->user("");

	# Let's check if we got a an access_token as HTTP header...
	my $access_token = $r->headers_in->{'Authorization'};
	if (defined $access_token)
	{
		$access_token =~ s/Bearer //;
		$log->debug("access_token from HTTP Authorization header: ", $access_token);	
	}
		
	# Let's check if we got a an access_token as query parameter...
	if (not defined $access_token)
	{
		$access_token = $r->param('access_token');
        if (defined $access_token)
        {
		    $log->debug("access_token from query string: ", $access_token);
        }
	}
		
	if (not defined $access_token)
	{
        # https://tools.ietf.org/html/rfc6750#page-9 section 3.1 Error Codes
        # If the request lacks any authentication information (e.g., the client
        # was unaware that authentication is necessary or attempted using an
        # unsupported authentication method), the resource server SHOULD NOT
        # include an error code or other error information.
        $log->debug("No access token");
		$r->err_headers_out->set("WWW-Authenticate" => 'Bearer realm="protected resources", error_description="Access Token missing"');
		return Apache2::Const::AUTH_REQUIRED;
	}
	
	# First: Check access token validity (make sure the user has not revoked it)
        my $basic_auth = encode_base64($client_id . ':' . $client_secret);
	
	my $curl = WWW::Curl::Easy->new;
	my $url = $validate_url . '?token=' . $access_token;
	my $res;
	my @headers  = ("Authorization: Basic ZmEwMGVmNGYtMTQzZC1kYTUzLWM4MTQtYWMxODY2ZDU5MmM1QG9nYy5zZWN1cmUtZGltZW5zaW9ucy5jb206YjBkZWM0Zjg1MzI3YzlhZjgwZjk2NjlmMGM4Zjk2NmViYzNmZmFhMGY1YzU2YzI0NGJhYzc2ODAyZDZiYTllZg==");
	$curl->setopt(CURLOPT_URL, $url);
	$curl->setopt(CURLOPT_PORT , 443);
	$curl->setopt(CURLOPT_VERBOSE, 0);
	$curl->setopt(CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1_2);
	$curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
	$curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
	$curl->setopt(CURLOPT_HTTPHEADER, \@headers);
	$curl->setopt(CURLOPT_HEADER, 0);

	$curl->setopt(CURLOPT_WRITEDATA,\$res);

	$log->debug("sending token validation request: ". $url);
	my $status_code = $curl->perform;

	$log->debug("tokeninfo status " . $status_code);
	$log->debug("tokeninfo response: " . $res);

	$curl = 0;
	if ($status_code == 0)
	{
		my $json_decoded = decode_json($res);
		$log->debug("Response active: ", $json_decoded->{'active'});

		if($json_decoded->{'active'} eq 'true') {
			$log->info("access token is valid");
            my $ret = $cache->set($access_token, $json_decoded, $json_decoded->{'expires'});
            $log->debug("memcached set returned: " . $ret);
		}
		else {
            # https://tools.ietf.org/html/rfc6750#page-9 section 3.1 Error Codes
            # invalid_token
            # The access token provided is expired, revoked, malformed, or
            # invalid for other reasons.  The resource SHOULD respond with
            # the HTTP 401 (Unauthorized) status code.  The client MAY
            # request a new access token and retry the protected resource
            # request.
            $log->error("access token is NOT valid: ".$access_token);
            $r->err_headers_out->set("WWW-Authenticate" => 'Bearer realm="protected resources", error="invalid_token", error_description="Access Token invalid"');
            $r->status_line("401 Access Token invalid");
            return Apache2::Const::AUTH_REQUIRED;
        }
	}	
	elsif ($res->code() eq 404)
	{
		$log->error("AS validate URL does not exist: " . $validate_url);
                $r->err_headers_out->set("WWW-Authenticate" => 'Bearer realm="protected resources", error="invalid_token", error_description="Access Token invalid"');
                $r->status_line("401 Access Token invalid");
                return Apache2::Const::AUTH_REQUIRED;
	
	}
	else {
		$log->error("access token is NOT valid: ".$access_token);
		$r->err_headers_out->set("WWW-Authenticate" => 'Bearer realm="protected resources", error="invalid_token", error_description="Access Token invalid"');
                $r->status_line("401 Access Token invalid");
		return Apache2::Const::AUTH_REQUIRED;
	} 
	

    my $userinfo = $cache->get($access_token);
    if (undef != $userinfo)
    {
        $log->debug("user claims from memcached: " . Dumper(\$userinfo));
        if($userinfo->{'sub'})
        {
	    $log->debug("subject-id ", $userinfo->{'sub'});
            $r->subprocess_env('subject-id', $userinfo->{'sub'});
            $r->subprocess_env('subject-clearance', $userinfo->{'subject_clearance'});
            $r->subprocess_env('public-key', $userinfo->{'public_key'});
            #Set the remote user
            $r->user($userinfo->{'sub'});
            return Apache2::Const::OK;
        }
        else
        {
            $r->user("");
        }
    }

	# Second: Request (all) user attributes (which the IdP will provide for scope openid)

        $curl = WWW::Curl::Easy->new;
        $url = $userinfo_url;
        my $user_info;
        @headers  = ("Authorization: Bearer " . $access_token );
        $curl->setopt(CURLOPT_URL, $url);
        $curl->setopt(CURLOPT_PORT , 443);
        $curl->setopt(CURLOPT_VERBOSE, 0);
        $curl->setopt(CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1_2);
        $curl->setopt(CURLOPT_SSL_VERIFYHOST, 0);
        $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);
        $curl->setopt(CURLOPT_HTTPHEADER, \@headers);
        $curl->setopt(CURLOPT_HEADER, 0);

        $curl->setopt(CURLOPT_WRITEDATA,\$user_info);

	my $curlf = new WWW::Curl::Form();
	$curlf->formadd('client_id',$client_id);
    	$curlf->formadd('client_secret',$client_secret);
	$curl->setopt(CURLOPT_HTTPPOST, $curlf);

        $log->debug("sending userinfo request: ". $url);
        $status_code = $curl->perform;

        $log->debug("userinfo status " . $status_code);
        $log->debug("userinfo response: " . $user_info);

	$curl = 0;
	if ($status_code == 0) {
		$log->debug("Received attribute statement: ", $user_info);
		my $json_decoded = decode_json($user_info);
		$log->debug("subject-id ", $json_decoded->{'sub'});
        	$r->subprocess_env('subject-id', $json_decoded->{'sub'});
        	$r->subprocess_env('subject-clearance', $json_decoded->{'subject_clearance'});
        	$r->subprocess_env('public-key', $json_decoded->{'public_key'});
        	#Set the remote user
        	$r->user($json_decoded->{'sub'});
        	#Set CORS headers
        	$r->headers_out->set("Access-Control-Allow-Origin" => $r->headers_in->{'Origin'});
        	$r->headers_out->set("Access-Control-Allow-Credentials" => "true");
		return Apache2::Const::OK;
	}
	else {
		$log->debug("HTTP GET error code: ", $res->code);
		$log->debug("HTTP GET error message: ", $res->message);
		return Apache2::Const::FORBIDDEN;
	} 
}
1;
