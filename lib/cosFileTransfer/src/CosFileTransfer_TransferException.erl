%%------------------------------------------------------------
%%
%% Implementation stub file
%% 
%% Target: CosFileTransfer_TransferException
%% Source: /ldisk/daily_build/otp_prebuild_r11b.2007-06-11_19/otp_src_R11B-5/lib/cosFileTransfer/src/CosFileTransfer.idl
%% IC vsn: 4.2.13
%% 
%% This file is automatically generated. DO NOT EDIT IT.
%%
%%------------------------------------------------------------

-module('CosFileTransfer_TransferException').
-ic_compiled("4_2_13").


-include("CosFileTransfer.hrl").

-export([tc/0,id/0,name/0]).



%% returns type code
tc() -> {tk_except,"IDL:omg.org/CosFileTransfer/TransferException:1.0",
                   "TransferException",
                   [{"reason",{tk_string,0}}]}.

%% returns id
id() -> "IDL:omg.org/CosFileTransfer/TransferException:1.0".

%% returns name
name() -> "CosFileTransfer_TransferException".



