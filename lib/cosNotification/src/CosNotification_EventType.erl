%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotification_EventType
%% Source: /ldisk/daily_build/otp_prebuild_r11b.2007-06-11_19/otp_src_R11B-5/lib/cosNotification/src/CosNotification.idl
%% IC vsn: 4.2.13
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotification_EventType').
-ic_compiled("4_2_13").


-include("CosNotification.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_struct,"IDL:omg.org/CosNotification/EventType:1.0",
                   "EventType",
                   [{"domain_name",{tk_string,0}},
                    {"type_name",{tk_string,0}}]}.

%% returns id
id() -> "IDL:omg.org/CosNotification/EventType:1.0".

%% returns name
name() -> "CosNotification_EventType".



