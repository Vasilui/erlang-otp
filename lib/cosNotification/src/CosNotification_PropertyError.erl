%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotification_PropertyError
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2007-12-04_15/otp_src_R12B-0/lib/cosNotification/src/CosNotification.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotification_PropertyError').
-ic_compiled("4_2_16").


-include("CosNotification.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_struct,"IDL:omg.org/CosNotification/PropertyError:1.0",
                   "PropertyError",
                   [{"code",
                     {tk_enum,"IDL:omg.org/CosNotification/QoSError_code:1.0",
                              "QoSError_code",
                              ["UNSUPPORTED_PROPERTY","UNAVAILABLE_PROPERTY",
                               "UNSUPPORTED_VALUE","UNAVAILABLE_VALUE",
                               "BAD_PROPERTY","BAD_TYPE","BAD_VALUE"]}},
                    {"name",{tk_string,0}},
                    {"available_range",
                     {tk_struct,"IDL:omg.org/CosNotification/PropertyRange:1.0",
                                "PropertyRange",
                                [{"low_val",tk_any},{"high_val",tk_any}]}}]}.

%% returns id
id() -> "IDL:omg.org/CosNotification/PropertyError:1.0".

%% returns name
name() -> "CosNotification_PropertyError".



