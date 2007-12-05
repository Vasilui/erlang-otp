%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotification_FixedEventHeader
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2007-12-04_15/otp_src_R12B-0/lib/cosNotification/src/CosNotification.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotification_FixedEventHeader').
-ic_compiled("4_2_16").


-include("CosNotification.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_struct,"IDL:omg.org/CosNotification/FixedEventHeader:1.0",
                   "FixedEventHeader",
                   [{"event_type",
                     {tk_struct,"IDL:omg.org/CosNotification/EventType:1.0",
                                "EventType",
                                [{"domain_name",{tk_string,0}},
                                 {"type_name",{tk_string,0}}]}},
                    {"event_name",{tk_string,0}}]}.

%% returns id
id() -> "IDL:omg.org/CosNotification/FixedEventHeader:1.0".

%% returns name
name() -> "CosNotification_FixedEventHeader".



