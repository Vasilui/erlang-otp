%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNotifyChannelAdmin_AdminLimitExceeded
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2008-02-05_20/otp_src_R12B-1/lib/cosNotification/src/CosNotifyChannelAdmin.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNotifyChannelAdmin_AdminLimitExceeded').
-ic_compiled("4_2_16").


-include("CosNotifyChannelAdmin.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_except,"IDL:omg.org/CosNotifyChannelAdmin/AdminLimitExceeded:1.0",
                   "AdminLimitExceeded",
                   [{"admin_property_err",
                     {tk_struct,"IDL:omg.org/CosNotifyChannelAdmin/AdminLimit:1.0",
                                "AdminLimit",
                                [{"name",{tk_string,0}},{"value",tk_any}]}}]}.

%% returns id
id() -> "IDL:omg.org/CosNotifyChannelAdmin/AdminLimitExceeded:1.0".

%% returns name
name() -> "CosNotifyChannelAdmin_AdminLimitExceeded".



