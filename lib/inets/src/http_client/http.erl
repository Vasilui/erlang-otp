% ``The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% The Initial Developer of the Original Code is Ericsson Utvecklings AB.
%% Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
%% AB. All Rights Reserved.''
%% 
%%     $Id$
%%
%% Description:
%%% This version of the HTTP/1.1 client supports:
%%%      - RFC 2616 HTTP 1.1 client part
%%%      - RFC 2818 HTTP Over TLS

-module(http).
-behaviour(inets_service).

%% API
-export([request/1, request/2, request/4, request/5,
	 cancel_request/1, cancel_request/2,
	 set_options/1, set_options/2,
	 verify_cookies/2, verify_cookies/3, cookie_header/1, 
	 cookie_header/2, stream_next/1]).

%% Behavior callbacks
-export([start_standalone/1, start_service/1, 
	 stop_service/1, services/0, service_info/1]).

-include("http_internal.hrl").
-include("httpc_internal.hrl").

%%%=========================================================================
%%%  API
%%%=========================================================================

%%--------------------------------------------------------------------------
%% request(Url [, Profile]) ->
%%           {ok, {StatusLine, Headers, Body}} | {error,Reason} 
%%
%%	Url - string() 
%% Description: Calls request/4 with default values.
%%--------------------------------------------------------------------------
request(Url) ->
    request(Url, default).

request(Url, Profile) ->
    request(get, {Url, []}, [], [], Profile).

%%--------------------------------------------------------------------------
%% request(Method, Request, HTTPOptions, Options [, Profile]) ->
%%           {ok, {StatusLine, Headers, Body}} | {ok, {Status, Body}} |
%%           {ok, RequestId} | {error,Reason} | {ok, {saved_as, FilePath}
%%
%%	Method - atom() = head | get | put | post | trace | options| delete 
%%	Request - {Url, Headers} | {Url, Headers, ContentType, Body} 
%%	Url - string() 
%%	HTTPOptions - [HttpOption]
%%	HTTPOption - {timeout, Time} | {ssl, SSLOptions} | 
%%                   {proxy_auth, {User, Password}}
%%	Ssloptions = [SSLOption]
%%	SSLOption =  {verify, code()} | {depth, depth()} | {certfile, path()} |
%%	{keyfile, path()} | {password, string()} | {cacertfile, path()} |
%%	{ciphers, string()} 
%%	Options - [Option]
%%	Option - {sync, Boolean} | {body_format, BodyFormat} | 
%%	{full_result, Boolean} | {stream, To} |
%%      {headers_as_is, Boolean}  
%%	StatusLine = {HTTPVersion, StatusCode, ReasonPhrase}</v>
%%	HTTPVersion = string()
%%	StatusCode = integer()
%%	ReasonPhrase = string()
%%	Headers = [Header]
%%      Header = {Field, Value}
%%	Field = string()
%%	Value = string()
%%	Body = string() | binary() - HTLM-code
%%
%% Description: Sends a HTTP-request. The function can be both
%% syncronus and asynchronous in the later case the function will
%% return {ok, RequestId} and later on a message will be sent to the
%% calling process on the format {http, {RequestId, {StatusLine,
%% Headers, Body}}} or {http, {RequestId, {error, Reason}}}
%%--------------------------------------------------------------------------

request(Method, Request, HttpOptions, Options) ->
    request(Method, Request, HttpOptions, Options, default). 

request(Method, {Url, Headers}, HTTPOptions, Options, Profile) 
  when Method==options;Method==get;Method==head;Method==delete;Method==trace ->
    case http_uri:parse(Url) of
	{error,Reason} ->
	    {error,Reason};
	ParsedUrl ->
	    handle_request(Method, Url, {ParsedUrl, Headers, [], []}, 
			   HTTPOptions, Options, Profile)
    end;
     
request(Method, {Url,Headers,ContentType,Body}, HTTPOptions, Options, Profile) 
  when Method==post;Method==put ->
    case http_uri:parse(Url) of
	{error,Reason} ->
	    {error,Reason};
	ParsedUrl ->
	    handle_request(Method, Url, 
			   {ParsedUrl, Headers, ContentType, Body}, 
			   HTTPOptions, Options, Profile)
    end.

%%--------------------------------------------------------------------------
%% request(RequestId) -> ok
%%   RequestId - As returned by request/4  
%%                                 
%% Description: Cancels a HTTP-request.
%%-------------------------------------------------------------------------
cancel_request(RequestId) ->
    cancel_request(RequestId, default).

cancel_request(RequestId, Profile) ->
    ok = httpc_manager:cancel_request(RequestId, profile_name(Profile)), 
    receive  
	%% If the request was allready fullfilled throw away the 
	%% answer as the request has been canceled.
	{http, {RequestId, _}} ->
	    ok 
    after 0 ->
	    ok
    end.

%%--------------------------------------------------------------------------
%% set_options(Options [, Profile]) -> ok | {error, Reason}
%%   Options - [Option]
%%   Profile - atom()
%%   Option - {proxy, {Proxy, NoProxy}} | {max_sessions, MaxSessions} | 
%%            {max_pipeline_length, MaxPipeline} | 
%%            {pipeline_timeout, PipelineTimeout} | {cookies, CookieMode}
%%            | {ipv6, Ipv6Mode}
%%   Proxy - {Host, Port}
%%   NoProxy - [Domain | HostName | IPAddress]   
%%   MaxSessions, MaxPipeline, PipelineTimeout = integer()   
%%   CookieMode - enabled | disabled | verify
%%   Ipv6Mode - enabled | disabled
%% Description: Informs the httpc_manager of the new settings. 
%%-------------------------------------------------------------------------
set_options(Options) ->
    set_options(Options, default).
set_options(Options, Profile) ->
    case validate_options(Options) of
	ok ->
	    try httpc_manager:set_options(Options, profile_name(Profile)) of
		Result ->
		    Result
	    catch
		exit:{noproc, _} ->
		    {error, inets_not_started}
	    end;
	{error, Reason} ->
	    {error, Reason}
    end.

%%--------------------------------------------------------------------------
%% verify_cookies(SetCookieHeaders, Url [, Profile]) -> ok | {error, reason} 
%%   
%%                                 
%% Description: 
%%-------------------------------------------------------------------------
verify_cookies(SetCookieHeaders, Url) ->
    verify_cookies(SetCookieHeaders, Url, default).

verify_cookies(SetCookieHeaders, Url, Profile) ->
    {_, _, Host, Port, Path, _} = http_uri:parse(Url),
    ProfileName = profile_name(Profile),
    Cookies = http_cookie:cookies(SetCookieHeaders, Path, Host),
    try httpc_manager:store_cookies(Cookies, {Host, Port}, ProfileName) of
	_ ->
	    ok
    catch 
	exit:{noproc, _} ->
	    {error, {not_started, Profile}}
    end.

%%--------------------------------------------------------------------------
%% cookie_header(Url [, Profile]) -> Header | {error, Reason}
%%               
%% Description: Returns the cookie header that would be sent when making
%% a request to <Url>.
%%-------------------------------------------------------------------------
cookie_header(Url) ->
    cookie_header(Url, default).

cookie_header(Url, Profile) ->
    try httpc_manager:cookies(Url, profile_name(Profile)) of
	Header ->
	    Header
    catch 
	exit:{noproc, _} ->
	    {error, {not_started, Profile}}
    end.


stream_next(Pid) ->
    httpc_handler:stream_next(Pid).

%%%========================================================================
%%% Behavior callbacks
%%%========================================================================
start_standalone(PropList) ->
    case proplists:get_value(profile, PropList) of
	undefined ->
	    {error, no_profile};
	Profile ->
	    Dir = 
		proplists:get_value(data_dir, PropList, only_session_cookies),
	    httpc_manager:start_link({Profile, Dir}, stand_alone)
    end.

start_service(Config) ->
    httpc_profile_sup:start_child(Config).

stop_service(Profile) when is_atom(Profile) ->
    httpc_profile_sup:stop_child(Profile);
stop_service(Pid) when is_pid(Pid) ->
    case service_info(Pid) of
	{ok, [{profile, Profile}]} ->
	    stop_service(Profile);
	Error ->
	    Error
    end.

services() ->
    [{httpc, Pid} || {_, Pid, _, _} <- 
			supervisor:which_children(httpc_profile_sup)].
service_info(Pid) ->
    try [{ChildName, ChildPid} || 
	    {ChildName, ChildPid, _, _} <- 
		supervisor:which_children(httpc_profile_sup)] of
	Children ->
	    child_name2info(child_name(Pid, Children))
    catch
	exit:{noproc, _} ->
	    {error, service_not_available} 
    end.

%%%========================================================================
%%% Internal functions
%%%========================================================================
handle_request(Method, Url, {{Scheme, UserInfo, Host, Port, Path, Query},
			Headers, ContentType, Body}, 
	       HTTPOptions, Options, Profile) ->
    HTTPRecordOptions = http_options(HTTPOptions, #http_options{}),
    
    Sync = proplists:get_value(sync, Options, true),
    NewHeaders = lists:map(fun({Key, Val}) -> 
				   {http_util:to_lower(Key), Val} end,
			   Headers),
    Stream = proplists:get_value(stream, Options, none),

    case {Sync, Stream} of
	{true, self} ->
	    {error, streaming_error};
	_ ->
	    RecordHeaders = header_record(NewHeaders, #http_request_h{}, 
					  Host),
	    Request = #request{from = self(),
			       scheme = Scheme, address = {Host,Port},
			       path = Path, pquery = Query, method = Method,
			       headers = RecordHeaders, 
			       content = {ContentType,Body},
			       settings = HTTPRecordOptions,
			       abs_uri = Url, userinfo = UserInfo, 
			       stream = Stream, 
			       headers_as_is = 
			       headers_as_is(Headers, Options)},
	    
	    
	    try httpc_manager:request(Request, profile_name(Profile)) of
		{ok, RequestId} ->
		    handle_answer(RequestId, Sync, Options);
		{error, Reason} ->
		    {error, Reason}
	    catch
		error:{noproc, _} ->
		    {error, {not_started, Profile}}
	    end
    end.

handle_answer(RequestId, false, _) ->
    {ok, RequestId};
handle_answer(RequestId, true, Options) ->
    receive
	{http, {RequestId, saved_to_file}} ->
	    {ok, saved_to_file};
	{http, {RequestId, Result = {_,_,_}}} ->
	    return_answer(Options, Result);
	{http, {RequestId, {error, Reason}}} ->
	    {error, Reason}
    end.
 
return_answer(Options, {StatusLine, Headers, BinBody}) ->
    Body = 
	case proplists:get_value(body_format, Options, string) of
	    string ->
		binary_to_list(BinBody);
	    _ ->
		BinBody
	end,
    case proplists:get_value(full_result, Options, true) of
	true ->
	    {ok, {StatusLine, Headers, Body}};
	false ->
	    {_, Status, _} = StatusLine,
	    {ok, {Status, Body}}
    end.


%% This options is a workaround for http servers that do not follow the 
%% http standard and have case sensative header parsing. Should only be
%% used if there is no other way to communicate with the server or for
%% testing purpose.
headers_as_is(Headers, Options) ->
     case proplists:get_value(headers_as_is, Options, false) of
	 false ->
	     [];
	 true  ->
	     Headers
     end.

http_options([], Acc) ->
    Acc;
http_options([{timeout, Val} | Settings], Acc) 
  when is_integer(Val), Val >= 0->
    http_options(Settings, Acc#http_options{timeout = Val});
http_options([{timeout, infinity} | Settings], Acc) ->
    http_options(Settings, Acc#http_options{timeout = infinity});
http_options([{autoredirect, Val} | Settings], Acc)   
  when Val == true; Val == false ->
    http_options(Settings, Acc#http_options{autoredirect = Val});
http_options([{ssl, Val} | Settings], Acc) ->
    http_options(Settings, Acc#http_options{ssl = Val});
http_options([{relaxed, Val} | Settings], Acc)
  when Val == true; Val == false ->
    http_options(Settings, Acc#http_options{relaxed = Val});
http_options([{proxy_auth, Val = {User, Passwd}} | Settings], Acc) 
  when is_list(User),
       is_list(Passwd) ->
    http_options(Settings, Acc#http_options{proxy_auth = Val});
http_options([Option | Settings], Acc) ->
    error_logger:info_report("Invalid option ignored ~p~n", [Option]),
    http_options(Settings, Acc).

validate_options([]) ->
    ok;
validate_options([{proxy, {{ProxyHost, ProxyPort}, NoProxy}}| Tail]) when
		 is_list(ProxyHost), is_integer(ProxyPort), 
		 is_list(NoProxy) ->
    validate_options(Tail);
validate_options([{pipeline_timeout, Value}| Tail]) when is_integer(Value) ->
    validate_options(Tail);
validate_options([{max_pipeline_length, Value}| Tail]) 
  when is_integer(Value) ->
    validate_options(Tail);
validate_options([{max_sessions, Value}| Tail]) when is_integer(Value) ->
    validate_options(Tail);
validate_options([{cookies, Value}| Tail]) 
  when Value == enabled; Value == disabled; Value == verify ->
    validate_options(Tail);
validate_options([{ipv6, Value}| Tail]) 
  when Value == enabled; Value == disabled ->
    validate_options(Tail);
validate_options([{verbose, Value}| Tail]) when Value == false;
						Value == verbose;
						Value == debug;
						Value == trace ->
    validate_options(Tail);
validate_options([{_, _} = Opt| _]) ->
    {error, {not_an_option, Opt}}.

header_record([], RequestHeaders, Host) ->
    validate_headers(RequestHeaders, Host);
header_record([{"cache-control", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'cache-control' = Val},
		  Host);  
header_record([{"connection", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{connection = Val}, Host);
header_record([{"date", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{date = Val}, Host);  
header_record([{"pragma", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{pragma = Val}, Host);  
header_record([{"trailer", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{trailer = Val}, Host);  
header_record([{"transfer-encoding", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, 
		  RequestHeaders#http_request_h{'transfer-encoding' = Val},
		  Host);  
header_record([{"upgrade", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{upgrade = Val}, Host);  
header_record([{"via", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{via = Val}, Host);  
header_record([{"warning", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{warning = Val}, Host);  
header_record([{"accept", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{accept = Val}, Host);  
header_record([{"accept-charset", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'accept-charset' = Val}, 
		  Host);  
header_record([{"accept-encoding", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'accept-encoding' = Val},
		  Host);  
header_record([{"accept-language", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'accept-language' = Val},
		  Host);  
header_record([{"authorization", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{authorization = Val}, 
		  Host);  
header_record([{"expect", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{expect = Val}, Host);
header_record([{"from", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{from = Val}, Host);  
header_record([{"host", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{host = Val}, Host);
header_record([{"if-match", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'if-match' = Val},
		  Host);  
header_record([{"if-modified-since", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, 
		  RequestHeaders#http_request_h{'if-modified-since' = Val},
		  Host);  
header_record([{"if-none-match", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'if-none-match' = Val}, 
		  Host);  
header_record([{"if-range", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'if-range' = Val}, 
		  Host);  

header_record([{"if-unmodified-since", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'if-unmodified-since' 
						      = Val}, Host);  
header_record([{"max-forwards", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'max-forwards' = Val}, 
		  Host);  
header_record([{"proxy-authorization", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'proxy-authorization' 
						      = Val}, Host);  
header_record([{"range", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{range = Val}, Host);  
header_record([{"referer", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{referer = Val}, Host);  
header_record([{"te", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{te = Val}, Host);  
header_record([{"user-agent", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'user-agent' = Val}, 
		  Host);  
header_record([{"allow", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{allow = Val}, Host);  
header_record([{"content-encoding", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, 
		  RequestHeaders#http_request_h{'content-encoding' = Val},
		  Host);  
header_record([{"content-language", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, 
		  RequestHeaders#http_request_h{'content-language' = Val}, 
		  Host);  
header_record([{"content-length", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'content-length' = Val},
		  Host);  
header_record([{"content-location", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, 
		  RequestHeaders#http_request_h{'content-location' = Val},
		  Host);  
header_record([{"content-md5", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'content-md5' = Val}, 
		  Host);  
header_record([{"content-range", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'content-range' = Val},
		  Host);  
header_record([{"content-type", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'content-type' = Val}, 
		  Host);  
header_record([{"expires", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{expires = Val}, Host);  
header_record([{"last-modified", Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{'last-modified' = Val},
		  Host);  
header_record([{Key, Val} | Rest], RequestHeaders, Host) ->
    header_record(Rest, RequestHeaders#http_request_h{
			  other = [{Key, Val} |
				   RequestHeaders#http_request_h.other]}, 
		  Host).

validate_headers(RequestHeaders = #http_request_h{te = undefined}, Host) ->
    validate_headers(RequestHeaders#http_request_h{te = ""}, Host);
validate_headers(RequestHeaders = #http_request_h{host = undefined}, Host) ->
    validate_headers(RequestHeaders#http_request_h{host = Host}, Host);
validate_headers(RequestHeaders, _) ->
    RequestHeaders.

profile_name(default) ->
    httpc_manager;
profile_name(Pid) when is_pid(Pid) ->
    Pid;
profile_name(Profile) ->
    list_to_atom("httpc_manager_" ++ atom_to_list(Profile)).

child_name2info(undefined) ->
    {error, no_such_service};
child_name2info(httpc_manager) ->
    {ok, [{profile, default}]};
child_name2info({http, Profile}) ->
    {ok, [{profile, Profile}]}.

child_name(_, []) ->
    undefined;
child_name(Pid, [{Name, Pid} | _]) ->
    Name;
child_name(Pid, [_ | Children]) ->
    child_name(Pid, Children).

