%% ``The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% The Initial Developer of the Original Code is Ericsson Utvecklings AB.
%% Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
%% AB. All Rights Reserved.''
%% 
%%     $Id$
%%
-module(asn1rt).

%% Runtime functions for ASN.1 (i.e encode, decode)

-export([encode/2,encode/3,decode/3,load_driver/0]).
    
encode(Module,{Type,Term}) ->
    encode(Module,Type,Term).

encode(Module,Type,Term) ->
    case catch apply(Module,encode,[Type,Term]) of
	{'EXIT',undef} ->
	    {error,{asn1,{undef,Module,Type}}};
	Result ->
	    Result
    end.

decode(Module,Type,Bytes) ->
    case catch apply(Module,decode,[Type,Bytes]) of
	{'EXIT',undef} ->
	    {error,{asn1,{undef,Module,Type}}};
	Result ->
	    Result
    end.
	
load_driver() ->
    case asn1rt_per_bin_rt2ct:start_drv(self()) of
	ok ->
	    ok;
	Error ->
	    Error
    end.
    
