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
%%-----------------------------------------------------------------
%% Purpose: Interface to the UDP transport module for Megaco/H.248
%%-----------------------------------------------------------------
-module(megaco_udp).

-include_lib("megaco/include/megaco.hrl").
-include_lib("megaco/src/udp/megaco_udp.hrl").

-record(send_handle, {socket, addr, port}).

%%-----------------------------------------------------------------
%% External exports
%%-----------------------------------------------------------------
-export([
	 start_transport/0,
	 open/2,
	 socket/1,
	 create_send_handle/3,
	 send_message/2,
	 close/1,
	 block/1,
	 unblock/1
	]).

%%-----------------------------------------------------------------
%% Internal exports
%%-----------------------------------------------------------------
-export([]).

%%-----------------------------------------------------------------
%% External interface functions
%%-----------------------------------------------------------------
%%-----------------------------------------------------------------
%% Func: start_transport
%% Description: Starts the UDP transport service
%%-----------------------------------------------------------------
start_transport() ->
    megaco_udp_sup:start_link().

%%-----------------------------------------------------------------
%% Func: open
%% Description: Function is used when opening an UDP socket
%%-----------------------------------------------------------------
open(SupPid, Options) ->
    Mand = [port, receive_handle],
    case parse_options(Options, #megaco_udp{}, Mand) of
	{ok, UdpRec} ->

	    %%------------------------------------------------------
	    %% Setup the socket
	    IpOpts = [binary, {reuseaddr, true}, {active, once} |
		      UdpRec#megaco_udp.options],

	    case catch gen_udp:open(UdpRec#megaco_udp.port, IpOpts) of
		{ok, Socket} ->
		    ?udp_debug(UdpRec, "udp open", []),
		    NewUdpRec = UdpRec#megaco_udp{socket = Socket},
		    case start_udp_server(SupPid, NewUdpRec) of
			{ok, ControlPid} ->
			    gen_udp:controlling_process(Socket, ControlPid),
			    {ok, Socket, ControlPid};
			{error, Reason} ->
			    Error = {error, {could_not_start_udp_server, Reason}},
			    ?udp_debug({socket, Socket}, "udp close", []),
			    gen_udp:close(Socket),
			    Error

		    end;
		{error, Reason} ->
		    Error = {error, {could_not_open_udp_port, Reason}},
		    ?udp_debug(UdpRec, "udp open failed", [Error]),
		    Error
	    end;
	{error, Reason} = Error ->
	    ?udp_debug(#megaco_udp{}, "udp open failed",
		       [Error, {options, Options}]),
	    {error, Reason}
    end.

%%-----------------------------------------------------------------
%% Func: socket
%% Description: Returns the inet socket
%%-----------------------------------------------------------------
socket(SH) when record(SH, send_handle) ->
    SH#send_handle.socket;
socket(Socket) ->
    Socket.

%%-----------------------------------------------------------------
%% Func: create_send_handle
%% Description: Function is used for creating the handle used when 
%%    sending data on the UDP socket
%%-----------------------------------------------------------------
create_send_handle(Socket, Addr, Port) ->
    #send_handle{socket = Socket, addr = Addr, port = Port}.

%%-----------------------------------------------------------------
%% Func: send_message
%% Description: Function is used for sending data on the UDP socket
%%-----------------------------------------------------------------
send_message(SH, Data) when record(SH, send_handle) ->
    #send_handle{socket = Socket, addr = Addr, port = Port} = SH,
    gen_udp:send(Socket, Addr, Port, Data);
send_message(SH, Data) ->
    {error, {bad_send_handle, SH}}.

%%-----------------------------------------------------------------
%% Func: block
%% Description: Function is used for blocking incomming messages
%%              on the TCP socket
%%-----------------------------------------------------------------
block(SH) when record(SH, send_handle) ->
    block(SH#send_handle.socket);
block(Socket) ->
    ?udp_debug({socket, Socket}, "udp block", []),
    inet:setopts(Socket, [{active, false}]).
      
%%-----------------------------------------------------------------
%% Func: unblock
%% Description: Function is used for blocking incomming messages
%%              on the TCP socket
%%-----------------------------------------------------------------
unblock(SH) when record(SH, send_handle) ->
    unblock(SH#send_handle.socket);
unblock(Socket) ->
    ?udp_debug({socket, Socket}, "udp unblock", []),
    inet:setopts(Socket, [{active, once}]).

%%-----------------------------------------------------------------
%% Func: close
%% Description: Function is used for closing the UDP socket
%%-----------------------------------------------------------------
close(SH) when record(SH, send_handle) ->
    close(SH#send_handle.socket);
close(Socket) ->
    ?udp_debug({socket, Socket}, "udp close", []),
    case erlang:port_info(Socket, connected) of
	{connected, ControlPid} ->
	    megaco_udp_server:stop(ControlPid);
	undefined ->
	    {error, already_closed}
    end.

%%-----------------------------------------------------------------
%% Internal functions
%%-----------------------------------------------------------------
%%-----------------------------------------------------------------
%% Func: start_udp_server/1
%% Description: Function is used for starting up a connection
%%              process
%%-----------------------------------------------------------------
start_udp_server(SupPid, UdpRec) ->
    supervisor:start_child(SupPid, [UdpRec]).

%%-----------------------------------------------------------------
%% Func: parse_options
%% Description: Function that parses the options sent to the UDP 
%%              module.
%%-----------------------------------------------------------------
parse_options([{Tag, Val} | T], UdpRec, Mand) ->
    Mand2 = Mand -- [Tag],
    case Tag of
	port ->
	    parse_options(T, UdpRec#megaco_udp{port = Val}, Mand2);
	udp_options when list(Val)->
	    parse_options(T, UdpRec#megaco_udp{options = Val}, Mand2);
	receive_handle ->
	    parse_options(T, UdpRec#megaco_udp{receive_handle = Val}, Mand2);
	module when atom(Val) ->
	    parse_options(T, UdpRec#megaco_udp{module = Val}, Mand2);
        Bad ->
	    {error, {bad_option, Bad}}
    end;
parse_options([], UdpRec, []) ->
    {ok, UdpRec};
parse_options([], UdpRec, Mand) ->
    {error, {missing_options, Mand}};
parse_options(BadList, UdpRec, Mand) ->
    {error, {bad_option_list, BadList}}.