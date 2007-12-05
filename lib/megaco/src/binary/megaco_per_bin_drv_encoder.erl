%%<copyright>
%% <year>2002-2007</year>
%% <holder>Ericsson AB, All Rights Reserved</holder>
%%</copyright>
%%<legalnotice>
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% The Initial Developer of the Original Code is Ericsson AB.
%%</legalnotice>
%%
%%----------------------------------------------------------------------
%% Purpose : Handle ASN.1 PER encoding of Megaco/H.248
%%----------------------------------------------------------------------

-module(megaco_per_bin_drv_encoder).

-behaviour(megaco_encoder).

-export([encode_message/2, decode_message/2,
	 encode_message/3, decode_message/3,
	 decode_mini_message/3, 

	 encode_transaction/3,
	 encode_action_requests/3,
	 encode_action_request/3,

	 version_of/2]).

-include_lib("megaco/src/engine/megaco_message_internal.hrl").

-define(V1_ASN1_MOD,     megaco_per_bin_drv_media_gateway_control_v1).
-define(V2_ASN1_MOD,     megaco_per_bin_drv_media_gateway_control_v2).
-define(V3_ASN1_MOD,     megaco_per_bin_drv_media_gateway_control_v3).
-define(PREV3A_ASN1_MOD, megaco_per_bin_drv_media_gateway_control_prev3a).
-define(PREV3B_ASN1_MOD, megaco_per_bin_drv_media_gateway_control_prev3b).
-define(PREV3C_ASN1_MOD, megaco_per_bin_drv_media_gateway_control_prev3c).

-define(V1_TRANS_MOD,     megaco_binary_transformer_v1).
-define(V2_TRANS_MOD,     megaco_binary_transformer_v2).
-define(V3_TRANS_MOD,     megaco_binary_transformer_V3).
-define(PREV3A_TRANS_MOD, megaco_binary_transformer_prev3a).
-define(PREV3B_TRANS_MOD, megaco_binary_transformer_prev3b).
-define(PREV3C_TRANS_MOD, megaco_binary_transformer_prev3c).

-define(BIN_LIB, megaco_binary_encoder_lib).


%%----------------------------------------------------------------------
%% Detect (check) which version a message is
%% Return {ok, Version} | {error, Reason}
%%----------------------------------------------------------------------
 
version_of([{version3,v3}|EC], Binary) ->
    Decoders = [?V1_ASN1_MOD, ?V2_ASN1_MOD, ?V3_ASN1_MOD], 
    ?BIN_LIB:version_of(EC, Binary, 1, Decoders);
version_of([{version3,prev3c}|EC], Binary) ->
    Decoders = [?V1_ASN1_MOD, ?V2_ASN1_MOD, ?PREV3C_ASN1_MOD], 
    ?BIN_LIB:version_of(EC, Binary, 1, Decoders);
version_of([{version3,prev3b}|EC], Binary) ->
    Decoders = [?V1_ASN1_MOD, ?V2_ASN1_MOD, ?PREV3B_ASN1_MOD], 
    ?BIN_LIB:version_of(EC, Binary, 1, Decoders);
version_of([{version3,prev3a}|EC], Binary) ->
    Decoders = [?V1_ASN1_MOD, ?V2_ASN1_MOD, ?PREV3A_ASN1_MOD], 
    ?BIN_LIB:version_of(EC, Binary, 1, Decoders);
version_of(EC, Binary) ->
    Decoders = [?V1_ASN1_MOD, ?V2_ASN1_MOD, ?V3_ASN1_MOD],
    ?BIN_LIB:version_of(EC, Binary, 1, Decoders).


%%----------------------------------------------------------------------
%% Convert a 'MegacoMessage' record into a binary
%% Return {ok, Binary} | {error, Reason}
%%----------------------------------------------------------------------

encode_message(EC, 
	       #'MegacoMessage'{mess = #'Message'{version = V}} = MegaMsg) ->
    encode_message(EC, V, MegaMsg).

encode_message([{version3,_}|EC], 1, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, ?V1_ASN1_MOD, ?V1_TRANS_MOD, io_list);
encode_message(EC, 1, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, ?V1_ASN1_MOD, ?V1_TRANS_MOD, io_list);
encode_message([{version3,_}|EC], 2, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, ?V2_ASN1_MOD, ?V2_TRANS_MOD, io_list);
encode_message(EC, 2, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, ?V2_ASN1_MOD, ?V2_TRANS_MOD, io_list);
encode_message([{version3,v3}|EC], 3, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, ?V3_ASN1_MOD, ?V3_TRANS_MOD, io_list);
encode_message([{version3,prev3c}|EC], 3, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, 
			    ?PREV3C_ASN1_MOD, ?PREV3C_TRANS_MOD, io_list);
encode_message([{version3,prev3b}|EC], 3, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, 
			    ?PREV3B_ASN1_MOD, ?PREV3B_TRANS_MOD, io_list);
encode_message([{version3,prev3a}|EC], 3, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, 
			    ?PREV3A_ASN1_MOD, ?PREV3A_TRANS_MOD, io_list);
encode_message(EC, 3, MegaMsg) ->
    ?BIN_LIB:encode_message(EC, MegaMsg, ?V3_ASN1_MOD, ?V3_TRANS_MOD, io_list).


%%----------------------------------------------------------------------
%% Convert a transaction (or transactions in the case of ack) record(s) 
%% into a binary
%% Return {ok, Binary} | {error, Reason}
%%----------------------------------------------------------------------

encode_transaction(_EC, 1, _Trans) ->
    %%     ?BIN_LIB:encode_transaction(EC, 
    %% 					     Trans,
    %% 					     ?V1_ASN1_MOD, 
    %% 					     ?V1_TRANS_MOD,
    %% 					     io_list);
    {error, not_implemented};
encode_transaction(_EC, 2, _Trans) ->
    %%     ?BIN_LIB:encode_transaction(EC, 
    %% 					     Trans, 
    %% 					     ?V2_ASN1_MOD, 
    %% 					     ?V2_TRANS_MOD,
    %% 					     io_list).
    {error, not_implemented};
encode_transaction(EC, prev3a, Trans) ->
    %%     ?BIN_LIB:encode_transaction(EC, Trans,
    %%                                       ?V3_ASN1_MOD,
    %%                                       ?V3_TRANS_MOD,
    %%                                       io_list).
    {error, not_implemented};
encode_transaction(EC, 3, Trans) ->
    encode_transaction(EC, prev3a, Trans).


%%----------------------------------------------------------------------
%% Convert a list of ActionRequest record's into a binary
%% Return {ok, DeepIoList} | {error, Reason}
%%----------------------------------------------------------------------
encode_action_requests(_EC, 1, ActReqs) when list(ActReqs) ->
    %%     ?BIN_LIB:encode_action_requests(EC, ActReqs,
    %% 						 ?V1_ASN1_MOD, 
    %% 						 ?V1_TRANS_MOD,
    %% 						 io_list);
    {error, not_implemented};
encode_action_requests(_EC, 2, ActReqs) when list(ActReqs) ->
    %%     ?BIN_LIB:encode_action_requests(EC, ActReqs,
    %% 						 ?V1_ASN1_MOD, 
    %% 						 ?V1_TRANS_MOD,
    %% 						 io_list).
    {error, not_implemented};
encode_action_requests(EC, 3, ActReqs) when list(ActReqs) ->
    %%     ?BIN_LIB:encode_action_requests(EC, ActReqs,
    %%                                           ?V3_ASN1_MOD,
    %%                                           ?V3_TRANS_MOD,
    %%                                           io_list).
    {error, not_implemented}.


%%----------------------------------------------------------------------
%% Convert a ActionRequest record into a binary
%% Return {ok, DeepIoList} | {error, Reason}
%%----------------------------------------------------------------------
encode_action_request(_EC, 1, _ActReq) ->
    %%     ?BIN_LIB:encode_action_request(EC, ActReq,
    %% 						?V1_ASN1_MOD, 
    %% 						?V1_TRANS_MOD,
    %% 						io_list);
    {error, not_implemented};
encode_action_request(_EC, 2, _ActReq) ->
    %%     ?BIN_LIB:encode_action_request(EC, ActReq,
    %% 						?V1_ASN1_MOD, 
    %% 						?V1_TRANS_MOD,
    %% 						io_list).
    {error, not_implemented};
encode_action_request(EC, 3, ActReq) ->
    %%     ?BIN_LIB:encode_action_request(EC, ActReq,
    %%                                          ?V3_ASN1_MOD,
    %%                                          ?V3_TRANS_MOD,
    %%                                          io_list).
    {error, not_implemented}.


%%----------------------------------------------------------------------
%% Convert a binary into a 'MegacoMessage' record
%% Return {ok, MegacoMessageRecord} | {error, Reason}
%%----------------------------------------------------------------------

%% Old decode function
decode_message(EC, Binary) ->
    decode_message(EC, 1, Binary).

%% PER does not support partial decode, so this means V1
decode_message(EC, dynamic, Binary) ->
    decode_message(EC, 1, Binary);

decode_message([{version3,_}|EC], 1, Binary) ->
    AsnMod   = ?V1_ASN1_MOD, 
    TransMod = ?V1_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);
decode_message(EC, 1, Binary) ->
    AsnMod   = ?V1_ASN1_MOD, 
    TransMod = ?V1_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);

decode_message([{version3,_}|EC], 2, Binary) ->
    AsnMod   = ?V2_ASN1_MOD, 
    TransMod = ?V2_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);
decode_message(EC, 2, Binary) ->
    AsnMod   = ?V2_ASN1_MOD, 
    TransMod = ?V2_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);

decode_message([{version3,v3}|EC], 3, Binary) ->
    AsnMod   = ?V3_ASN1_MOD, 
    TransMod = ?V3_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);
decode_message([{version3,prev3c}|EC], 3, Binary) ->
    AsnMod   = ?PREV3C_ASN1_MOD, 
    TransMod = ?PREV3C_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);
decode_message([{version3,prev3b}|EC], 3, Binary) ->
    AsnMod   = ?PREV3B_ASN1_MOD, 
    TransMod = ?PREV3B_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);
decode_message([{version3,prev3a}|EC], 3, Binary) ->
    AsnMod   = ?PREV3A_ASN1_MOD, 
    TransMod = ?PREV3A_TRANS_MOD, 
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary);
decode_message(EC, 3, Binary) ->
    AsnMod   = ?V3_ASN1_MOD,
    TransMod = ?V3_TRANS_MOD,
    ?BIN_LIB:decode_message(EC, Binary, AsnMod, TransMod, binary).

decode_mini_message(_EC, _Vsn, _Bin) ->
    {error, not_implemented}.

