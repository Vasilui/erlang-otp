%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: TimeBase_IntervalT
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2007-12-04_15/otp_src_R12B-0/lib/cosTime/src/TimeBase.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('TimeBase_IntervalT').
-ic_compiled("4_2_16").


-include("TimeBase.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_struct,"IDL:omg.org/TimeBase/IntervalT:1.0","IntervalT",
                   [{"lower_bound",tk_ulonglong},
                    {"upper_bound",tk_ulonglong}]}.

%% returns id
id() -> "IDL:omg.org/TimeBase/IntervalT:1.0".

%% returns name
name() -> "TimeBase_IntervalT".



