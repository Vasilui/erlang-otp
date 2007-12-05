%% ``The contents of this file are subject to the Erlang Public License,
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

-module(inets_service).

-export([behaviour_info/1]).

behaviour_info(callbacks) ->
    [{start_standalone,         1}, 
     {start_service,            1},
     {stop_service,             1},
     {services,                 0},
     {service_info,             1}];
behaviour_info(_) ->
    undefined.

%% Starts service stand-alone
%% start_standalone(Config) ->  % {ok, Pid} | {error, Reason}
%%    <service>:start_link(Config).

%% Starts service as part of inets
%% start_service(Config) -> % {ok, Pid} | {error, Reason}
%%    <service_sup>:start_child(Config).
%% Stop service
%% stop_service(Pid) ->  % ok | {error, Reason}   
%%   <service_sup>:stop_child(maybe_map_pid_to_other_ref(Pid)).
%%
%% <service_sup>:stop_child(Ref) ->
%%    Id = id(Ref),
%%    case supervisor:terminate_child(?MODULE, Id) of
%%        ok ->
%%            supervisor:delete_child(?MODULE, Id);
%%        Error ->
%%            Error
%%    end.

%% Returns list of running services. Services started as stand alone
%% are not listed 
%% services() -> % [{Service, Pid}] 
%% Exampel:
%% services() ->
%%   [{httpc, Pid} || {_, Pid, _, _} <- 
%%			supervisor:which_children(httpc_profile_sup)].


%% service_info() -> [{Property, Value}] | {error, Reason}
%% ex: http:service_info() -> [{profile, ProfileName}] 
%%     httpd:service_info() -> [{host, Host}, {port, Port}]
