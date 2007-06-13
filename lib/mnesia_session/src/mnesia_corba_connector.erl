%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: mnesia_corba_connector
%% Source: /ldisk/daily_build/otp_prebuild_r11b.2007-06-11_19/otp_src_R11B-5/lib/mnesia_session/src/mnesia_corba_session.idl
%% IC vsn: 4.2.13
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module(mnesia_corba_connector).
-ic_compiled("4_2_13").


%% Interface functions
-export([connect/1, connect/2, disconnect/2]).
-export([disconnect/3]).

%% Type identification function
-export([typeID/0]).

%% Used to start server
-export([oe_create/0, oe_create_link/0, oe_create/1]).
-export([oe_create_link/1, oe_create/2, oe_create_link/2]).

%% TypeCode Functions and inheritance
-export([oe_tc/1, oe_is_a/1, oe_get_interface/0]).

%% gen server export stuff
-behaviour(gen_server).
-export([init/1, terminate/2, handle_call/3]).
-export([handle_cast/2, handle_info/2, code_change/3]).

-include_lib("orber/include/corba.hrl").


%%------------------------------------------------------------
%%
%% Object interface functions.
%%
%%------------------------------------------------------------



%%%% Operation: connect
%% 
%%   Returns: RetVal
%%
connect(OE_THIS) ->
    corba:call(OE_THIS, connect, [], ?MODULE).

connect(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, connect, [], ?MODULE, OE_Options).

%%%% Operation: disconnect
%% 
%%   Returns: RetVal
%%
disconnect(OE_THIS, Object_key) ->
    corba:call(OE_THIS, disconnect, [Object_key], ?MODULE).

disconnect(OE_THIS, OE_Options, Object_key) ->
    corba:call(OE_THIS, disconnect, [Object_key], ?MODULE, OE_Options).

%%------------------------------------------------------------
%%
%% Inherited Interfaces
%%
%%------------------------------------------------------------
oe_is_a("IDL:mnesia/corba_connector:1.0") -> true;
oe_is_a(_) -> false.

%%------------------------------------------------------------
%%
%% Interface TypeCode
%%
%%------------------------------------------------------------
oe_tc(connect) -> 
	{{tk_objref,"IDL:mnesia/corba_session:1.0","corba_session"},[],[]};
oe_tc(disconnect) -> 
	{tk_void,[{tk_objref,"IDL:mnesia/corba_session:1.0","corba_session"}],
                 []};
oe_tc(_) -> undefined.

oe_get_interface() -> 
	[{"disconnect", oe_tc(disconnect)},
	{"connect", oe_tc(connect)}].




%%------------------------------------------------------------
%%
%% Object server implementation.
%%
%%------------------------------------------------------------


%%------------------------------------------------------------
%%
%% Function for fetching the interface type ID.
%%
%%------------------------------------------------------------

typeID() ->
    "IDL:mnesia/corba_connector:1.0".


%%------------------------------------------------------------
%%
%% Object creation functions.
%%
%%------------------------------------------------------------

oe_create() ->
    corba:create(?MODULE, "IDL:mnesia/corba_connector:1.0").

oe_create_link() ->
    corba:create_link(?MODULE, "IDL:mnesia/corba_connector:1.0").

oe_create(Env) ->
    corba:create(?MODULE, "IDL:mnesia/corba_connector:1.0", Env).

oe_create_link(Env) ->
    corba:create_link(?MODULE, "IDL:mnesia/corba_connector:1.0", Env).

oe_create(Env, RegName) ->
    corba:create(?MODULE, "IDL:mnesia/corba_connector:1.0", Env, RegName).

oe_create_link(Env, RegName) ->
    corba:create_link(?MODULE, "IDL:mnesia/corba_connector:1.0", Env, RegName).

%%------------------------------------------------------------
%%
%% Init & terminate functions.
%%
%%------------------------------------------------------------

init(Env) ->
%% Call to implementation init
    corba:handle_init(mnesia_corba_connector_impl, Env).

terminate(Reason, State) ->
    corba:handle_terminate(mnesia_corba_connector_impl, Reason, State).


%%%% Operation: connect
%% 
%%   Returns: RetVal
%%
handle_call({_, OE_Context, connect, []}, _, OE_State) ->
  corba:handle_call(mnesia_corba_connector_impl, connect, [], OE_State, OE_Context, false, false);

%%%% Operation: disconnect
%% 
%%   Returns: RetVal
%%
handle_call({_, OE_Context, disconnect, [Object_key]}, _, OE_State) ->
  corba:handle_call(mnesia_corba_connector_impl, disconnect, [Object_key], OE_State, OE_Context, false, false);



%%%% Standard gen_server call handle
%%
handle_call(stop, _, State) ->
    {stop, normal, ok, State};

handle_call(_, _, State) ->
    {reply, catch corba:raise(#'BAD_OPERATION'{minor=1163001857, completion_status='COMPLETED_NO'}), State}.


%%%% Standard gen_server cast handle
%%
handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_, State) ->
    {noreply, State}.


%%%% Standard gen_server handles
%%
handle_info(_, State) ->
    {noreply, State}.


code_change(OldVsn, State, Extra) ->
    corba:handle_code_change(mnesia_corba_connector_impl, OldVsn, State, Extra).

