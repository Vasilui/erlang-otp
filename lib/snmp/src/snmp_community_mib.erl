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
-module(snmp_community_mib).

-export([configure/1, reconfigure/1,
	 snmpCommunityTable/1, snmpCommunityTable/3,
	 snmpTargetAddrExtTable/3,
	 community2vacm/2, vacm2community/2,
	 get_target_addr_ext_mms/2]).

-include("SNMP-COMMUNITY-MIB.hrl").
-include("SNMP-TARGET-MIB.hrl").
-include("SNMPv2-TC.hrl").

-define(VMODULE,"COMMUNITY-MIB").
-include("snmp_verbosity.hrl").

-ifndef(default_verbosity).
-define(default_verbosity,silence).
-endif.


%%%-----------------------------------------------------------------
%%% Implements the instrumentation functions and additional 
%%% functions for the SNMP-COMMUNITY-MIB.
%%% This MIB contains objects that makes it possible to use VACM
%%% with SNMPv1 and SNMPv2c.
%%%-----------------------------------------------------------------
%%-----------------------------------------------------------------
%% Func: configure/1
%% Args: Dir is the directory where the configuration files are found.
%% Purpose: If the tables doesn't exist, this function reads
%%          the config-files for the community mib tables, and
%%          inserts the data.  This means that the data in the tables
%%          survive a reboot.  However, the StorageType column is
%%          checked for each row.  If volatile, the row is deleted.
%% Returns: ok
%% Fails: exit(configuration_error)
%%-----------------------------------------------------------------
configure(Dir) ->
    set_sname(),
    case snmp_local_db:table_exists(db(snmpCommunityTable)) of
	true ->
	    ?vlog("community table exist: cleanup",[]),
	    gc_tabs();
	false ->
	    ?vlog("community table does not exist: reconfigure",[]),
	    reconfigure(Dir)
    end.

%%-----------------------------------------------------------------
%% Func: reconfigure/1
%% Args: Dir is the directory where the configuration files are found.
%% Purpose: Reads the config-files for the community mib tables, and
%%          inserts the data.  Makes sure that all old data in
%%          the tables are deleted, and the new data inserted.
%%          This function makes sure that all (and only) 
%%          config-file-data are in the tables. 
%% Returns: ok
%% Fails: exit(configuration_error)
%%-----------------------------------------------------------------
reconfigure(Dir) ->
    set_sname(),
    ?vdebug("read community config files",[]),
    Comms = snmp_conf:read_community_config_files(Dir),
    ?vdebug("initiate tables",[]),
    init_tabs(Comms).

init_tabs(Comms) ->
    ?vdebug("create community table",[]),
    snmp_local_db:table_delete(db(snmpCommunityTable)),
    snmp_local_db:table_create(db(snmpCommunityTable)),
    ?vdebug("invalidate cache",[]),
    invalidate_cache(),
    ?vdebug("initiate community table",[]),
    init_comm_table(Comms).
    
    
init_comm_table([Row | T]) ->
    Key = element(1, Row),
    table_create_row(snmpCommunityTable, Key, Row),
    update_cache(Key),
    init_comm_table(T);
init_comm_table([]) -> true.

table_create_row(Tab,Name,Row) ->
    ?vtrace("create table ~w row with Name: ~s",[Tab,Name]),
    snmp_local_db:table_create_row(db(Tab), Name, Row).


gc_tabs() ->
    gc_tab(snmpCommunityTable),
    ok.

gc_tab(Tab) ->
    STC = stc(Tab),
    F = fun(RowIndex, Row) ->
		case element(STC, Row) of
		    ?'StorageType_volatile' ->
			snmp_local_db:table_delete_row(db(Tab), RowIndex),
			invalidate_cache(RowIndex);
		    _ ->
			update_cache(RowIndex)
		end
	end,
    gc_tab1(F,Tab).


gc_tab1(F,Tab) ->
    case (catch snmp_generic:table_foreach(db(Tab), F)) of
	{'EXIT',{cyclic_db_reference,Oid}} ->
	    %% Remove the row regardless of storage type since this
	    %% is a major error. This row must be removed.
	    case snmp_local_db:table_delete_row(db(Tab), Oid) of
		true -> 
		    ?vlog("deleted cyclic ref row for: ~w",[Oid]),
		    config_err("cyclic reference in table ~w: "
			       "~w -> ~w. Row deleted", [Tab, Oid, Oid]),
		    gc_tab1(F,Tab);
		false ->
		    ?vlog("unable to remove faulty row from table ~w",[Tab]),
		    config_err("failed removing faulty row. "
			       "Giving up on table ~w cleanup", [Tab])
	    end;
	_ ->
	    ok
    end.


%%-----------------------------------------------------------------
%% API functions
%%-----------------------------------------------------------------
%%-----------------------------------------------------------------
%% We keep two caches for mapping;
%% one that maps CommunityName to CommunityIndex, and
%% one that maps 
%%     {SecName, ContextEngineId, ContextName} to {CommunityName, Tag}
%% Name -> Index instead of Name -> Vacm allows us to save a 
%% few bytes of memory, although it introduces an extra level of
%% indirection.
%%-----------------------------------------------------------------
community2vacm(Community, Addr) ->
    case ets:lookup(snmp_community_cache, Community) of
	Found when list(Found) ->
	    Fs = lists:keysort(2, Found),
	    loop_c2v_rows(Fs, Addr);
	_ ->
	    undefined
    end.

loop_c2v_rows([{_, CommunityIndex} | T], Addr) ->
    case get_row(CommunityIndex) of
	{_Community, VacmParams, Tag} ->
	    {TDomain, TAddr} = Addr,
	    case snmp_target_mib:is_valid_tag(Tag, TDomain, TAddr) of
		true ->
		    ?vtrace("loop_c2v_rows -> ~p valid tag", [Tag]),
		    VacmParams;
		false ->
		    ?vtrace("loop_c2v_rows -> ~p not valid tag", [Tag]),
		    loop_c2v_rows(T, Addr)
	    end;
	undefined ->
	    loop_c2v_rows(T, Addr)
    end;
loop_c2v_rows([], _Addr) ->
    undefined.


%%-----------------------------------------------------------------
%% Func: vacm2community(Vacm, {TDomain, TAddr}) -> 
%%         {ok, Community} | undefined
%% Types: Vacm = {SecName, ContextEngineId, ContextName}
%% Purpose: Follows the steps in draft-ietf-snmpv3-coex-03 section
%%          5.2.3 in order to find a community string to be used
%%          in a notification.
%%-----------------------------------------------------------------
vacm2community(Vacm, Addr) ->
    case ets:lookup(snmp_community_cache, Vacm) of
	Found when list(Found) ->
	    Fs = lists:keysort(2, Found),
	    loop_v2c_rows(Fs, Addr);
	_ ->
	    undefined
    end.
    
loop_v2c_rows([{_, {CommunityName, Tag}} | T], Addr) ->
    {TDomain, TAddr} = Addr,
    case snmp_target_mib:is_valid_tag(Tag, TDomain, TAddr) of
	true ->
	    {ok, CommunityName};
	false ->
	    loop_v2c_rows(T, Addr)
    end;
loop_v2c_rows([], _Addr) ->
    undefined.



get_row(RowIndex) ->
    case snmp_generic:table_get_row(db(snmpCommunityTable), RowIndex) of
	{_, CommunityName, SecName, ContextEngineId, ContextName,
	 TransportTag, _StorageType, ?'RowStatus_active'} ->
	    {CommunityName, {SecName, ContextEngineId, ContextName}, 
	     TransportTag};
	_ ->
	    undefined
    end.

invalidate_cache(RowIndex) ->
    case get_row(RowIndex) of
	{CommunityName, VacmParams, TransportTag} ->
	    ets:match_delete(snmp_community_cache,
			     {CommunityName, RowIndex}),
	    ets:match_delete(snmp_community_cache,
			     {VacmParams, {CommunityName, TransportTag}});
	undefined ->
	    ok
    end.

update_cache(RowIndex) ->
    case get_row(RowIndex) of
	{CommunityName, VacmParams, TransportTag} ->
	    ets:insert(snmp_community_cache, 
		       {CommunityName, RowIndex}), % CommunityIndex
	    ets:insert(snmp_community_cache, 
		       {VacmParams, {CommunityName, TransportTag}});
	undefined ->
	    ok
    end.

invalidate_cache() ->
    ets:match_delete(snmp_community_cache, {'_', '_'}).


get_target_addr_ext_mms(TDomain, TAddress) ->
    get_target_addr_ext_mms(TDomain, TAddress, []).
get_target_addr_ext_mms(TDomain, TAddress, Key) ->
    case snmp_target_mib:table_next(snmpTargetAddrTable, Key) of
	endOfTable -> 
	    false;
	NextKey -> 
	    case snmp_target_mib:get(
		   snmpTargetAddrTable, NextKey, [?snmpTargetAddrTDomain,
						  ?snmpTargetAddrTAddress,
						  12]) of
		[{value, TDomain}, {value, TAddress}, {value, MMS}] ->
		    {ok, MMS};
		_ ->
		    get_target_addr_ext_mms(TDomain, TAddress, NextKey)
	    end
    end.
%%-----------------------------------------------------------------
%% Instrumentation Functions
%%-----------------------------------------------------------------
%% Op == new | delete
snmpCommunityTable(Op) ->
    snmp_generic:table_func(Op, db(snmpCommunityTable)).

%% Op == get | is_set_ok | set | get_next
snmpCommunityTable(get, RowIndex, Cols) ->
    get(snmpCommunityTable, RowIndex, Cols);
snmpCommunityTable(get_next, RowIndex, Cols) ->
    next(snmpCommunityTable, RowIndex, Cols);
snmpCommunityTable(is_set_ok, RowIndex, Cols) ->
    LocalEngineID = snmp_framework_mib:get_engine_id(),
    NCols =
	case lists:keysearch(?snmpCommunityContextEngineID, 1, Cols) of
	    {value, {_, LocalEngineID}} -> Cols;
	    {value, _} -> 
		throw({inconsistentValue, ?snmpCommunityContextEngineID});
	    false -> kinsert(Cols, LocalEngineID)
	end,
    snmp_generic:table_func(is_set_ok, RowIndex, NCols, db(snmpCommunityTable));
snmpCommunityTable(set, RowIndex, Cols) ->
    invalidate_cache(RowIndex),
    Res = snmp_generic:table_func(set, RowIndex, Cols, db(snmpCommunityTable)),
    update_cache(RowIndex),
    Res;
snmpCommunityTable(Op, Arg1, Arg2) ->
    snmp_generic:table_func(Op, Arg1, Arg2, db(snmpCommunityTable)).

%% Op == get | is_set_ok | set | get_next
snmpTargetAddrExtTable(get, RowIndex, Cols) ->
    NCols = conv1(Cols),
    get(snmpTargetAddrExtTable, RowIndex, NCols);
snmpTargetAddrExtTable(get_next, RowIndex, Cols) ->
    NCols = conv1(Cols),
    conv2(next(snmpTargetAddrExtTable, RowIndex, NCols));
snmpTargetAddrExtTable(set, RowIndex, Cols) ->
    snmp_generic:table_func(set, RowIndex, Cols, db(snmpTargetAddrExtTable));
snmpTargetAddrExtTable(Op, Arg1, Arg2) ->
    snmp_generic:table_func(Op, Arg1, Arg2, db(snmpTargetAddrExtTable)).

db(snmpTargetAddrExtTable) -> {snmpTargetAddrTable, persistent};
db(X) -> {X, persistent}.

fa(snmpCommunityTable) -> ?snmpCommunityName;
fa(snmpTargetAddrExtTable) -> 11.
 
foi(snmpCommunityTable) -> ?snmpCommunityIndex;
foi(snmpTargetAddrExtTable) -> 11.
 
noc(snmpCommunityTable) -> 8;
noc(snmpTargetAddrExtTable) -> 12.

stc(snmpCommunityTable) -> ?snmpCommunityStorageType.
 
next(Name, RowIndex, Cols) ->
    snmp_generic:handle_table_next(db(Name), RowIndex, Cols,
                                   fa(Name), foi(Name), noc(Name)).

conv1([Col | T]) -> [Col + 10 | conv1(T)];
conv1([]) -> [].
     

conv2([{[Col | Oid], Val} | T]) ->
    [{[Col - 10 | Oid], Val} | conv2(T)];
conv2([X | T]) ->
    [X | conv2(T)];
conv2(X) -> X.

get(Name, RowIndex, Cols) ->
    snmp_generic:handle_table_get(db(Name), RowIndex, Cols, foi(Name)).

kinsert([H | T], EngineID) when element(1, H) < ?snmpCommunityContextEngineID ->
    [H | kinsert(T, EngineID)];
kinsert(Cols, EngineID) ->
    [{?snmpCommunityContextEngineID, EngineID} | Cols].


set_sname() ->
    set_sname(get(sname)).

set_sname(undefined) ->
    put(sname,conf);
set_sname(_) -> %% Keep it, if already set.
    ok.


config_err(F, A) ->
    snmp_error_report:config_err(F, A).
