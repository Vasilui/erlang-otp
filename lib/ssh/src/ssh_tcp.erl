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

%%% Description: SSH port forwarding

-module(ssh_tcp).

-behaviour(gen_server).
%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("ssh.hrl").

%%--------------------------------------------------------------------
%% External exports
-export([start/1, start_link/1]).
-export([start/2, start_link/2]).
-export([start/3, start_link/3]).

-export([forward/5, backward/5]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state,
	{
	  cm,     % connection manager
	  opts    % options
	 }).

-define(DEFAULT_TIMEOUT, 5000).


%%====================================================================
%% External functions
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link/0
%% Description: Starts the server
%%--------------------------------------------------------------------

start_link(CM) ->
    gen_server:start_link(?MODULE, [CM], []).

start_link(Host, Opts) ->
    gen_server:start_link(?MODULE, [Host,22,Opts], []).
    
start_link(Host, Port, Opts) ->
    gen_server:start_link(?MODULE, [Host,Port,Opts], []).

start(CM) ->
    gen_server:start(?MODULE, [CM], []).

start(Host, Opts) ->
    gen_server:start(?MODULE, [Host, 22, Opts], []).
    
start(Host, Port, Opts) ->
    gen_server:start(?MODULE, [Host, Port, Opts], []).


forward(Pid, LocalIP, LocalPort, RemoteIP, RemotePort) ->
    gen_server:call(Pid, {forward, 
			  LocalIP, LocalPort,
			  RemoteIP, RemotePort}).

backward(Pid, LocalIP, LocalPort, RemoteIP, RemotePort) ->
    gen_server:call(Pid, {backward,
			  LocalIP, LocalPort,
			  RemoteIP, RemotePort}).

%%====================================================================
%% Server functions
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%%--------------------------------------------------------------------
init([CM]) ->
    case ssh_cm:attach(CM, ?DEFAULT_TIMEOUT) of
	{ok,CMPid} ->
	    {ok, #state{cm = CMPid, opts = []}};
	Error ->
	    {stop, Error }
    end;
init([Host, Port, Opts]) ->
    case ssh_cm:connect(Host, Port, Opts) of
	{ok, CM} ->
	    {ok, #state {cm = CM, opts = Opts}};
	Error ->
	    {stop, Error}
    end.

%%--------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%%--------------------------------------------------------------------

handle_call({forward, LocalIP, LocalPort, RemoteIP, RemotePort},_From,State) ->
    LIP = ip_address(LocalIP),
    _RIP = ip_address(RemoteIP),
    Me = self(),
    Prog = fun(S) ->
		   ?dbg(true, "accepted\n", ""),
		   gen_tcp:controlling_process(S, Me),
		   gen_server:cast(Me,{forward, S, RemoteIP, RemotePort})
	   end,
    case ssh_tcp_wrap:spawn_server(LocalPort,
				   [{ifaddr, LIP},{mode, binary},
				    {packet, 0},{active, false}],Prog) of
	{ok,_Server,ListenPort} ->
	    {reply, {ok,ListenPort}, State};
	Error ->
	    {reply, Error, State}
    end;
handle_call({backward, LocalIP, LocalPort, RemoteIP, RemotePort},_From,State) ->
    case ssh_cm:tcpip_forward(State#state.cm, RemoteIP, RemotePort) of
	ok ->
	    put({ipmap,{RemoteIP,RemotePort}}, {LocalIP,LocalPort}),
	    {reply, ok, State};
	Error ->
	    {reply, Error, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error,bad_call}, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%%--------------------------------------------------------------------
handle_cast({forward, S, RemoteIP, RemotePort}, State) ->
    case inet:peername(S) of
	{ok,{OrigIP, OrigPort}} ->
	    ?dbg(true, "peer ~p ~p remote ~p ~p\n", 
		 [OrigIP, OrigPort, RemoteIP, RemotePort]),
	    #state{opts = Opts, cm = CM} = State,
	    TMO = proplists:get_value(connect_timeout,
				      Opts, ?DEFAULT_TIMEOUT),
	    case ssh_cm:direct_tcpip(CM,
				     RemoteIP, RemotePort,
				     OrigIP, OrigPort, TMO) of
		{ok, Channel} ->
		    ?dbg(true, "got channel ~p\n", [Channel]),
		    ssh_cm:set_user_ack(CM, Channel, true, TMO),
		    put({channel,S}, Channel),
		    put({socket,Channel}, S),
		    inet:setopts(S, [{active, once}]),
		    {noreply, State};
		{error, _Error} ->
		    ?dbg(true, "forward: error ~p\n", [_Error]),
		    gen_tcp:close(S),
		    {noreply, State}
	    end;
	_Error ->
	    gen_tcp:close(S),
	    {noreply, State}
    end;
    
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%%--------------------------------------------------------------------

handle_info({tcp, S, Data}, State) ->
    case get({channel,S}) of
	undefined ->
	    {noreply, State};	    
	Channel ->
	    ?dbg(true, "sending ~p -> ~p\n", [S, Channel]),
	    %% send and wait for ack
	    ssh_cm:send_ack(State#state.cm, Channel, Data),
	    inet:setopts(S, [{active, once}]),
	    {noreply, State}
    end;
handle_info({tcp_closed, S}, State) ->
    ?dbg(true, "tcp: closed: ~p\n", [S]),
    case get({channel,S}) of
	undefined -> 
	    {noreply, State};
	Channel ->
	    ssh_cm:send_eof(State#state.cm, Channel),
	    {noreply, State}
    end;

handle_info({ssh_cm, CM, {data, Channel, Type, Data}}, State) ->
    if Type == 0 ->
	    ?dbg(true, "ssh_cm: data: ~p\n", [Channel]),
	    case get({socket,Channel}) of
		undefined ->{noreply, State};
		S ->
		    ?dbg(true, "sending ~p -> ~p\n", [Channel,S]),
		    gen_tcp:send(S, Data),
		    ssh_cm:adjust_window(CM, Channel, size(Data)),
		    {noreply, State}
	    end;
       true  ->
	    ?dbg(true, "STDERR: ~s\n", [binary_to_list(Data)]),
	    ssh_cm:adjust_window(CM, Channel, size(Data)),
	    {noreply, State}
    end;

handle_info({ssh_cm, _CM, {closed, Channel}}, State) ->
    ?dbg(true, "ssh_cm: closed: ~p\n", [Channel]),
    case get({socket, Channel}) of
	undefined -> {noreply, State};
	S ->
	    erase({socket,Channel}),
	    erase({channel,S}),
	    gen_tcp:close(S),
	    {noreply, State}
    end;

handle_info({ssh_cm, _CM, {eof, Channel}}, State) ->
    ?dbg(true, "ssh_cm: eof: ~p\n", [Channel]),
    case get({socket,Channel}) of
	undefined -> {noreply, State};
	S ->
	    gen_tcp:shutdown(S, write),
	    {noreply, State}
    end;

handle_info({open, Channel, {forwarded_tcpip,
			     RemoteAddr, RemotePort,
			     _OrigIp, _OrigPort}},
	    #state{opts = Opts, cm = CM} = State) ->
    TMO = proplists:get_value(connect_timeout,
			      Opts, ?DEFAULT_TIMEOUT),
    case get({ipmap,{RemoteAddr,RemotePort}}) of
	undefined ->
	    ssh_cm:close(CM, Channel),
	    {noreply, State};
	{LocalIP, LocalPort} ->
	    case gen_tcp:connect(LocalIP, LocalPort, [{active,once},
						      {mode,binary},
						      {packet,0},
						      {connect_timeout, TMO}]) of
		{ok, S} ->
		    %% We want ack on send!
		    ssh_cm:set_user_ack(CM, Channel, true, TMO),
		    %% FIXME: set fake peer and port?
		    put({channel, S}, Channel),
		    put({socket,Channel}, S),
		    {noreply, State};
		_Error ->
		    ssh_cm:close(CM, Channel),
		    {noreply, State}
	    end
    end;
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions 
%%--------------------------------------------------------------------

%% Try to convert to ip4/ip6 address tuple	    
ip_address(Addr) when tuple(Addr) ->
    Addr;
ip_address(local) -> local;
ip_address(any)   -> any;
ip_address(Addr) when list(Addr) ->
    case inet_parse:address(Addr) of
	{error, _} -> Addr;
	{ok,A} -> A
    end;
ip_address(A) -> A.

    