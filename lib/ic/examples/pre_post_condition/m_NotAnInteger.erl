%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: m_NotAnInteger
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2008-02-05_20/otp_src_R12B-1/lib/ic/examples/pre_post_condition/ex.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module(m_NotAnInteger).
-ic_compiled("4_2_16").


-include("m.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_except,"IDL:m/NotAnInteger:1.0","NotAnInteger",[]}.

%% returns id
id() -> "IDL:m/NotAnInteger:1.0".

%% returns name
name() -> "m_NotAnInteger".



