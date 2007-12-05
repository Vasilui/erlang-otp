%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotification_AdminPropertiesAdmin
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2007-12-04_15/otp_src_R12B-0/lib/cosNotification/src/CosNotification.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotification_AdminPropertiesAdmin').
-ic_compiled("4_2_16").


%% Interface functions
-export([get_admin/1, get_admin/2, set_admin/2]).
-export([set_admin/3]).

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



%%%% Operation: get_admin
%% 
%%   Returns: RetVal
%%
get_admin(OE_THIS) ->
    corba:call(OE_THIS, get_admin, [], ?MODULE).

get_admin(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, get_admin, [], ?MODULE, OE_Options).

%%%% Operation: set_admin
%% 
%%   Returns: RetVal
%%   Raises:  CosNotification::UnsupportedAdmin
%%
set_admin(OE_THIS, Admin) ->
    corba:call(OE_THIS, set_admin, [Admin], ?MODULE).

set_admin(OE_THIS, OE_Options, Admin) ->
    corba:call(OE_THIS, set_admin, [Admin], ?MODULE, OE_Options).

%%------------------------------------------------------------
%%
%% Inherited Interfaces
%%
%%------------------------------------------------------------
oe_is_a("IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0") -> true;
oe_is_a(_) -> false.

%%------------------------------------------------------------
%%
%% Interface TypeCode
%%
%%------------------------------------------------------------
oe_tc(get_admin) -> 
	{{tk_sequence,{tk_struct,"IDL:omg.org/CosNotification/Property:1.0",
                                 "Property",
                                 [{"name",{tk_string,0}},{"value",tk_any}]},
                      0},
         [],[]};
oe_tc(set_admin) -> 
	{tk_void,
            [{tk_sequence,
                 {tk_struct,"IDL:omg.org/CosNotification/Property:1.0",
                     "Property",
                     [{"name",{tk_string,0}},{"value",tk_any}]},
                 0}],
            []};
oe_tc(_) -> undefined.

oe_get_interface() -> 
	[{"set_admin", oe_tc(set_admin)},
	{"get_admin", oe_tc(get_admin)}].




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
    "IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0".


%%------------------------------------------------------------
%%
%% Object creation functions.
%%
%%------------------------------------------------------------

oe_create() ->
    corba:create(?MODULE, "IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0").

oe_create_link() ->
    corba:create_link(?MODULE, "IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0").

oe_create(Env) ->
    corba:create(?MODULE, "IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0", Env).

oe_create_link(Env) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0", Env).

oe_create(Env, RegName) ->
    corba:create(?MODULE, "IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0", Env, RegName).

oe_create_link(Env, RegName) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosNotification/AdminPropertiesAdmin:1.0", Env, RegName).

%%------------------------------------------------------------
%%
%% Init & terminate functions.
%%
%%------------------------------------------------------------

init(Env) ->
%% Call to implementation init
    corba:handle_init('CosNotification_AdminPropertiesAdmin_impl', Env).

terminate(Reason, State) ->
    corba:handle_terminate('CosNotification_AdminPropertiesAdmin_impl', Reason, State).


%%%% Operation: get_admin
%% 
%%   Returns: RetVal
%%
handle_call({_, OE_Context, get_admin, []}, _, OE_State) ->
  corba:handle_call('CosNotification_AdminPropertiesAdmin_impl', get_admin, [], OE_State, OE_Context, false, false);

%%%% Operation: set_admin
%% 
%%   Returns: RetVal
%%   Raises:  CosNotification::UnsupportedAdmin
%%
handle_call({_, OE_Context, set_admin, [Admin]}, _, OE_State) ->
  corba:handle_call('CosNotification_AdminPropertiesAdmin_impl', set_admin, [Admin], OE_State, OE_Context, false, false);



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
    corba:handle_code_change('CosNotification_AdminPropertiesAdmin_impl', OldVsn, State, Extra).

