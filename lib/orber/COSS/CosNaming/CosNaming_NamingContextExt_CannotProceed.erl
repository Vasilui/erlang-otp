%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosNaming_NamingContextExt_CannotProceed
%% Source: /ldisk/daily_build/otp_prebuild_r12b.2008-02-05_20/otp_src_R12B-1/lib/orber/COSS/CosNaming/cos_naming_ext.idl
%% IC vsn: 4.2.16
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosNaming_NamingContextExt_CannotProceed').
-ic_compiled("4_2_16").


-include("CosNaming_NamingContextExt.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_except,
            "IDL:omg.org/CosNaming/NamingContext/CannotProceed:1.0",
            "CannotProceed",
            [{"cxt",
              {tk_objref,"IDL:omg.org/CosNaming/NamingContext:1.0",
                  "NamingContext"}},
             {"rest_of_name",
              {tk_sequence,
                  {tk_struct,"IDL:omg.org/CosNaming/NameComponent:1.0",
                      "NameComponent",
                      [{"id",{tk_string,0}},{"kind",{tk_string,0}}]},
                  0}}]}.

%% returns id
id() -> "IDL:CosNaming/NamingContextExt/CannotProceed:1.0".

%% returns name
name() -> "CosNaming_NamingContextExt_CannotProceed".



