%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotifyComm_InvalidEventType
%% Source: /ldisk/daily_build/otp_prebuild_r11b.2007-06-11_19/otp_src_R11B-5/lib/cosNotification/src/CosNotifyComm.idl
%% IC vsn: 4.2.13
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotifyComm_InvalidEventType').
-ic_compiled("4_2_13").


-include("CosNotifyComm.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_except,"IDL:omg.org/CosNotifyComm/InvalidEventType:1.0",
                   "InvalidEventType",
                   [{"type",
                     {tk_struct,"IDL:omg.org/CosNotification/EventType:1.0",
                                "EventType",
                                [{"domain_name",{tk_string,0}},
                                 {"type_name",{tk_string,0}}]}}]}.

%% returns id
id() -> "IDL:omg.org/CosNotifyComm/InvalidEventType:1.0".

%% returns name
name() -> "CosNotifyComm_InvalidEventType".



