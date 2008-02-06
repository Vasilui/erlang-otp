%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosPropertyService_PropertySetFactory
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2008-02-05_20/otp_src_R12B-1/lib/cosProperty/src/CosProperty.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosPropertyService_PropertySetFactory').
-ic_compiled("4_2_16").


%% Interface functions
-export([create_propertyset/1, create_propertyset/2, create_constrained_propertyset/3]).
-export([create_constrained_propertyset/4, create_initial_propertyset/2, create_initial_propertyset/3]).

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



%%%% Operation: create_propertyset
%% 
%%   Returns: RetVal
%%
create_propertyset(OE_THIS) ->
    corba:call(OE_THIS, create_propertyset, [], ?MODULE).

create_propertyset(OE_THIS, OE_Options) ->
    corba:call(OE_THIS, create_propertyset, [], ?MODULE, OE_Options).

%%%% Operation: create_constrained_propertyset
%% 
%%   Returns: RetVal
%%   Raises:  CosPropertyService::ConstraintNotSupported
%%
create_constrained_propertyset(OE_THIS, Allowed_property_types, Allowed_properties) ->
    corba:call(OE_THIS, create_constrained_propertyset, [Allowed_property_types, Allowed_properties], ?MODULE).

create_constrained_propertyset(OE_THIS, OE_Options, Allowed_property_types, Allowed_properties) ->
    corba:call(OE_THIS, create_constrained_propertyset, [Allowed_property_types, Allowed_properties], ?MODULE, OE_Options).

%%%% Operation: create_initial_propertyset
%% 
%%   Returns: RetVal
%%   Raises:  CosPropertyService::MultipleExceptions
%%
create_initial_propertyset(OE_THIS, Initial_properties) ->
    corba:call(OE_THIS, create_initial_propertyset, [Initial_properties], ?MODULE).

create_initial_propertyset(OE_THIS, OE_Options, Initial_properties) ->
    corba:call(OE_THIS, create_initial_propertyset, [Initial_properties], ?MODULE, OE_Options).

%%------------------------------------------------------------
%%
%% Inherited Interfaces
%%
%%------------------------------------------------------------
oe_is_a("IDL:omg.org/CosPropertyService/PropertySetFactory:1.0") -> true;
oe_is_a(_) -> false.

%%------------------------------------------------------------
%%
%% Interface TypeCode
%%
%%------------------------------------------------------------
oe_tc(create_propertyset) -> 
	{{tk_objref,"IDL:omg.org/CosPropertyService/PropertySet:1.0",
                    "PropertySet"},
         [],[]};
oe_tc(create_constrained_propertyset) -> 
	{{tk_objref,"IDL:omg.org/CosPropertyService/PropertySet:1.0",
                    "PropertySet"},
         [{tk_sequence,tk_TypeCode,0},
          {tk_sequence,{tk_struct,"IDL:omg.org/CosPropertyService/Property:1.0",
                                  "Property",
                                  [{"property_name",{tk_string,0}},
                                   {"property_value",tk_any}]},
                       0}],
         []};
oe_tc(create_initial_propertyset) -> 
	{{tk_objref,"IDL:omg.org/CosPropertyService/PropertySet:1.0",
                    "PropertySet"},
         [{tk_sequence,{tk_struct,"IDL:omg.org/CosPropertyService/Property:1.0",
                                  "Property",
                                  [{"property_name",{tk_string,0}},
                                   {"property_value",tk_any}]},
                       0}],
         []};
oe_tc(_) -> undefined.

oe_get_interface() -> 
	[{"create_initial_propertyset", oe_tc(create_initial_propertyset)},
	{"create_constrained_propertyset", oe_tc(create_constrained_propertyset)},
	{"create_propertyset", oe_tc(create_propertyset)}].




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
    "IDL:omg.org/CosPropertyService/PropertySetFactory:1.0".


%%------------------------------------------------------------
%%
%% Object creation functions.
%%
%%------------------------------------------------------------

oe_create() ->
    corba:create(?MODULE, "IDL:omg.org/CosPropertyService/PropertySetFactory:1.0").

oe_create_link() ->
    corba:create_link(?MODULE, "IDL:omg.org/CosPropertyService/PropertySetFactory:1.0").

oe_create(Env) ->
    corba:create(?MODULE, "IDL:omg.org/CosPropertyService/PropertySetFactory:1.0", Env).

oe_create_link(Env) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosPropertyService/PropertySetFactory:1.0", Env).

oe_create(Env, RegName) ->
    corba:create(?MODULE, "IDL:omg.org/CosPropertyService/PropertySetFactory:1.0", Env, RegName).

oe_create_link(Env, RegName) ->
    corba:create_link(?MODULE, "IDL:omg.org/CosPropertyService/PropertySetFactory:1.0", Env, RegName).

%%------------------------------------------------------------
%%
%% Init & terminate functions.
%%
%%------------------------------------------------------------

init(Env) ->
%% Call to implementation init
    corba:handle_init('CosPropertyService_PropertySetFactory_impl', Env).

terminate(Reason, State) ->
    corba:handle_terminate('CosPropertyService_PropertySetFactory_impl', Reason, State).


%%%% Operation: create_propertyset
%% 
%%   Returns: RetVal
%%
handle_call({OE_THIS, OE_Context, create_propertyset, []}, _, OE_State) ->
  corba:handle_call('CosPropertyService_PropertySetFactory_impl', create_propertyset, [], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: create_constrained_propertyset
%% 
%%   Returns: RetVal
%%   Raises:  CosPropertyService::ConstraintNotSupported
%%
handle_call({OE_THIS, OE_Context, create_constrained_propertyset, [Allowed_property_types, Allowed_properties]}, _, OE_State) ->
  corba:handle_call('CosPropertyService_PropertySetFactory_impl', create_constrained_propertyset, [Allowed_property_types, Allowed_properties], OE_State, OE_Context, OE_THIS, false);

%%%% Operation: create_initial_propertyset
%% 
%%   Returns: RetVal
%%   Raises:  CosPropertyService::MultipleExceptions
%%
handle_call({OE_THIS, OE_Context, create_initial_propertyset, [Initial_properties]}, _, OE_State) ->
  corba:handle_call('CosPropertyService_PropertySetFactory_impl', create_initial_propertyset, [Initial_properties], OE_State, OE_Context, OE_THIS, false);



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
    corba:handle_code_change('CosPropertyService_PropertySetFactory_impl', OldVsn, State, Extra).

