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

%%%-------------------------------------------------------------------
%%% File    : erts_alloc_config.erl
%%% Author  : Rickard Green
%%% Description : Generate an erts_alloc configuration suitable for
%%%               a limited amount of runtime scenarios.
%%%
%%% Created :  9 May 2007 by Rickard Green
%%%-------------------------------------------------------------------

-module(erts_alloc_config).

-record(state, {have_scenario = false,
		alloc}).


-record(alloc, {name,
		enabled,
		alloc_util,
		low_mbc_blocks_size,
		high_mbc_blocks_size,
		sbct,
		segments}).

-record(conf,
	{segments,
	 format_to}).

-record(segment, {size,number}).

-define(PRINT_WITDH, 76).

-define(SERVER, '__erts_alloc_config__').

-define(KB, 1024).
-define(MB, 1048576).

-define(B2KB(B), ((((B) - 1) div ?KB) + 1)).
-define(ROUNDUP(V, R), ((((V) - 1) div (R)) + 1)*(R)).

-define(LARGE_GROWTH_ABS_LIMIT, 20*?MB).
-define(MBC_MSEG_LIMIT, 150).
-define(FRAG_FACT, 1.25).
-define(GROWTH_SEG_FACT, 2).
-define(MIN_SEG_SIZE, 1*?MB).
-define(SMALL_GROWTH_SEGS, 5).

-define(ALLOC_UTIL_ALLOCATOR(A),
	A == binary_alloc;
	A == std_alloc;
	A == ets_alloc;
	A == eheap_alloc;
	A == ll_alloc;
	A == sl_alloc;
	A == temp_alloc).

-define(ALLOCATORS,
	[binary_alloc,
	 ets_alloc,
	 eheap_alloc,
	 fix_alloc,
	 ll_alloc,
	 mseg_alloc,
	 sl_alloc,
	 std_alloc,
	 sys_alloc,
	 temp_alloc]).

-define(MMBCS_DEFAULTS,
	[{binary_alloc, 131072},
	 {std_alloc, 131072},
	 {ets_alloc, 131072},
	 {eheap_alloc, 524288},
	 {ll_alloc, 2097152},
	 {sl_alloc, 131072},
	 {temp_alloc, 131072}]).

-define(MMMBC_DEFAULTS,
	[{binary_alloc, 10},
	 {std_alloc, 10},
	 {ets_alloc, 10},
	 {eheap_alloc, 10},
	 {ll_alloc, 0},
	 {sl_alloc, 10},
	 {temp_alloc, 10}]).


%%%
%%% Exported interface
%%%

-export([save_scenario/0,
	 make_config/0,
	 make_config/1,
	 stop/0]).

%% Test and debug export
-export([state/0]).


save_scenario() ->
    req(save_scenario).

make_config() ->
    make_config(group_leader()).

make_config(FileName) when is_list(FileName) ->
    case file:open(FileName, [write]) of
	{ok, IODev} ->
	    Res = req({make_config, IODev}),
	    file:close(IODev),
	    Res;
	Error ->
	    Error
    end;
make_config(IODev) ->
    req({make_config, IODev}).

stop() ->
    req(stop).


%% state() is intentionally undocumented, and is for testing
%% and debugging only...

state() ->
    req(state).

%%%
%%% Server
%%%

req(Req) ->
    Ref = make_ref(),
    ReqMsg = {request, self(), Ref, Req},
    req(ReqMsg, Ref, true).

req(ReqMsg, Ref, TryStart) ->
    req(ReqMsg, Ref, TryStart, erlang:monitor(process, ?SERVER)).

req(ReqMsg, Ref, TryStart, Mon) ->
    (catch ?SERVER ! ReqMsg),
    receive
	{response, Ref, Res} ->
	    erlang:demonitor(Mon, [flush]),
	    Res;
	{'DOWN', Mon, _, _, noproc} ->
	    case TryStart of
		true -> start_server(Ref, ReqMsg);
		false -> {error, server_died}
	    end;
	{'DOWN', Mon, _, _, Reason} ->
	    {error, Reason}
    end.

start_server(Ref, ReqMsg) ->
    Starter = self(),
    Pid = spawn(fun () ->
			register(?SERVER, self()),
			Starter ! {Ref, self(), started},
			server_loop(make_state())
		end),
    Mon = erlang:monitor(process, Pid),
    receive
	{Ref, Pid, started} ->
	    req(ReqMsg, Ref, false, Mon);
	{'DOWN', Mon, _, _, _} ->
	    req(ReqMsg, Ref, false)
    end.

server_loop(State) ->
    NewState = receive
		   {request, From, Ref, save_scenario} ->
		       Alloc = save_scenario(State#state.alloc),
		       From ! {response, Ref, ok},
		       State#state{alloc = Alloc, have_scenario = true};
		   {request, From, Ref, {make_config, IODev}} ->
		       case State#state.have_scenario of
			   true ->
			       Conf = #conf{segments = ?MBC_MSEG_LIMIT,
					    format_to = IODev},
			       Res = mk_config(Conf, State#state.alloc),
			       From ! {response, Ref, Res};
			   _ ->
			       From ! {response, Ref, no_scenario_saved}
		       end,
		       State;
		   {request, From, Ref, stop} ->
		       From ! {response, Ref, ok},
		       exit(normal);
		   {request, From, Ref, state} ->
		       From ! {response, Ref, State},
		       State;
		   {request, From, Ref, Req} ->
		       From ! {response, Ref, {unknown_request, Req}},
		       State;
		   _ ->
		       State
	       end,
    server_loop(NewState).

make_state() ->
    #state{alloc = lists:map(fun (A) -> #alloc{name = A} end, ?ALLOCATORS)}.

%%
%% Save scenario
%%

ai_value(Key1, Key2, AI) ->
    case lists:keysearch(Key1, 1, AI) of
	{value, {Key1, Value1}} ->
	    case lists:keysearch(Key2, 1, Value1) of
		{value, Result} -> Result;
		_ -> undefined
	    end;
	_ -> undefined
    end.


chk_mbcs_blocks_size(#alloc{low_mbc_blocks_size = undefined,
			    high_mbc_blocks_size = undefined} = Alc,
		     Min,
		     Max) ->
    Alc#alloc{low_mbc_blocks_size = Min,
	      high_mbc_blocks_size = Max,
	      enabled = true};
chk_mbcs_blocks_size(#alloc{low_mbc_blocks_size = LowBS,
			    high_mbc_blocks_size = HighBS} = Alc,
		     Min,
		     Max) ->
    true = is_integer(LowBS),
    true = is_integer(HighBS),
    Alc1 = case Min < LowBS of
	       true -> Alc#alloc{low_mbc_blocks_size = Min};
	       false -> Alc
	   end,
    case Max > HighBS of
	true -> Alc1#alloc{high_mbc_blocks_size = Max};
	false -> Alc1
    end.

set_alloc_util(#alloc{alloc_util = AU} = Alc, AU) ->
    Alc;
set_alloc_util(Alc, Val) ->
    Alc#alloc{alloc_util = Val}.

chk_sbct(#alloc{sbct = undefined} = Alc, AI) ->
    case ai_value(options, sbct, AI) of
	{sbct, Bytes} when is_integer(Bytes) -> Alc#alloc{sbct = b2kb(Bytes)};
	_ -> Alc
    end;
chk_sbct(Alc, _AI) ->
    Alc.

save_scenario(AlcList) ->
    %% The high priority is not really necessary. It is
    %% used since it will make retrieval of allocator
    %% information less spread out in time on a highly
    %% loaded system.
    OP = process_flag(priority, high),
    Res = do_save_scenario(AlcList),
    process_flag(priority, OP),
    Res.
    
do_save_scenario(AlcList) ->
    lists:map(fun (#alloc{enabled = false} = Alc) ->
		      Alc;
		  (#alloc{name = Name} = Alc) ->
		      case erlang:system_info({allocator, Name}) of
			  undefined ->
			      exit({bad_allocator_name, Name});
			  false ->
			      Alc#alloc{enabled = false};
			  AI when is_list(AI) ->
			      Alc1 = chk_sbct(Alc, AI),
			      case ai_value(mbcs, blocks_size, AI) of
				  {blocks_size, MinBS, _, MaxBS} ->
				      set_alloc_util(chk_mbcs_blocks_size(Alc1,
									  MinBS,
									  MaxBS),
						     true);
				  _ ->
				      set_alloc_util(Alc, false)
			      end
		      end
	      end,
	      AlcList).

%%
%% Make configuration
%%

conf_size(Bytes) when is_integer(Bytes), Bytes < 0 ->
    exit({bad_value, Bytes});
conf_size(Bytes) when is_integer(Bytes), Bytes < 1*?MB ->
    ?ROUNDUP(?B2KB(Bytes), 128);
conf_size(Bytes) when is_integer(Bytes), Bytes < 10*?MB ->
    ?ROUNDUP(?B2KB(Bytes), ?B2KB(1*?MB));
conf_size(Bytes) when is_integer(Bytes), Bytes < 100*?MB ->
    ?ROUNDUP(?B2KB(Bytes), ?B2KB(2*?MB));
conf_size(Bytes) when is_integer(Bytes), Bytes < 256*?MB ->
    ?ROUNDUP(?B2KB(Bytes), ?B2KB(5*?MB));
conf_size(Bytes) when is_integer(Bytes) ->
    ?ROUNDUP(?B2KB(Bytes), ?B2KB(10*?MB)).

sbct(#conf{format_to = FTO}, #alloc{name = A, sbct = SBCT}) ->
    fc(FTO, "Sbc threshold size of ~p kilobytes.", [SBCT]),
    format(FTO, " +M~csbct ~p~n", [alloc_char(A), SBCT]).

mmbcs(#conf{format_to = FTO},
      #alloc{name = A, low_mbc_blocks_size = BlocksSize}) ->
    {value, {A, MMBCS_Default}} = lists:keysearch(A, 1, ?MMBCS_DEFAULTS),
    if BlocksSize > MMBCS_Default ->
	    MMBCS = conf_size(BlocksSize),
	    fc(FTO, "Main mbc size of ~p kilobytes.", [MMBCS]),
	    format(FTO, " +M~cmmbcs ~p~n", [alloc_char(A), MMBCS]);
       true ->
	    ok
    end.

smbcs_lmbcs_mmmbc(#conf{format_to = FTO},
		  #alloc{name = A, segments = Segments}) ->
    MMMBC = Segments#segment.number,
    MBCS = Segments#segment.size,
    AC = alloc_char(A),
    fc(FTO, "Mseg mbc size of ~p kilobytes.", [MBCS]),
    format(FTO, " +M~csmbcs ~p +M~clmbcs ~p~n", [AC, MBCS, AC, MBCS]),
    fc(FTO, "Max ~p mseg mbcs.", [MMMBC]),
    format(FTO, " +M~cmmmbc ~p~n", [AC, MMMBC]),
    ok.

alloc_char(binary_alloc) -> $B;
alloc_char(std_alloc) -> $D;
alloc_char(ets_alloc) -> $E;
alloc_char(fix_alloc) -> $F;
alloc_char(eheap_alloc) -> $H;
alloc_char(ll_alloc) -> $L;
alloc_char(mseg_alloc) -> $M;
alloc_char(sl_alloc) -> $S;
alloc_char(temp_alloc) -> $T;
alloc_char(sys_alloc) -> $Y;
alloc_char(Alloc) ->
    exit({bad_allocator, Alloc}).

conf_alloc(#conf{format_to = FTO},
	   #alloc{name = A, enabled = false}) ->
    fcl(FTO, A),
    fcp(FTO,
	"WARNING: ~p has been disabled. Consider enabling ~p and rerun "
	"erts_alloc_config.",
	[A,A]);
conf_alloc(#conf{format_to = FTO} = Conf,
	   #alloc{name = A, alloc_util = true} = Alc) ->
    fcl(FTO, A),
    chk_xnote(Conf, Alc),
    au_conf_alloc(Conf, Alc),
    format(FTO, "#~n", []);
conf_alloc(#conf{format_to = FTO} = Conf, #alloc{name = A} = Alc) ->
    fcl(FTO, A),
    chk_xnote(Conf, Alc).

chk_xnote(#conf{format_to = FTO},
	  #alloc{name = fix_alloc}) ->
    fcp(FTO, "Cannot be configured.");
chk_xnote(#conf{format_to = FTO},
	  #alloc{name = sys_alloc}) ->
    fcp(FTO, "Cannot be configured. Default malloc implementation used.");
chk_xnote(#conf{format_to = FTO},
	  #alloc{name = mseg_alloc}) ->
    fcp(FTO, "Default configuration used.");
chk_xnote(#conf{format_to = FTO},
	  #alloc{name = ll_alloc}) ->
    fcp(FTO,
	"Note, blocks allocated with ll_alloc are very "
	"seldom deallocated. Placing blocks in mseg "
	"carriers is therefore very likely only a waste "
	"of resources.");
chk_xnote(#conf{}, #alloc{}) ->
    ok.

au_conf_alloc(#conf{format_to = FTO} = Conf,
	      #alloc{alloc_util = true,
		     low_mbc_blocks_size = Low,
		     high_mbc_blocks_size = High} = Alc) ->
    fcp(FTO, "Usage of mbcs: ~p - ~p kilobytes", [?B2KB(Low), ?B2KB(High)]),
    mmbcs(Conf, Alc),
    smbcs_lmbcs_mmmbc(Conf, Alc),
    sbct(Conf, Alc).

large_growth(Low, High) ->
    High - Low >= ?LARGE_GROWTH_ABS_LIMIT.

calc_seg_size(Growth, Segs) ->
    conf_size(round(Growth*?FRAG_FACT*?GROWTH_SEG_FACT) div Segs).

calc_growth_segments(Conf, AlcList0) ->
    CalcSmall = fun (#alloc{name = ll_alloc} = Alc, Acc) ->
			{Alc#alloc{segments = #segment{size = 0,
						       number = 0}},
			 Acc};
		    (#alloc{alloc_util = true,
			    low_mbc_blocks_size = Low,
			    high_mbc_blocks_size = High} = Alc,
		     {SL, AL}) ->
			Growth = High - Low,
			case large_growth(Low, High) of
			    true ->
				{Alc, {SL, AL+1}};
			    false ->
				Segs = ?SMALL_GROWTH_SEGS,
				SegSize = calc_seg_size(Growth, Segs),
				{Alc#alloc{segments
					   = #segment{size = SegSize,
						      number = Segs}},
				 {SL - Segs, AL}}

			end;
		    (Alc, Acc) -> {Alc, Acc}
		end,
    {AlcList1, {SegsLeft, AllocsLeft}}
	= lists:mapfoldl(CalcSmall, {Conf#conf.segments, 0}, AlcList0),
    case AllocsLeft of
	0 ->
	    AlcList1;
	_ ->
	    SegsPerAlloc = case (SegsLeft div AllocsLeft) + 1 of
			       SPA when SPA < ?SMALL_GROWTH_SEGS ->
				   ?SMALL_GROWTH_SEGS;
			       SPA ->
				   SPA
			   end,
	    CalcLarge = fun (#alloc{alloc_util = true,
				    segments = undefined,
				    low_mbc_blocks_size = Low,
				    high_mbc_blocks_size = High} = Alc) ->
				Growth = High - Low,
				SegSize = calc_seg_size(Growth,
							SegsPerAlloc),
				Alc#alloc{segments
					  = #segment{size = SegSize,
						     number = SegsPerAlloc}};
			    (Alc) ->
				Alc
			end,
	    lists:map(CalcLarge, AlcList1)
    end.

mk_config(#conf{format_to = FTO} = Conf, AlcList) ->
    format_header(FTO),
    Res = lists:foreach(fun (Alc) -> conf_alloc(Conf, Alc) end,
			calc_growth_segments(Conf, AlcList)),
    format_footer(FTO),
    Res.

format_header(FTO) ->
    {Y,Mo,D} = erlang:date(),
    {H,Mi,S} = erlang:time(),
    fcl(FTO),
    fcl(FTO, "erts_alloc configuration"),
    fcl(FTO),
    fcp(FTO,
	"This erts_alloc configuration was automatically "
	"generated at ~w-~2..0w-~2..0w ~2..0w:~2..0w.~2..0w by "
	"erts_alloc_config.",
	[Y, Mo, D, H, Mi, S]),
    fcp(FTO,
	"~s was used when generating the configuration.",
	[string:strip(erlang:system_info(system_version), both, $\n)]),
    fcp(FTO,
	"This configuration is intended as a suggestion and "
	"may need to be adjusted manually. Instead of modifying "
	"this file, you are advised to write another configuration "
	"file and override values that you want to change. "
	"Doing it this way simplifies things when you want to "
	"rerun erts_alloc_config."),
    fcp(FTO,
	"This configuration is based on the actual use of "
	"multi-block carriers (mbcs) for a set of different "
	"runtime scenarios. Note that this configuration may "
	"perform bad, ever horrible, for other runtime "
	"scenarios."),
    fcp(FTO,
	"You are advised to rerun erts_alloc_config if the "
	"applications run when the configuration was made "
	"are changed, or if the load on the applications have "
	"changed since the configuration was made. You are also "
	"advised to rerun erts_alloc_config if the Erlang runtime "
	"system used is changed."),
    fcp(FTO,
	"Note, that the singel-block carrier (sbc) parameters "
	"very much effects the use of mbcs. Therefore, if you "
	"change the sbc parameters, you are advised to rerun "
	"erts_alloc_config."),
    fcp(FTO,
	"For more information see the erts_alloc_config(3) "
	"documentation."),
    ok.

format_footer(FTO) ->
    fcl(FTO).

%%%
%%% Misc.
%%%

b2kb(B) when is_integer(B) ->
    MaxKB = (1 bsl erlang:system_info(wordsize)*8) div 1024,
    case ?B2KB(B) of
	KB when KB > MaxKB -> MaxKB;
	KB -> KB
    end.

format(false, _Frmt) ->
    ok;
format(IODev, Frmt) ->
    io:format(IODev, Frmt, []).

format(false, _Frmt, _Args) ->
    ok;
format(IODev, Frmt, Args) ->
    io:format(IODev, Frmt, Args).

%% fcp: format comment paragraf
fcp(IODev, Frmt, Args) ->
    fc(IODev, Frmt, Args),
    format(IODev, "#~n").

fcp(IODev, Frmt) ->
    fc(IODev, Frmt),
    format(IODev, "#~n").

%% fc: format comment
fc(IODev, Frmt, Args) ->
    fc(IODev, lists:flatten(io_lib:format(Frmt, Args))).

fc(IODev, String) ->
    fc_aux(IODev, string:tokens(String, " "), 0).

fc_aux(_IODev, [], 0) ->
    ok;
fc_aux(IODev, [], _Len) ->
    format(IODev, "~n");
fc_aux(IODev, [T|Ts], 0) ->
    Len = 2 + length(T),
    format(IODev, "# ~s", [T]),
    fc_aux(IODev, Ts, Len);
fc_aux(IODev, [T|_Ts] = ATs, Len) when (length(T) + Len) >= ?PRINT_WITDH ->
    format(IODev, "~n"),
    fc_aux(IODev, ATs, 0);
fc_aux(IODev, [T|Ts], Len) ->
    NewLen = Len + 1 + length(T),
    format(IODev, " ~s", [T]),
    fc_aux(IODev, Ts, NewLen).

%% fcl: format comment line
fcl(FTO) ->
    EndStr = "# ",
    Precision = length(EndStr),
    FieldWidth = -1*(?PRINT_WITDH),
    format(FTO, "~*.*.*s~n", [FieldWidth, Precision, $-, EndStr]).

fcl(FTO, A) when is_atom(A) ->
    fcl(FTO, atom_to_list(A));
fcl(FTO, Str) when is_list(Str) ->
    Str2 = "# --- " ++ Str ++ " ",
    Precision = length(Str2),
    FieldWidth = -1*(?PRINT_WITDH),
    format(FTO, "~*.*.*s~n", [FieldWidth, Precision, $-, Str2]).
