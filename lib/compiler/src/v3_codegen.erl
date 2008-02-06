%% -*- erlang-indent-level: 4 -*-
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
%% Purpose : Code generator for Beam.

%% The following assumptions have been made:
%%
%% 1. Matches, i.e. things with {match,M,Ret} wrappers, only return
%% values; no variables are exported. If the match would have returned
%% extra variables then these have been transformed to multiple return
%% values.
%% 
%% 2. All BIF's called in guards are gc-safe so there is no need to
%% put thing on the stack in the guard.  While this would in principle
%% work it would be difficult to keep track of the stack depth when
%% trimming.
%%
%% The code generation uses variable lifetime information added by
%% the v3_life module to save variables, allocate registers and 
%% move registers to the stack when necessary.
%%
%% We try to use a consistent variable name scheme throughout.  The
%% StackReg record is always called Bef,Int<n>,Aft.

-module(v3_codegen).

%% The main interface.
-export([module/2]).

-import(lists, [member/2,keymember/3,keysort/2,keysearch/3,keydelete/3,
		append/1,map/2,flatmap/2,filter/2,foldl/3,foldr/3,mapfoldl/3,
		sort/1,reverse/1,reverse/2]).
-import(v3_life, [vdb_find/2]).

%%-compile([export_all]).

-include("v3_life.hrl").

%% Main codegen structure.
-record(cg, {lcount=1,				%Label counter
	     finfo,				%Function info label
	     btype,				%Type of bif used.
	     bfail,				%Fail label of bif
	     break,				%Break label
	     recv,				%Receive label
	     is_top_block,			%Boolean: top block or not
	     functable=gb_trees:empty(),	%Gb tree of local functions:
						% {{Name,Arity},Label}
	     in_catch=false,			%Inside a catch or not.
	     need_frame				%Need a stack frame.
	    }).			

%% Stack/register state record.
-record(sr, {reg=[],				%Register table
	     stk=[],				%Stack table
	     res=[]}).				%Reserved regs: [{reserved,I,V}]

module({Mod,Exp,Attr,Forms}, Options) ->
    put(?MODULE, Options),
    {Fs,St} = functions(Forms, {atom,Mod}),
    erase(?MODULE),
    {ok,{Mod,Exp,Attr,Fs,St#cg.lcount}}.

functions(Forms, AtomMod) ->
    mapfoldl(fun (F, St) -> function(F, AtomMod, St) end, #cg{lcount=1}, Forms).

function({function,Name,Arity,As0,Vb,Vdb}, AtomMod, St0) ->
    %%ok = io:fwrite("cg ~w:~p~n", [?LINE,{Name,Arity}]),
    try
	{Asm,EntryLabel,St} = cg_fun(Vb, As0, Vdb, AtomMod, {Name,Arity}, St0),
	Func = {function,Name,Arity,EntryLabel,Asm},
	{Func,St}
    catch
	Class:Error ->
	    Stack = erlang:get_stacktrace(),
	    io:fwrite("Function: ~w/~w\n", [Name,Arity]),
	    erlang:raise(Class, Error, Stack)
    end.

%% cg_fun([Lkexpr], [HeadVar], Vdb, State) -> {[Ainstr],State}

cg_fun(Les, Hvs, Vdb, AtomMod, NameArity, St0) ->
    {Fi,St1} = new_label(St0),			%FuncInfo label
    {Fl,St2} = local_func_label(NameArity, St1),

    %% Create initial stack/register state, clear unused arguments.
    Bef = clear_dead(#sr{reg=foldl(fun ({var,V}, Reg) ->
					   put_reg(V, Reg)
				   end, [], Hvs),
			stk=[]}, 0, Vdb),
    {B2,_Aft,St3} = cg_list(Les, 0, Vdb, Bef, St2#cg{btype=exit,
						     bfail=Fi,
						     finfo=Fi,
						     is_top_block=true}),
    {Name,Arity} = NameArity,
    A = [{label,Fi},{func_info,AtomMod,{atom,Name},Arity},
	 {label,Fl}|B2],
    {A,Fl,St3}.

%% cg(Lkexpr, Vdb, StackReg, State) -> {[Ainstr],StackReg,State}.
%%  Generate code for a kexpr.
%%  Split function into two steps for clarity, not efficiency.

cg(Le, Vdb, Bef, St) ->
    cg(Le#l.ke, Le, Vdb, Bef, St).

cg({block,Es}, Le, Vdb, Bef, St) ->
    block_cg(Es, Le, Vdb, Bef, St);
cg({match,M,Rs}, Le, Vdb, Bef, St) ->
    match_cg(M, Rs, Le, Vdb, Bef, St);
cg({match_fail,F}, Le, Vdb, Bef, St) ->
    match_fail_cg(F, Le, Vdb, Bef, St);
cg({call,Func,As,Rs}, Le, Vdb, Bef, St) ->
    call_cg(Func, As, Rs, Le, Vdb, Bef, St);
cg({enter,Func,As}, Le, Vdb, Bef, St) ->
    enter_cg(Func, As, Le, Vdb, Bef, St);
cg({bif,Bif,As,Rs}, Le, Vdb, Bef, St) ->
    bif_cg(Bif, As, Rs, Le, Vdb, Bef, St);
cg({gc_bif,Bif,As,Rs}, Le, Vdb, Bef, St) ->
    gc_bif_cg(Bif, As, Rs, Le, Vdb, Bef, St);
cg({receive_loop,Te,Rvar,Rm,Tes,Rs}, Le, Vdb, Bef, St) ->
    recv_loop_cg(Te, Rvar, Rm, Tes, Rs, Le, Vdb, Bef, St);
cg(receive_next, Le, Vdb, Bef, St) ->
    recv_next_cg(Le, Vdb, Bef, St);
cg(receive_accept, _Le, _Vdb, Bef, St) -> {[remove_message],Bef,St};
cg({'try',Ta,Vs,Tb,Evs,Th,Rs}, Le, Vdb, Bef, St) ->
    try_cg(Ta, Vs, Tb, Evs, Th, Rs, Le, Vdb, Bef, St);
cg({try_enter,Ta,Vs,Tb,Evs,Th}, Le, Vdb, Bef, St) ->
    try_enter_cg(Ta, Vs, Tb, Evs, Th, Le, Vdb, Bef, St);
cg({'catch',Cb,R}, Le, Vdb, Bef, St) ->
    catch_cg(Cb, R, Le, Vdb, Bef, St);
cg({set,Var,Con}, Le, Vdb, Bef, St) ->
    set_cg(Var, Con, Le, Vdb, Bef, St);
cg({return,Rs}, Le, Vdb, Bef, St) -> return_cg(Rs, Le, Vdb, Bef, St);
cg({break,Bs}, Le, Vdb, Bef, St) -> break_cg(Bs, Le, Vdb, Bef, St);
cg({need_heap,H}, _Le, _Vdb, Bef, St) ->
    {[{test_heap,H,max_reg(Bef#sr.reg)}],Bef,St}.

%% cg_list([Kexpr], FirstI, Vdb, StackReg, St) -> {[Ainstr],StackReg,St}.

cg_list(Kes, I, Vdb, Bef, St0) ->
    {Keis,{Aft,St1}} =
	flatmapfoldl(fun (Ke, {Inta,Sta}) ->
			     {Keis,Intb,Stb} = cg(Ke, Vdb, Inta, Sta),
			     {comment(Inta) ++ Keis,{Intb,Stb}}
		     end, {Bef,St0}, need_heap(Kes, I)),
    {Keis,Aft,St1}.

%% need_heap([Lkexpr], I, St) -> [Lkexpr].
%%  Insert need_heap instructions in Kexpr list.  Try to be smart and
%%  collect them together as much as possible.

need_heap(Kes0, I) ->
    {Kes,H} = need_heap_0(reverse(Kes0), 0, []),

    %% Prepend need_heap if necessary.
    need_heap_need(I, H) ++ Kes.

need_heap_0([Ke|Kes], H0, Acc) ->
    {Ns,H} = need_heap_1(Ke, H0),
    need_heap_0(Kes, H, [Ke|Ns]++Acc);
need_heap_0([], H, Acc) ->
    {Acc,H}.

need_heap_1(#l{ke={set,_,{binary,_}},i=I}, H) ->
    {need_heap_need(I, H),0};
need_heap_1(#l{ke={set,_,Val}}, H) ->
    %% Just pass through adding to needed heap.
    {[],H + case Val of
		{cons,_} -> 2;
		{tuple,Es} -> 1 + length(Es);
		{string,S} -> 2 * length(S);
		_Other -> 0
	    end};
need_heap_1(#l{ke={bif,dsetelement,_As,_Rs},i=I}, H) ->
    {need_heap_need(I, H),0};
need_heap_1(#l{ke={bif,{make_fun,_,_,_,_},_As,_Rs},i=I}, H) ->
    {need_heap_need(I, H),0};
need_heap_1(#l{ke={bif,bs_init_writable,_As,_Rs},i=I}, H) ->
    {need_heap_need(I, H),0};
need_heap_1(#l{ke={bif,_Bif,_As,_Rs}}, H) ->
    {[],H};
need_heap_1(#l{i=I}, H) ->
    {need_heap_need(I, H),0}.

need_heap_need(_I, 0) -> [];
need_heap_need(I, H) -> [#l{ke={need_heap,H},i=I}].

%% match_cg(Match, [Ret], Le, Vdb, StackReg, State) ->
%%	{[Ainstr],StackReg,State}.
%%  Generate code for a match.  First save all variables on the stack
%%  that are to survive after the match.  We leave saved variables in
%%  their registers as they might actually be in the right place.

match_cg(M, Rs, Le, Vdb, Bef, St0) ->
    I = Le#l.i,
    {Sis,Int0} = adjust_stack(Bef, I, I+1, Vdb),
    {B,St1} = new_label(St0),
    {Mis,Int1,St2} = match_cg(M, none, Int0, St1#cg{break=B}),
    %% Put return values in registers.
    Reg = load_vars(Rs, Int1#sr.reg),
    {Sis ++ Mis ++ [{label,B}],
     clear_dead(Int1#sr{reg=Reg}, I, Vdb),
     St2#cg{break=St1#cg.break}}.

%% match_cg(Match, Fail, StackReg, State) -> {[Ainstr],StackReg,State}.
%%  Generate code for a match tree.  N.B. there is no need pass Vdb
%%  down as each level which uses this takes its own internal Vdb not
%%  the outer one.

match_cg(Le, Fail, Bef, St) ->
    match_cg(Le#l.ke, Le, Fail, Bef, St).

match_cg({alt,F,S}, _Le, Fail, Bef, St0) ->
    {Tf,St1} = new_label(St0),
    {Fis,Faft,St2} = match_cg(F, Tf, Bef, St1),
    {Sis,Saft,St3} = match_cg(S, Fail, Bef, St2),
    Aft = sr_merge(Faft, Saft),
    {Fis ++ [{label,Tf}] ++ Sis,Aft,St3};
match_cg({select,{var,Vname}=V,Scs0}, #l{a=Anno}, Fail, Bef, St) ->
    ReuseForContext = member(reuse_for_context, Anno) andalso
	find_reg(Vname, Bef#sr.reg) =/= error,
    Scs = case ReuseForContext of
	      false -> Scs0;
	      true -> bsm_rename_ctx(Scs0, Vname)
	  end,
    match_fmf(fun (S, F, Sta) ->
		      select_cg(S, V, F, Fail, Bef, Sta) end,
	      Fail, St, Scs);
match_cg({guard,Gcs}, _Le, Fail, Bef, St) ->
    match_fmf(fun (G, F, Sta) -> guard_clause_cg(G, F, Bef, Sta) end,
	      Fail, St, Gcs);
match_cg({block,Es}, Le, _Fail, Bef, St) ->
    %% Must clear registers and stack of dead variables.
    Int = clear_dead(Bef, Le#l.i, Le#l.vdb),
    block_cg(Es, Le, Int, St).

%% match_fail_cg(FailReason, Le, Vdb, StackReg, State) ->
%%	{[Ainstr],StackReg,State}.
%%  Generate code for the match_fail "call".  N.B. there is no generic
%%  case for when the fail value has been created elsewhere.

match_fail_cg({function_clause,As}, Le, Vdb, Bef, St) ->
    %% Must have the args in {x,0}, {x,1},...
    {Sis,Int} = cg_setup_call(As, Bef, Le#l.i, Vdb),
    {Sis ++ [{jump,{f,St#cg.finfo}}],
     Int#sr{reg=clear_regs(Int#sr.reg)},St};
match_fail_cg({badmatch,Term}, Le, Vdb, Bef, St) ->
    R = cg_reg_arg(Term, Bef),
    Int0 = clear_dead(Bef, Le#l.i, Vdb),
    {Sis,Int} = adjust_stack(Int0, Le#l.i, Le#l.i+1, Vdb),
    {Sis ++ [{badmatch,R}],
     Int#sr{reg=clear_regs(Int0#sr.reg)},St};
match_fail_cg({case_clause,Reason}, Le, Vdb, Bef, St) ->
    R = cg_reg_arg(Reason, Bef),
    Int0 = clear_dead(Bef, Le#l.i, Vdb),
    {Sis,Int} = adjust_stack(Int0, Le#l.i, Le#l.i+1, Vdb),
    {Sis++[{case_end,R}],
     Int#sr{reg=clear_regs(Bef#sr.reg)},St};
match_fail_cg(if_clause, Le, Vdb, Bef, St) ->
    Int0 = clear_dead(Bef, Le#l.i, Vdb),
    {Sis,Int1} = adjust_stack(Int0, Le#l.i, Le#l.i+1, Vdb),
    {Sis++[if_end],Int1#sr{reg=clear_regs(Int1#sr.reg)},St};
match_fail_cg({try_clause,Reason}, Le, Vdb, Bef, St) ->
    R = cg_reg_arg(Reason, Bef),
    Int0 = clear_dead(Bef, Le#l.i, Vdb),
    {Sis,Int} = adjust_stack(Int0, Le#l.i, Le#l.i+1, Vdb),
    {Sis ++ [{try_case_end,R}],
     Int#sr{reg=clear_regs(Int0#sr.reg)},St}.

%% bsm_rename_ctx([Clause], Var) -> [Clause]
%%  We know from an annotation that the register for a binary can
%%  be reused for the match context because the two are not truly
%%  alive at the same time (even though the conservative life time
%%  information calculated by v3_life says so).
%%
%%  The easiest way to have those variables share the same register is
%%  to rename the variable with the shortest life-span (the match
%%  context) to the variable for the binary (which can have a very
%%  long life-time because it is locked during matching). We KNOW that
%%  the match state variable will only be alive during the matching.
%%
%%  We must also remove all information about the match context
%%  variable from all life-time information databases (Vdb).

bsm_rename_ctx([#l{ke={type_clause,binary,
		       [#l{ke={val_clause,{binary,{var,Old}},Ke0}}=L2]}}=L1|Cs], New) ->
    Ke = bsm_rename_ctx(Ke0, Old, New, false),
    [L1#l{ke={type_clause,binary,
	      [L2#l{ke={val_clause,{binary,{var,New}},Ke}}]}}|bsm_rename_ctx(Cs, New)];
bsm_rename_ctx([C|Cs], New) ->
    [C|bsm_rename_ctx(Cs, New)];
bsm_rename_ctx([], _) -> [].

%% bsm_rename_ctx(Ke, OldName, NewName, InProt) -> Ke'
%%  Rename and clear OldName from life-time information. We must
%%  recurse into any block contained in a protected, but it would
%%  only complicatate things to recurse into blocks not in a protected
%%  (the match context variable will is not live inside them).

bsm_rename_ctx(#l{ke={select,{var,V},Cs0}}=L, Old, New, InProt) ->
    Cs = bsm_rename_ctx_list(Cs0, Old, New, InProt),
    L#l{ke={select,{var,bsm_rename_var(V, Old, New)},Cs}};
bsm_rename_ctx(#l{ke={type_clause,Type,Cs0}}=L, Old, New, InProt) ->
    Cs = bsm_rename_ctx_list(Cs0, Old, New, InProt),
    L#l{ke={type_clause,Type,Cs}};
bsm_rename_ctx(#l{ke={val_clause,{bin_end,V},Ke0}}=L, Old, New, InProt) ->
    Ke = bsm_rename_ctx(Ke0, Old, New, InProt),
    L#l{ke={val_clause,{bin_end,bsm_rename_var(V, Old, New)},Ke}};
bsm_rename_ctx(#l{ke={val_clause,{bin_seg,V,Sz,U,Type,Fl,Vs},Ke0}}=L,
	       Old, New, InProt) ->
    Ke = bsm_rename_ctx(Ke0, Old, New, InProt),
    L#l{ke={val_clause,{bin_seg,bsm_rename_var(V, Old, New),Sz,U,Type,Fl,Vs},Ke}};
bsm_rename_ctx(#l{ke={val_clause,{bin_int,V,Sz,U,Fl,Val,Vs},Ke0}}=L,
	       Old, New, InProt) ->
    Ke = bsm_rename_ctx(Ke0, Old, New, InProt),
    L#l{ke={val_clause,{bin_int,bsm_rename_var(V, Old, New),Sz,U,Fl,Val,Vs},Ke}};
bsm_rename_ctx(#l{ke={val_clause,Val,Ke0}}=L, Old, New, InProt) ->
    Ke = bsm_rename_ctx(Ke0, Old, New, InProt),
    L#l{ke={val_clause,Val,Ke}};
bsm_rename_ctx(#l{ke={alt,F0,S0}}=L, Old, New, InProt) ->
    F = bsm_rename_ctx(F0, Old, New, InProt),
    S = bsm_rename_ctx(S0, Old, New, InProt),
    L#l{ke={alt,F,S}};
bsm_rename_ctx(#l{ke={guard,Gcs0}}=L, Old, New, InProt) ->
    Gcs = bsm_rename_ctx_list(Gcs0, Old, New, InProt),
    L#l{ke={guard,Gcs}};
bsm_rename_ctx(#l{ke={guard_clause,G0,B0}}=L, Old, New, InProt) ->
    G = bsm_rename_ctx(G0, Old, New, InProt),
    B = bsm_rename_ctx(B0, Old, New, InProt),
    %% A guard clause may cause unsaved variables to be saved on the stack.
    %% Since the match state variable Old is an alias for New (uses the
    %% same register), it is neither in the stack nor register descriptor
    %% lists and we would crash when we didn't find it unless we remove
    %% it from the database.
    bsm_forget_var(L#l{ke={guard_clause,G,B}}, Old);
bsm_rename_ctx(#l{ke={protected,Ts0,Rs}}=L, Old, New, _InProt) ->
    InProt = true,
    Ts = bsm_rename_ctx_list(Ts0, Old, New, InProt),
    bsm_forget_var(L#l{ke={protected,Ts,Rs}}, Old);
bsm_rename_ctx(#l{ke={match,Ms0,Rs}}=L, Old, New, InProt) ->
    Ms = bsm_rename_ctx(Ms0, Old, New, InProt),
    L#l{ke={match,Ms,Rs}};
bsm_rename_ctx(#l{ke={test,_,_}}=L, _, _, _) -> L;
bsm_rename_ctx(#l{ke={bif,_,_,_}}=L, _, _, _) -> L;
bsm_rename_ctx(#l{ke={gc_bif,_,_,_}}=L, _, _, _) -> L;
bsm_rename_ctx(#l{ke={set,_,_}}=L, _, _, _) -> L;
bsm_rename_ctx(#l{ke={block,_}}=L, Old, _, false) ->
    %% This block is not inside a protected. The match context variable cannot
    %% possibly be live inside the block.
    bsm_forget_var(L, Old);
bsm_rename_ctx(#l{ke={block,Bl0}}=L, Old, New, true) ->
    %% A block in a protected. We must recursively rename the variable
    %% inside the block.
    Bl = bsm_rename_ctx_list(Bl0, Old, New, true),
    bsm_forget_var(L#l{ke={block,Bl}}, Old);
bsm_rename_ctx(#l{ke={break,_}}=L, Old, _New, _InProt) ->
    bsm_forget_var(L, Old).

bsm_rename_ctx_list([C|Cs], Old, New, InProt) ->
    [bsm_rename_ctx(C, Old, New, InProt)|
     bsm_rename_ctx_list(Cs, Old, New, InProt)];
bsm_rename_ctx_list([], _, _, _) -> [].
    
bsm_rename_var(Old, Old, New) -> New;
bsm_rename_var(V, _, _) -> V.

%% bsm_forget_var(#l{}, Variable) -> #l{}
%%  Remove a variable from the variable life-time database.

bsm_forget_var(#l{vdb=Vdb}=L, V) ->
    L#l{vdb=keydelete(V, 1, Vdb)}.

%% block_cg([Kexpr], Le, Vdb, StackReg, St) -> {[Ainstr],StackReg,St}.
%% block_cg([Kexpr], Le, StackReg, St) -> {[Ainstr],StackReg,St}.

block_cg(Es, Le, _Vdb, Bef, St) ->
    block_cg(Es, Le, Bef, St).

block_cg(Es, Le, Bef, #cg{is_top_block=false}=St) ->
    cg_block(Es, Le#l.i, Le#l.vdb, Bef, St);
block_cg(Es, Le, Bef, St0) ->
    {Is0,Aft,St} = cg_block(Es, Le#l.i, Le#l.vdb, Bef,
			    St0#cg{is_top_block=false,need_frame=false}),
    Is = top_level_block(Is0, Aft, max_reg(Bef#sr.reg), St),
    {Is,Aft,St#cg{is_top_block=true}}.

cg_block([], _I, _Vdb, Bef, St0) ->
    {[],Bef,St0};
cg_block(Kes0, I, Vdb, Bef, St0) ->
    {Kes2,Int1,St1} =
	case basic_block(Kes0) of
	    {Kes1,LastI,Args,Rest} ->
		Ke = hd(Kes1),
		Fb = Ke#l.i,
		cg_basic_block(Kes1, Fb, LastI, Args, Vdb, Bef, St0);
	    {Kes1,Rest} ->
		cg_list(Kes1, I, Vdb, Bef, St0)
	end,
    {Kes3,Int2,St2} = cg_block(Rest, I, Vdb, Int1, St1),
    {Kes2 ++ Kes3,Int2,St2}.

basic_block(Kes) -> basic_block(Kes, []).

basic_block([Le|Les], Acc) ->
    case collect_block(Le#l.ke) of
	include -> basic_block(Les, [Le|Acc]);
	{block_end,As} ->
	    case Acc of
		[] ->
		    %% If the basic block does not contain any set instructions,
		    %% it serves no useful purpose to do basic block optimizations.
		    {[Le],Les};
		_ ->
		    {reverse(Acc, [Le]),Le#l.i,As,Les}
	    end;
	no_block -> {reverse(Acc, [Le]),Les}
    end.
	
collect_block({set,_,{binary,_}})    -> no_block;
collect_block({set,_,_})             -> include;
collect_block({call,{var,_}=Var,As,_Rs}) -> {block_end,As++[Var]};
collect_block({call,Func,As,_Rs})   -> {block_end,As++func_vars(Func)};
collect_block({enter,{var,_}=Var,As})-> {block_end,As++[Var]};
collect_block({enter,Func,As})       -> {block_end,As++func_vars(Func)};
collect_block({return,Rs})           -> {block_end,Rs};
collect_block({break,Bs})            -> {block_end,Bs};
collect_block(_)                     -> no_block.

func_vars({remote,M,F}) when element(1, M) =:= var;
			     element(1, F) =:= var ->
    [M,F];
func_vars(_) -> [].

%% cg_basic_block([Kexpr], FirstI, LastI, As, Vdb, StackReg, State) ->
%%      {[Ainstr],StackReg,State}.

cg_basic_block(Kes, Fb, Lf, As, Vdb, Bef, St0) ->
    Res = make_reservation(As, 0),
    Regs0 = reserve(Res, Bef#sr.reg, Bef#sr.stk),
    Stk = extend_stack(Bef, Lf, Lf+1, Vdb),
    Int0 = Bef#sr{reg=Regs0,stk=Stk,res=Res},
    X0_v0 = x0_vars(As, Fb, Lf, Vdb),
    {Keis,{Aft,_,St1}} =
	flatmapfoldl(fun(Ke, St) -> cg_basic_block(Ke, St, Lf, Vdb) end,
		     {Int0,X0_v0,St0}, need_heap(Kes, Fb)),
    {Keis,Aft,St1}.

cg_basic_block(#l{ke={need_heap,_}}=Ke, {Inta,X0v,Sta}, _Lf, Vdb) ->
    {Keis,Intb,Stb} = cg(Ke, Vdb, Inta, Sta),
    {comment(Inta) ++ Keis, {Intb,X0v,Stb}};
cg_basic_block(Ke, {Inta,X0_v1,Sta}, Lf, Vdb) ->
    {Sis,Intb} = save_carefully(Inta, Ke#l.i, Lf+1, Vdb),
    {X0_v2,Intc} = allocate_x0(X0_v1, Ke#l.i, Intb),
    Intd = reserve(Intc),
    {Keis,Inte,Stb} = cg(Ke, Vdb, Intd, Sta),
    {comment(Inta) ++ Sis ++ Keis, {Inte,X0_v2,Stb}}.

make_reservation([], _) -> [];
make_reservation([{var,V}|As], I) -> [{I,V}|make_reservation(As, I+1)];
make_reservation([A|As], I) -> [{I,A}|make_reservation(As, I+1)].

reserve(Sr) -> Sr#sr{reg=reserve(Sr#sr.res, Sr#sr.reg, Sr#sr.stk)}.

reserve([{I,V}|Rs], [free|Regs], Stk) -> [{reserved,I,V}|reserve(Rs, Regs, Stk)];
reserve([{I,V}|Rs], [{I,V}|Regs], Stk) -> [{I,V}|reserve(Rs, Regs, Stk)];
reserve([{I,V}|Rs], [{I,Var}|Regs], Stk) ->
    case on_stack(Var, Stk) of
	true -> [{reserved,I,V}|reserve(Rs, Regs, Stk)];
	false -> [{I,Var}|reserve(Rs, Regs, Stk)]
    end;
reserve([{I,V}|Rs], [{reserved,I,_}|Regs], Stk) ->
    [{reserved,I,V}|reserve(Rs, Regs, Stk)];
%reserve([{I,V}|Rs], [Other|Regs], Stk) -> [Other|reserve(Rs, Regs, Stk)];
reserve([{I,V}|Rs], [], Stk) -> [{reserved,I,V}|reserve(Rs, [], Stk)];
reserve([], Regs, _) -> Regs.

extend_stack(Bef, Fb, Lf, Vdb) ->
    Stk0 = clear_dead_stk(Bef#sr.stk, Fb, Vdb),
    Saves = [V || {V,F,L} <- Vdb,
		  F < Fb,
		  L >= Lf,
		  not on_stack(V, Stk0)],
    Stk1 = foldl(fun (V, Stk) -> put_stack(V, Stk) end, Stk0, Saves),
    Bef#sr.stk ++ lists:duplicate(length(Stk1) - length(Bef#sr.stk), free).

save_carefully(Bef, Fb, Lf, Vdb) ->
    Stk = Bef#sr.stk,
    %% New variables that are in use but not on stack.
    New = [ {V,F,L} || {V,F,L} <- Vdb,
		       F < Fb,
		   L >= Lf,
		       not on_stack(V, Stk) ],
    Saves = [ V || {V,_,_} <- keysort(2, New) ],
    save_carefully(Saves, Bef, []).

save_carefully([], Bef, Acc) -> {reverse(Acc),Bef};
save_carefully([V|Vs], Bef, Acc) ->
    case put_stack_carefully(V, Bef#sr.stk) of
	error -> {reverse(Acc),Bef};
	Stk1 ->
	    SrcReg = fetch_reg(V, Bef#sr.reg),
	    Move = {move,SrcReg,fetch_stack(V, Stk1)},
	    {x,_} = SrcReg,			%Assertion - must be X register.
	    save_carefully(Vs, Bef#sr{stk=Stk1}, [Move|Acc])
    end.

x0_vars([], _Fb, _Lf, _Vdb) -> [];
x0_vars([{var,V}|_], Fb, _Lf, Vdb) ->
    {V,F,_L} = VFL = vdb_find(V, Vdb),
    x0_vars1([VFL], Fb, F, Vdb);
x0_vars([X0|_], Fb, Lf, Vdb) ->
    x0_vars1([{X0,Lf,Lf}], Fb, Lf, Vdb).

x0_vars1(X0, Fb, Xf, Vdb) ->
    Vs0 = [VFL || {_V,F,L}=VFL <- Vdb,
		  F >= Fb,
		  L < Xf],
    Vs1 = keysort(3, Vs0),
    keysort(2, X0++Vs1).

allocate_x0([], _, Bef) -> {[],Bef#sr{res=[]}};
allocate_x0([{_,_,L}|Vs], I, Bef) when L =< I ->
    allocate_x0(Vs, I, Bef);
allocate_x0([{V,_F,_L}=VFL|Vs], _, Bef) ->
    {[VFL|Vs],Bef#sr{res=reserve_x0(V, Bef#sr.res)}}.

reserve_x0(V, [_|Res]) -> [{0,V}|Res];
reserve_x0(V, []) -> [{0,V}].

top_level_block(Keis, #sr{stk=[]}, _MaxRegs, #cg{need_frame=false}) ->
    Keis;
top_level_block(Keis, Bef, MaxRegs, _St) ->
    %% This top block needs an allocate instruction before it, and a
    %% deallocate instruction before each return.
    FrameSz = length(Bef#sr.stk),
    MaxY = FrameSz-1,
    Keis1 = flatmap(fun ({call_only,Arity,Func}) ->
			    [{call_last,Arity,Func,FrameSz}];
			({call_ext_only,Arity,Func}) ->
			    [{call_ext_last,Arity,Func,FrameSz}];
			({apply_only,Arity}) ->
			    [{apply_last,Arity,FrameSz}];
			({break,Fail}) ->
			    [{deallocate,FrameSz},{jump,Fail}];
			(return) ->
			    [{deallocate,FrameSz},return];
			(Tuple) when is_tuple(Tuple) ->
			    [turn_yregs(tuple_size(Tuple), Tuple, MaxY)];
			(Other) ->
			    [Other]
		    end, Keis),
    [{allocate_zero,FrameSz,MaxRegs}|Keis1].

%% turn_yregs(Size, Tuple, MaxY) -> Tuple'
%%   Renumber y register so that {y,0} becomes {y,FrameSize-1},
%%   {y,FrameSize-1} becomes {y,0} and so on.  This is to make nested
%%   catches work.  The code generation algorithm gives a lower register
%%   number to the outer catch, which is wrong.

turn_yregs(0, Tp, _) -> Tp;
turn_yregs(El, Tp, MaxY) when element(1, element(El, Tp)) =:= yy ->
    turn_yregs(El-1, setelement(El, Tp, {y,MaxY-element(2, element(El, Tp))}), MaxY);
turn_yregs(El, Tp, MaxY) when is_list(element(El, Tp)) ->
    New = map(fun ({yy,YY}) -> {y,MaxY-YY};
		  (Other) -> Other end, element(El, Tp)),
    turn_yregs(El-1, setelement(El, Tp, New), MaxY);
turn_yregs(El, Tp, MaxY) ->
    turn_yregs(El-1, Tp, MaxY).

%% select_cg(Sclause, V, TypeFail, ValueFail, StackReg, State) ->
%%      {Is,StackReg,State}.
%%  Selecting type and value needs two failure labels, TypeFail is the
%%  label to jump to of the next type test when this type fails, and
%%  ValueFail is the label when this type is correct but the value is
%%  wrong.  These are different as in the second case there is no need
%%  to try the next type, it will always fail.

select_cg(#l{ke={type_clause,cons,[S]}}, {var,V}, Tf, Vf, Bef, St) ->
    select_cons(S, V, Tf, Vf, Bef, St);
select_cg(#l{ke={type_clause,nil,[S]}}, {var,V}, Tf, Vf, Bef, St) ->
    select_nil(S, V, Tf, Vf, Bef, St);
select_cg(#l{ke={type_clause,binary,[S]}}, {var,V}, Tf, Vf, Bef, St) ->
    select_binary(S, V, Tf, Vf, Bef, St);
select_cg(#l{ke={type_clause,bin_seg,S}}, {var,V}, Tf, _Vf, Bef, St) ->
    select_bin_segs(S, V, Tf, Bef, St);
select_cg(#l{ke={type_clause,bin_int,S}}, {var,V}, Tf, _Vf, Bef, St) ->
    select_bin_segs(S, V, Tf, Bef, St);
select_cg(#l{ke={type_clause,bin_end,[S]}}, {var,V}, Tf, _Vf, Bef, St) ->
    select_bin_end(S, V, Tf, Bef, St);
select_cg(#l{ke={type_clause,Type,Scs}}, {var,V}, Tf, Vf, Bef, St0) ->
    {Vis,{Aft,St1}} =
	mapfoldl(fun (S, {Int,Sta}) ->
			 {Val,Is,Inta,Stb} = select_val(S, V, Vf, Bef, Sta),
			 {{Is,[Val]},{sr_merge(Int, Inta),Stb}}
		 end, {void,St0}, Scs),
    OptVls = combine(lists:sort(combine(Vis))),
    {Vls,Sis,St2} = select_labels(OptVls, St1, [], []),
    {select_val_cg(Type, fetch_var(V, Bef), Vls, Tf, Vf, Sis), Aft, St2}.

select_val_cg(tuple, R, [Arity,{f,Lbl}], Tf, Vf, [{label,Lbl}|Sis]) ->
    [{test,is_tuple,{f,Tf},[R]},{test,test_arity,{f,Vf},[R,Arity]}|Sis];
select_val_cg(tuple, R, Vls, Tf, Vf, Sis) ->
    [{test,is_tuple,{f,Tf},[R]},{select_tuple_arity,R,{f,Vf},{list,Vls}}|Sis];
select_val_cg(Type, R, [Val, {f,Lbl}], Fail, Fail, [{label,Lbl}|Sis]) ->
    [{test,is_eq_exact,{f,Fail},[R,{Type,Val}]}|Sis];
select_val_cg(Type, R, [Val, {f,Lbl}], Tf, Vf, [{label,Lbl}|Sis]) ->
    [{test,select_type_test(Type),{f,Tf},[R]},
     {test,is_eq_exact,{f,Vf},[R,{Type,Val}]}|Sis];
select_val_cg(Type, R, Vls0, Tf, Vf, Sis) ->
    Vls1 = map(fun ({f,Lbl}) -> {f,Lbl};
		   (Value) -> {Type,Value}
	       end, Vls0),
    [{test,select_type_test(Type),{f,Tf},[R]}, {select_val,R,{f,Vf},{list,Vls1}}|Sis].
    
select_type_test(integer) -> is_integer;
select_type_test(atom) -> is_atom;
select_type_test(float) -> is_float.

combine([{Is,Vs1}, {Is,Vs2}|Vis]) -> combine([{Is,Vs1 ++ Vs2}|Vis]);
combine([V|Vis]) -> [V|combine(Vis)];
combine([]) -> [].

select_labels([{Is,Vs}|Vis], St0, Vls, Sis) ->
    {Lbl,St1} = new_label(St0),
    select_labels(Vis, St1, add_vls(Vs, Lbl, Vls), [[{label,Lbl}|Is]|Sis]);
select_labels([], St, Vls, Sis) ->
    {Vls,append(Sis),St}.

add_vls([V|Vs], Lbl, Acc) ->
    add_vls(Vs, Lbl, [V, {f,Lbl}|Acc]);
add_vls([], _, Acc) -> Acc.

select_cons(#l{ke={val_clause,{cons,Es},B},i=I,vdb=Vdb}, V, Tf, Vf, Bef, St0) ->
    {Eis,Int,St1} = select_extract_cons(V, Es, I, Vdb, Bef, St0),
    {Bis,Aft,St2} = match_cg(B, Vf, Int, St1),
    {[{test,is_nonempty_list,{f,Tf},[fetch_var(V, Bef)]}] ++ Eis ++ Bis,Aft,St2}.

select_nil(#l{ke={val_clause,nil,B}}, V, Tf, Vf, Bef, St0) ->
    {Bis,Aft,St1} = match_cg(B, Vf, Bef, St0),
    {[{test,is_nil,{f,Tf},[fetch_var(V, Bef)]}] ++ Bis,Aft,St1}.

select_binary(#l{ke={val_clause,{binary,{var,V}},B},i=I,vdb=Vdb},
	      V, Tf, Vf, Bef, St0) ->
    Int0 = clear_dead(Bef#sr{reg=Bef#sr.reg}, I, Vdb),
    {Bis,Aft,St1} = match_cg(B, Vf, Int0, St0),
    CtxReg = fetch_var(V, Int0),
    Live = max_reg(Bef#sr.reg),
    {[{test,bs_start_match2,{f,Tf},[CtxReg,Live,V,CtxReg]},
      {bs_save2,CtxReg,{V,V}}|Bis],
     Aft,St1};
select_binary(#l{ke={val_clause,{binary,{var,Ivar}},B},i=I,vdb=Vdb},
	      V, Tf, Vf, Bef, St0) ->
    Regs = put_reg(Ivar, Bef#sr.reg),
    Int0 = clear_dead(Bef#sr{reg=Regs}, I, Vdb),
    {Bis,Aft,St1} = match_cg(B, Vf, Int0, St0),
    CtxReg = fetch_var(Ivar, Int0),
    Live = max_reg(Bef#sr.reg),
    {[{test,bs_start_match2,{f,Tf},[fetch_var(V, Bef),Live,Ivar,CtxReg]},
      {bs_save2,CtxReg,{Ivar,Ivar}}|Bis],
     Aft,St1}.

%% New instructions for selection of binary segments.

select_bin_segs(Scs, Ivar, Tf, Bef, St) ->
    match_fmf(fun(S, Fail, Sta) ->
		      select_bin_seg(S, Ivar, Fail, Bef, Sta) end,
	      Tf, St, Scs).

select_bin_seg(#l{ke={val_clause,{bin_seg,Ctx,Size,U,T,Fs0,Es},B},i=I,vdb=Vdb,a=A},
	       Ivar, Fail, Bef, St0) ->
    Fs = [{anno,A}|Fs0],
    {Mis,Int,St1} = select_extract_bin(Es, Size, U, T, Fs, Fail,
				       I, Vdb, Bef, Ctx, B, St0),
    {Bis,Aft,St2} = match_cg(B, Fail, Int, St1),
    CtxReg = fetch_var(Ctx, Bef),
    Is = if
	     Mis =:= [] ->
		 %% No bs_restore2 instruction needed if no match instructions.
		 Bis;
	     true ->
		 [{bs_restore2,CtxReg,{Ctx,Ivar}}|Mis++Bis]
	 end,
    {Is,Aft,St2};
select_bin_seg(#l{ke={val_clause,{bin_int,Ctx,Sz,U,Fs,Val,Es},B},i=I,vdb=Vdb},
	       Ivar, Fail, Bef, St0) ->
    {Mis,Int,St1} = select_extract_int(Es, Val, Sz, U, Fs, Fail,
				       I, Vdb, Bef, Ctx, St0),
    {Bis,Aft,St2} = match_cg(B, Fail, Int, St1),
    CtxReg = fetch_var(Ctx, Bef),
    {[{bs_restore2,CtxReg,{Ctx,Ivar}}|Mis] ++ Bis,Aft,St2}.

select_extract_int([{var,Tl}], Val, {integer,Sz}, U, Fs, Vf,
		   I, Vdb, Bef, Ctx, St) ->
    EmptyBindings = erl_eval:new_bindings(),
    EvalFun = fun({integer,_,S}, B) -> {value,S,B} end,
    Expr = [{bin_element,0,{integer,0,Val},{integer,0,Sz},[{unit,U}|Fs]}],
    {value,Bin,EmptyBindings} = eval_bits:expr_grp(Expr, EmptyBindings, EvalFun),
    Bits = U*Sz,
    Bits = bit_size(Bin),			%Assertion.
    CtxReg = fetch_var(Ctx, Bef),
    {[{test,bs_match_string,{f,Vf},[CtxReg,Bin]},{bs_save2,CtxReg,{Ctx,Tl}}],
     clear_dead(Bef, I, Vdb),St}.

select_extract_bin([{var,Hd},{var,Tl}], Size0, Unit, Type, Flags, Vf,
		   I, Vdb, Bef, Ctx, _Body, St) ->
    SizeReg = get_bin_size_reg(Size0, Bef),
    {Es,Aft} =
	case vdb_find(Hd, Vdb) of
	    {_,_,Lhd} when Lhd =< I ->
		CtxReg = fetch_var(Ctx, Bef),
		{[{test,bs_skip_bits2,{f,Vf},[CtxReg,SizeReg,Unit,{field_flags,Flags}]},
		  {bs_save2,CtxReg,{Ctx,Tl}}],Bef};
	    {_,_,_} ->
		Reg = put_reg(Hd, Bef#sr.reg),
		Int1 = Bef#sr{reg=Reg},
		Rhd = fetch_reg(Hd, Reg),
		CtxReg = fetch_reg(Ctx, Reg),
		Name = get_bits_instr(Type),
		Live = max_reg(Bef#sr.reg),
		{[{test,Name,{f,Vf},[CtxReg,Live,SizeReg,Unit,{field_flags,Flags},Rhd]},
		  {bs_save2,CtxReg,{Ctx,Tl}}],Int1}
	end,
    {Es,clear_dead(Aft, I, Vdb),St};
select_extract_bin([{var,Hd}], Size0, Unit, Type, Flags, Vf,
		   I, Vdb, Bef, Ctx, Body, St) ->
    SizeReg = get_bin_size_reg(Size0, Bef),
    {Es,Aft} =
	case vdb_find(Hd, Vdb) of
	    {_,_,Lhd} when Lhd =< I ->
		CtxReg = fetch_var(Ctx, Bef),
		{case SizeReg =:= {atom,all} andalso is_context_unused(Body) of
		     true when Unit =:= 1 ->
			 [];
		     true ->
			 [{test,bs_test_unit,{f,Vf},[CtxReg,Unit]}];
		     false ->
			 [{test,bs_skip_bits2,{f,Vf},
			   [CtxReg,SizeReg,Unit,{field_flags,Flags}]}]
		 end,Bef};
	    {_,_,_} ->
		case is_context_unused(Body) of
		    false ->
			Reg = put_reg(Hd, Bef#sr.reg),
			Int1 = Bef#sr{reg=Reg},
			Rhd = fetch_reg(Hd, Reg),
			CtxReg = fetch_reg(Ctx, Reg),
			Name = get_bits_instr(Type),
			Live = max_reg(Bef#sr.reg),
			{[{test,Name,{f,Vf},[CtxReg,Live,SizeReg,Unit,
					     {field_flags,Flags},Rhd]}],
			 Int1};
		    true ->
			%% Since the matching context will not be used again,
			%% we can reuse its register. Reusing the register
			%% opens some interesting optimizations in the
			%% run-time system.

			Reg0 = Bef#sr.reg,
			CtxReg = fetch_reg(Ctx, Reg0),
			Reg = replace_reg_contents(Ctx, Hd, Reg0),
			Int1 = Bef#sr{reg=Reg},
			Name = get_bits_instr(Type),
			Live = max_reg(Int1#sr.reg),
			{[{test,Name,{f,Vf},[CtxReg,Live,SizeReg,Unit,
					     {field_flags,Flags},CtxReg]}],
			 Int1}
		end
	end,
    {Es,clear_dead(Aft, I, Vdb),St}.

%% is_context_unused(Ke) -> true | false
%%   Simple heurististic to determine whether the code that follows will
%%   use the current matching context again. (The information of liveness
%%   calculcated by v3_life is too conservative to be useful for this purpose.)
%%   'true' means that the code that follows will definitely not use the context
%%   again (because it is a block, not guard or matching code); 'false' that we
%%   are not sure (there is either a guard, or more matching, either which may
%%   reference the context again).

is_context_unused(#l{ke=Ke}) -> is_context_unused(Ke);
is_context_unused({block,_}) -> true;
is_context_unused(_) -> false.

select_bin_end(#l{ke={val_clause,{bin_end,Ctx},B}},
	       Ivar, Tf, Bef, St0) ->
    {Bis,Aft,St2} = match_cg(B, Tf, Bef, St0),
    CtxReg = fetch_var(Ctx, Bef),
    {[{bs_restore2,CtxReg,{Ctx,Ivar}},{test,bs_test_tail2,{f,Tf},[CtxReg,0]}|Bis],Aft,St2}.

get_bin_size_reg({var,V}, Bef) ->
    fetch_var(V, Bef);
get_bin_size_reg(Literal, _Bef) ->
    Literal.

get_bits_instr(integer) -> bs_get_integer2;
get_bits_instr(float)   -> bs_get_float2;
get_bits_instr(binary)  -> bs_get_binary2.

select_val(#l{ke={val_clause,{tuple,Es},B},i=I,vdb=Vdb}, V, Vf, Bef, St0) ->
    {Eis,Int,St1} = select_extract_tuple(V, Es, I, Vdb, Bef, St0),
    {Bis,Aft,St2} = match_cg(B, Vf, Int, St1),
    {length(Es),Eis ++ Bis,Aft,St2};
select_val(#l{ke={val_clause,{_,Val},B}}, _V, Vf, Bef, St0) ->
    {Bis,Aft,St1} = match_cg(B, Vf, Bef, St0),
    {Val,Bis,Aft,St1}.

%% select_extract_tuple(Src, [V], I, Vdb, StackReg, State) ->
%%      {[E],StackReg,State}.
%%  Extract tuple elements, but only if they do not immediately die.

select_extract_tuple(Src, Vs, I, Vdb, Bef, St) ->
    F = fun ({var,V}, {Int0,Elem}) ->
		case vdb_find(V, Vdb) of
		    {V,_,L} when L =< I -> {[], {Int0,Elem+1}};
		    _Other ->
			Reg1 = put_reg(V, Int0#sr.reg),
			Int1 = Int0#sr{reg=Reg1},
			Rsrc = fetch_var(Src, Int1),
			{[{get_tuple_element,Rsrc,Elem,fetch_reg(V, Reg1)}],
			 {Int1,Elem+1}}
		end
	end,
    {Es,{Aft,_}} = flatmapfoldl(F, {Bef,0}, Vs),
    {Es,Aft,St}.

select_extract_cons(Src, [{var,Hd}, {var,Tl}], I, Vdb, Bef, St) ->
    {Es,Aft} = case {vdb_find(Hd, Vdb), vdb_find(Tl, Vdb)} of
		   {{_,_,Lhd}, {_,_,Ltl}} when Lhd =< I, Ltl =< I ->
		       %% Both head and tail are dead.  No need to generate
		       %% any instruction.
		       {[], Bef};
		   _ ->
		       %% At least one of head and tail will be used,
		       %% but we must always fetch both.  We will call
		       %% clear_dead/2 to allow reuse of the register
		       %% in case only of them is used.

		       Reg0 = put_reg(Tl, put_reg(Hd, Bef#sr.reg)),
		       Int0 = Bef#sr{reg=Reg0},
		       Rsrc = fetch_var(Src, Int0),
		       Rhd = fetch_reg(Hd, Reg0),
		       Rtl = fetch_reg(Tl, Reg0),
		       Int1 = clear_dead(Int0, I, Vdb),
		       {[{get_list,Rsrc,Rhd,Rtl}], Int1}
	       end,
    {Es,Aft,St}.
    

guard_clause_cg(#l{ke={guard_clause,G,B},vdb=Vdb,i=I}, Fail, Bef, St0) ->
    case is_matching_guard(G) of
	false ->
	    %% The basic case without the complication of matching
	    %% in the guard.

	    {Gis,Int,St1} = guard_cg(G, Fail, Vdb, Bef, St0),
	    {Bis,Aft,St} = match_cg(B, Fail, Int, St1),
	    {Gis ++ Bis,Aft,St};
	true ->
	    %% This top-level guard contains code that matches
	    %% (because the original source code used andalso/orelse).
	    %%   We must set up a stack frame. Furthermore
	    %% we must restore all X registers before leaving the guard.
	    %% This is messy, so we do it in a separate function.

	    saving_guard_cg(G, B, I, Vdb, Fail, Bef, St0)
    end.

saving_guard_cg(G, B, _I, Vdb, Fail, Bef, St0) ->
    {RestoreL,St1} = new_label(St0),
    {Gis,Int,St2} = guard_cg(G, RestoreL, Vdb, Bef,
			     St1#cg{is_top_block=false}),
    Hvs = hvs(Bef, Int),
    {Bis,Aft,St} = match_cg(B, Fail, Int, St2),
    {RestoreRegsIs,_} = cg_setup_call(Hvs, Int, 1, Vdb),
    Break = case St0#cg.is_top_block of
		false -> [{jump,{f,Fail}}];
		true -> [{break,{f,Fail}}]
	    end,
    Is0 = Gis++Bis++[{label,RestoreL}] ++
	RestoreRegsIs ++ Break,
    Is = case St0#cg.is_top_block of
	     false -> Is0;
	     true -> top_level_block(Is0, Aft, max_reg(Bef#sr.reg), St)
	 end,
    {Is,Aft,St#cg{is_top_block=St0#cg.is_top_block}}.

hvs(#sr{reg=Reg}, #sr{stk=Saved0}) ->
    Saved = ordsets:from_list([V || {V} <- Saved0]),
    hvs_1(Reg, Saved, []).

hvs_1([{_,V}|Rs], Saved, Acc) ->
    case ordsets:is_element(V, Saved) of
	false -> hvs_1(Rs, Saved, [nil|Acc]);
	true ->  hvs_1(Rs, Saved, [{var,V}|Acc])
    end;
hvs_1([_|Rs], Saved, Acc) ->
    hvs_1(Rs, Saved, [nil|Acc]);
hvs_1([], _, Acc) -> hvs_2(Acc).

hvs_2([nil|Vs]) -> hvs_2(Vs);
hvs_2(Vs) -> reverse(Vs).


%% is_matching_guard(GuardExpr) -> true|false
%%  Determine whether a guard expression contains a match expression.

is_matching_guard(#l{ke={protected,T,_}}) -> is_matching_guard_list(T);
is_matching_guard(#l{ke={test,_,_}}) -> false;
is_matching_guard(#l{ke={bif,_,_,_}}) -> false;
is_matching_guard(#l{ke={gc_bif,_,_,_}}) -> false;
is_matching_guard(#l{ke={set,_,_}}) -> false;
is_matching_guard(#l{ke={match,_,_}}) -> true.

is_matching_guard_list([T|Ts]) ->
    case is_matching_guard(T) of
	false -> is_matching_guard_list(Ts);
	true -> true
    end;
is_matching_guard_list([]) -> false.

%% guard_cg(Guard, Fail, Vdb, StackReg, State) ->
%%      {[Ainstr],StackReg,State}.
%%  A guard is a boolean expression of tests.  Tests return true or
%%  false.  A fault in a test causes the test to return false.  Tests
%%  never return the boolean, instead we generate jump code to go to
%%  the correct exit point.  Primops and tests all go to the next
%%  instruction on success or jump to a failure label.

guard_cg(#l{ke={protected,Ts,Rs},i=I,vdb=Pdb}, Fail, _Vdb, Bef, St) ->
    protected_cg(Ts, Rs, Fail, I, Pdb, Bef, St);
guard_cg(#l{ke={block,Ts},i=I,vdb=Bdb}, Fail, _Vdb, Bef, St) ->
    guard_cg_list(Ts, Fail, I, Bdb, Bef, St);
guard_cg(#l{ke={test,Test,As},i=I,vdb=_Tdb}, Fail, Vdb, Bef, St) ->
    test_cg(Test, As, Fail, I, Vdb, Bef, St);
guard_cg(G, _Fail, Vdb, Bef, St) ->
    %%ok = io:fwrite("cg ~w: ~p~n", [?LINE,{G,Fail,Vdb,Bef}]),
    {Gis,Aft,St1} = cg(G, Vdb, Bef, St),
    %%ok = io:fwrite("cg ~w: ~p~n", [?LINE,{Aft}]),
    {Gis,Aft,St1}.

%% protected_cg([Kexpr], [Ret], Fail, I, Vdb, Bef, St) -> {[Ainstr],Aft,St}.
%%  Do a protected.  Protecteds without return values are just done
%%  for effect, the return value is not checked, success passes on to
%%  the next instruction and failure jumps to Fail.  If there are
%%  return values then these must be set to 'false' on failure,
%%  control always passes to the next instruction.

protected_cg(Ts, Rs, Fail, I, Vdb, Bef, St0) ->
    case is_matching_guard_list(Ts) of
	false ->
	    protected_cg_1(Ts, Rs, Fail, I, Vdb, Bef, St0);
	true ->
	    %% A match construct inside a protected means that there was
	    %% an andalso/orelse in the source code.
	    %% We must save all variables that are to survive the protected
	    %% before entering it (i.e. before executing any
	    %% instruction that could fail, such as a guard BIF).

	    {Sis,Int} = adjust_stack(Bef, I, I+1, Vdb),
	    {Tis,Aft,St} = protected_cg_1(Ts, Rs, Fail, I, Vdb, Int, St0),
	    {Sis++Tis,Aft,St}
    end.

protected_cg_1(Ts, [], Fail, I, Vdb, Bef, St0) ->
    %% Protect these calls, revert when done.
    {Tis,Aft,St1} = guard_cg_list(Ts, Fail, I, Vdb, Bef,
				  St0#cg{btype=fail,bfail=Fail}),
    {Tis,Aft,St1#cg{btype=St0#cg.btype,bfail=St0#cg.bfail}};
protected_cg_1(Ts, Rs, _Fail, I, Vdb, Bef, St0) ->
    {Pfail,St1} = new_label(St0),
    {Psucc,St2} = new_label(St1),
    {Tis,Aft,St3} = guard_cg_list(Ts, Pfail, I, Vdb, Bef,
				  St2#cg{btype=fail,bfail=Pfail}),
    %%ok = io:fwrite("cg ~w: ~p~n", [?LINE,{Rs,I,Vdb,Aft}]),
    %% Set return values to false.
    Mis = map(fun ({var,V}) -> {move,{atom,false},fetch_var(V, Aft)} end, Rs),
    Live = {'%live',max_reg(Aft#sr.reg)},
    {Tis ++ [Live,{jump,{f,Psucc}},
	     {label,Pfail}] ++ Mis ++ [Live,{label,Psucc}],
     Aft,St3#cg{btype=St0#cg.btype,bfail=St0#cg.bfail}}.    

%% test_cg(TestName, Args, Fail, I, Vdb, Bef, St) -> {[Ainstr],Aft,St}.
%%  Generate test instruction.  Use explicit fail label here.

test_cg(Test, As, Fail, I, Vdb, Bef, St) ->
    Args = cg_reg_args(As, Bef),
    Aft = clear_dead(Bef, I, Vdb),
    {[beam_utils:bif_to_test(Test, Args, {f,Fail})],Aft,St}.

%% guard_cg_list([Kexpr], Fail, I, Vdb, StackReg, St) ->
%%      {[Ainstr],StackReg,St}.

guard_cg_list(Kes, Fail, I, Vdb, Bef, St0) ->
    {Keis,{Aft,St1}} =
	flatmapfoldl(fun (Ke, {Inta,Sta}) ->
			     {Keis,Intb,Stb} =
				 guard_cg(Ke, Fail, Vdb, Inta, Sta),
			     {comment(Inta) ++ Keis,{Intb,Stb}}
		     end, {Bef,St0}, need_heap(Kes, I)),
    {Keis,Aft,St1}.

%% match_fmf(Fun, LastFail, State, [Clause]) -> {Is,Aft,State}.
%%  This is a special flatmapfoldl for match code gen where we
%%  generate a "failure" label for each clause. The last clause uses
%%  an externally generated failure label, LastFail.  N.B. We do not
%%  know or care how the failure labels are used.

match_fmf(F, LastFail, St, [H]) ->
    F(H, LastFail, St);
match_fmf(F, LastFail, St0, [H|T]) ->
    {Fail,St1} = new_label(St0),
    {R,Aft1,St2} = F(H, Fail, St1),
    {Rs,Aft2,St3} = match_fmf(F, LastFail, St2, T),
    {R ++ [{label,Fail}] ++ Rs,sr_merge(Aft1, Aft2),St3}.

%% call_cg(Func, [Arg], [Ret], Le, Vdb, StackReg, State) ->
%%      {[Ainstr],StackReg,State}.
%% enter_cg(Func, [Arg], Le, Vdb, Bef, St) -> {[Ainstr],Aft,St}.
%%  Call and enter first put the arguments into registers and save any
%%  other registers, then clean up and compress the stack and set the
%%  frame size. Finally the actual call is made.  Call then needs the
%%  return values filled in.

call_cg({var,V}, As, Rs, Le, Vdb, Bef, St0) ->
    {Sis,Int} = cg_setup_call(As++[{var,V}], Bef, Le#l.i, Vdb),
    %% Put return values in registers.
    Reg = load_vars(Rs, clear_regs(Int#sr.reg)),
    %% Build complete code and final stack/register state.
    Arity = length(As),
    {Frees,Aft} = free_dead(clear_dead(Int#sr{reg=Reg}, Le#l.i, Vdb)),
    {comment({call_fun,{var,V},As}) ++ Sis ++ Frees ++ [{call_fun,Arity}],
     Aft,need_stack_frame(St0)};
call_cg({remote,Mod,Name}, As, Rs, Le, Vdb, Bef, St0)
  when element(1, Mod) =:= var;
       element(1, Name) =:= var ->
    {Sis,Int} = cg_setup_call(As++[Mod,Name], Bef, Le#l.i, Vdb),
    %% Put return values in registers.
    Reg = load_vars(Rs, clear_regs(Int#sr.reg)),
    %% Build complete code and final stack/register state.
    Arity = length(As),
    Call = {apply,Arity},
    St = need_stack_frame(St0),
    %%{Call,St1} = build_call(Func, Arity, St0),
    {Frees,Aft} = free_dead(clear_dead(Int#sr{reg=Reg}, Le#l.i, Vdb)),
    {Sis ++ Frees ++ [Call],Aft,St};
call_cg(Func, As, Rs, Le, Vdb, Bef, St0) ->
    {Sis,Int} = cg_setup_call(As, Bef, Le#l.i, Vdb),
    %% Put return values in registers.
    Reg = load_vars(Rs, clear_regs(Int#sr.reg)),
    %% Build complete code and final stack/register state.
    Arity = length(As),
    {Call,St1} = build_call(Func, Arity, St0),
    {Frees,Aft} = free_dead(clear_dead(Int#sr{reg=Reg}, Le#l.i, Vdb)),
    {comment({call,Func,As}) ++ Sis ++ Frees ++ Call,Aft,St1}.

build_call({remote,{atom,erlang},{atom,'!'}}, 2, St0) ->
    {[send],need_stack_frame(St0)};
build_call({remote,{atom,Mod},{atom,Name}}, Arity, St0) ->
    {[{call_ext,Arity,{extfunc,Mod,Name,Arity}}],need_stack_frame(St0)};
build_call(Name, Arity, St0) when is_atom(Name) ->
    {Lbl,St1} = local_func_label(Name, Arity, need_stack_frame(St0)),
    {[{call,Arity,{f,Lbl}}],St1}.

free_dead(#sr{stk=Stk0}=Aft) ->
    {Instr,Stk} = free_dead(Stk0, 0, [], []),
    {Instr,Aft#sr{stk=Stk}}.

free_dead([dead|Stk], Y, Instr, StkAcc) ->
    %% Note: kill/1 is equivalent to init/1 (translated by beam_asm).
    %% We use kill/1 to help further optimisation passes.
    free_dead(Stk, Y+1, [{kill,{yy,Y}}|Instr], [free|StkAcc]);
free_dead([Any|Stk], Y, Instr, StkAcc) ->
    free_dead(Stk, Y+1, Instr, [Any|StkAcc]);
free_dead([], _, Instr, StkAcc) -> {Instr,reverse(StkAcc)}.

enter_cg({var,V}, As, Le, Vdb, Bef, St0) ->
    {Sis,Int} = cg_setup_call(As++[{var,V}], Bef, Le#l.i, Vdb),
    %% Build complete code and final stack/register state.
    Arity = length(As),
    {comment({call_fun,{var,V},As}) ++ Sis ++ [{call_fun,Arity},return],
     clear_dead(Int#sr{reg=clear_regs(Int#sr.reg)}, Le#l.i, Vdb),
     need_stack_frame(St0)};
enter_cg({remote,Mod,Name}=Func, As, Le, Vdb, Bef, St0)
  when element(1, Mod) =:= var;
       element(1, Name) =:= var ->
    {Sis,Int} = cg_setup_call(As++[Mod,Name], Bef, Le#l.i, Vdb),
    %% Build complete code and final stack/register state.
    Arity = length(As),
    Call = {apply_only,Arity},
    St = need_stack_frame(St0),
    {comment({enter,Func,As}) ++ Sis ++ [Call],
     clear_dead(Int#sr{reg=clear_regs(Int#sr.reg)}, Le#l.i, Vdb),
     St};
enter_cg(Func, As, Le, Vdb, Bef, St0) ->
    {Sis,Int} = cg_setup_call(As, Bef, Le#l.i, Vdb),
    %% Build complete code and final stack/register state.
    Arity = length(As),
    {Call,St1} = build_enter(Func, Arity, St0),
    {comment({enter,Func,As}) ++ Sis ++ Call,
     clear_dead(Int#sr{reg=clear_regs(Int#sr.reg)}, Le#l.i, Vdb),
     St1}.

build_enter({remote,{atom,erlang},{atom,'!'}}, 2, St0) ->
    {[send,return],need_stack_frame(St0)};
build_enter({remote,{atom,Mod},{atom,Name}}, Arity, St0) ->
    St1 = case trap_bif(Mod, Name, Arity) of
	      true -> need_stack_frame(St0);
	      false -> St0
	  end,
    {[{call_ext_only,Arity,{extfunc,Mod,Name,Arity}}],St1};
build_enter(Name, Arity, St0) when is_atom(Name) ->
    {Lbl,St1} = local_func_label(Name, Arity, St0),
    {[{call_only,Arity,{f,Lbl}}],St1}.

%% local_func_label(Name, Arity, State) -> {Label,State'}
%% local_func_label({Name,Arity}, State) -> {Label,State'}
%%  Get the function entry label for a local function.

local_func_label(Name, Arity, St) ->
    local_func_label({Name,Arity}, St).

local_func_label(Key, #cg{functable=Tab}=St0) ->
    case gb_trees:lookup(Key, Tab) of
	{value,Label} ->
	    {Label,St0};
	none ->
  	    {Label,St} = new_label(St0),
	    {Label,St#cg{functable=gb_trees:insert(Key, Label, Tab)}}
    end.

%% need_stack_frame(State) -> State'
%%  Make a note in the state that this function will need a stack frame.

need_stack_frame(#cg{need_frame=true}=St) -> St;
need_stack_frame(St) -> St#cg{need_frame=true}.

%% trap_bif(Mod, Name, Arity) -> true|false
%%   Trap bifs that need a stack frame.

trap_bif(erlang, link, 1) -> true;
trap_bif(erlang, unlink, 1) -> true;
trap_bif(erlang, monitor_node, 2) -> true;
trap_bif(erlang, group_leader, 2) -> true;
trap_bif(erlang, exit, 2) -> true;
trap_bif(_, _, _) -> false.

%% bif_cg(Bif, [Arg], [Ret], Le, Vdb, StackReg, State) ->
%%      {[Ainstr],StackReg,State}.

bif_cg(bs_context_to_binary=Instr, [Src0], [], Le, Vdb, Bef, St0) ->
    [Src] = cg_reg_args([Src0], Bef),
    {[{Instr,Src}],clear_dead(Bef, Le#l.i, Vdb), St0};
bif_cg(dsetelement, [Index0,Tuple0,New0], _Rs, Le, Vdb, Bef, St0) ->
    [New,Tuple,{integer,Index1}] = cg_reg_args([New0,Tuple0,Index0], Bef),
    Index = Index1-1,
    {[{set_tuple_element,New,Tuple,Index}],
     clear_dead(Bef, Le#l.i, Vdb), St0};
bif_cg({make_fun,Func,Arity,Index,Uniq}, As, Rs, Le, Vdb, Bef, St0) ->
    %% This behaves more like a function call.
    {Sis,Int} = cg_setup_call(As, Bef, Le#l.i, Vdb),
    Reg = load_vars(Rs, clear_regs(Int#sr.reg)),
    {FuncLbl,St1} = local_func_label(Func, Arity, St0),
    MakeFun = {make_fun2,{f,FuncLbl},Index,Uniq,length(As)},
    {Sis ++ [MakeFun],
     clear_dead(Int#sr{reg=Reg}, Le#l.i, Vdb),
     St1};
bif_cg(bs_init_writable=I, As, Rs, Le, Vdb, Bef, St) ->
    %% This behaves like a function call.
    {Sis,Int} = cg_setup_call(As, Bef, Le#l.i, Vdb),
    Reg = load_vars(Rs, clear_regs(Int#sr.reg)),
    {Sis++[I],clear_dead(Int#sr{reg=Reg}, Le#l.i, Vdb),St};
bif_cg(Bif, As, [{var,V}], Le, Vdb, Bef, St0) ->
    Ars = cg_reg_args(As, Bef),

    %% If we are inside a catch, we must save everything that will
    %% be alive after the catch (because the BIF might fail and there
    %% will be a jump to the code after the catch).
    %%   Currently, we are somewhat pessimistic in
    %% that we save any variable that will be live after this BIF call.

    {Sis,Int0} = case St0#cg.in_catch andalso
		     not erl_bifs:is_safe(erlang, Bif, length(As)) of
		     true -> adjust_stack(Bef, Le#l.i, Le#l.i+1, Vdb);
		     false -> {[],Bef}
		 end,
    Int1 = clear_dead(Int0, Le#l.i, Vdb),
    Reg = put_reg(V, Int1#sr.reg),
    Int = Int1#sr{reg=Reg},
    Arity = length(Ars),
    Dst = fetch_reg(V, Reg),
    BifFail = bif_fail(St0#cg.btype, St0#cg.bfail, Arity),
    {Sis++[{bif,Bif,BifFail,Ars,Dst}],
     clear_dead(Int, Le#l.i, Vdb), St0}.


%% gc_bif_cg(Bif, [Arg], [Ret], Le, Vdb, StackReg, State) ->
%%      {[Ainstr],StackReg,State}.

gc_bif_cg(Bif, As, [{var,V}], Le, Vdb, Bef, St0) ->
    Ars = cg_reg_args(As, Bef),

    %% If we are inside a catch, we must save everything that will
    %% be alive after the catch (because the BIF might fail and there
    %% will be a jump to the code after the catch).
    %%   Currently, we are somewhat pessimistic in
    %% that we save any variable that will be live after this BIF call.

    {Sis,Int0} =
	case St0#cg.in_catch of
	    true -> adjust_stack(Bef, Le#l.i, Le#l.i+1, Vdb);
	    false -> {[],Bef}
	end,

    Int1 = clear_dead(Int0, Le#l.i, Vdb),
    Reg = put_reg(V, Int1#sr.reg),
    Int = Int1#sr{reg=Reg},
    Dst = fetch_reg(V, Reg),
    BifFail = case St0#cg.btype of
		  exit -> {f,0};
		  fail -> {f,St0#cg.bfail}
	      end,
    {Sis++[{gc_bif,Bif,BifFail,max_reg(Bef#sr.reg),Ars,Dst}],
     clear_dead(Int, Le#l.i, Vdb), St0}.

bif_fail(_, _, 0) -> nofail;
bif_fail(exit, _, _) -> {f,0};
bif_fail(fail, Fail, _) -> {f,Fail}.

%% recv_loop_cg(TimeOut, ReceiveVar, ReceiveMatch, TimeOutExprs,
%%              [Ret], Le, Vdb, Bef, St) -> {[Ainstr],Aft,St}.

recv_loop_cg(Te, Rvar, Rm, Tes, Rs, Le, Vdb, Bef, St0) ->
    {Sis,Int0} = adjust_stack(Bef, Le#l.i, Le#l.i, Vdb),
    Int1 = Int0#sr{reg=clear_regs(Int0#sr.reg)},
    %% Get labels.
    {Rl,St1} = new_label(St0),
    {Tl,St2} = new_label(St1),
    {Bl,St3} = new_label(St2),
    St4 = St3#cg{break=Bl,recv=Rl},		%Set correct receive labels
    {Ris,Raft,St5} = cg_recv_mesg(Rvar, Rm, Tl, Int1, St4),
    {Wis,Taft,St6} = cg_recv_wait(Te, Tes, Le#l.i, Int1, St5),
    Int2 = sr_merge(Raft, Taft),		%Merge stack/registers
    Reg = load_vars(Rs, Int2#sr.reg),
    {Sis ++ Ris ++ [{label,Tl}] ++ Wis ++ [{label,Bl}],
     clear_dead(Int2#sr{reg=Reg}, Le#l.i, Vdb),
     St6#cg{break=St0#cg.break,recv=St0#cg.recv}}.

%% cg_recv_mesg( ) -> {[Ainstr],Aft,St}.

cg_recv_mesg({var,R}, Rm, Tl, Bef, St0) ->
    Int0 = Bef#sr{reg=put_reg(R, Bef#sr.reg)},
    Ret = fetch_reg(R, Int0#sr.reg),
    %% Int1 = clear_dead(Int0, I, Rm#l.vdb),
    Int1 = Int0,
    {Mis,Int2,St1} = match_cg(Rm, none, Int1, St0),
    {[{'%live',0},{label,St1#cg.recv},{loop_rec,{f,Tl},Ret}|Mis],Int2,St1}.

%% cg_recv_wait(Te, Tes, I, Vdb, Int2, St3) -> {[Ainstr],Aft,St}.

cg_recv_wait({atom,infinity}, Tes, I, Bef, St0) ->
    %% We know that the 'after' body will never be executed.
    %% But to keep the stack and register information up to date,
    %% we will generate the code for the 'after' body, and then discard it.
    Int1 = clear_dead(Bef, I, Tes#l.vdb),
    {_,Int2,St1} = cg_block(Tes#l.ke, Tes#l.i, Tes#l.vdb,
			      Int1#sr{reg=clear_regs(Int1#sr.reg)}, St0),
    {[{wait,{f,St1#cg.recv}}],Int2,St1};
cg_recv_wait({integer,0}, Tes, _I, Bef, St0) ->
    {Tis,Int,St1} = cg_block(Tes#l.ke, Tes#l.i, Tes#l.vdb, Bef, St0),
    {[timeout|Tis],Int,St1};
cg_recv_wait(Te, Tes, I, Bef, St0) ->
    Reg = cg_reg_arg(Te, Bef),
    %% Must have empty registers here!  Bug if anything in registers.
    Int0 = clear_dead(Bef, I, Tes#l.vdb),
    {Tis,Int,St1} = cg_block(Tes#l.ke, Tes#l.i, Tes#l.vdb,
			     Int0#sr{reg=clear_regs(Int0#sr.reg)}, St0),
    {[{wait_timeout,{f,St1#cg.recv},Reg},timeout] ++ Tis,Int,St1}.

%% recv_next_cg(Le, Vdb, StackReg, St) -> {[Ainstr],StackReg,St}.
%%  Use adjust stack to clear stack, but only need it for Aft.

recv_next_cg(Le, Vdb, Bef, St) ->
    {Sis,Aft} = adjust_stack(Bef, Le#l.i, Le#l.i+1, Vdb),
    {[{loop_rec_end,{f,St#cg.recv}}] ++ Sis,Aft,St}.	%Joke

%% try_cg(TryBlock, [BodyVar], TryBody, [ExcpVar], TryHandler, [Ret],
%%        Le, Vdb, StackReg, St) -> {[Ainstr],StackReg,St}.

try_cg(Ta, Vs, Tb, Evs, Th, Rs, Le, Vdb, Bef, St0) ->
    {B,St1} = new_label(St0),			%Body label
    {H,St2} = new_label(St1),			%Handler label
    {E,St3} = new_label(St2),			%End label
    TryTag = Ta#l.i,
    Int1 = Bef#sr{stk=put_catch(TryTag, Bef#sr.stk)},
    TryReg = fetch_stack({catch_tag,TryTag}, Int1#sr.stk),
    {Ais,Int2,St4} = cg(Ta, Vdb, Int1, St3#cg{break=B,in_catch=true}),
    Int3 = Int2#sr{stk=drop_catch(TryTag, Int2#sr.stk)},
    St5 = St4#cg{break=E,in_catch=St3#cg.in_catch},
    {Bis,Baft,St6} = cg(Tb, Vdb, Int3#sr{reg=load_vars(Vs, Int3#sr.reg)}, St5),
    {His,Haft,St7} = cg(Th, Vdb, Int3#sr{reg=load_vars(Evs, Int3#sr.reg)}, St6),
    Int4 = sr_merge(Baft, Haft),		%Merge stack/registers
    Aft = Int4#sr{reg=load_vars(Rs, Int4#sr.reg)},
    {[{'try',TryReg,{f,H}}] ++ Ais ++ 
     [{label,B},{try_end,TryReg}] ++ Bis ++
     [{label,H},{try_case,TryReg}] ++ His ++
     [{label,E}],
     clear_dead(Aft, Le#l.i, Vdb),
     St7#cg{break=St0#cg.break}}.     

try_enter_cg(Ta, Vs, Tb, Evs, Th, Le, Vdb, Bef, St0) ->
    {B,St1} = new_label(St0),			%Body label
    {H,St2} = new_label(St1),			%Handler label
    TryTag = Ta#l.i,
    Int1 = Bef#sr{stk=put_catch(TryTag, Bef#sr.stk)},
    TryReg = fetch_stack({catch_tag,TryTag}, Int1#sr.stk),
    {Ais,Int2,St3} = cg(Ta, Vdb, Int1, St2#cg{break=B,in_catch=true}),
    Int3 = Int2#sr{stk=drop_catch(TryTag, Int2#sr.stk)},
    St4 = St3#cg{in_catch=St2#cg.in_catch},
    {Bis,Baft,St5} = cg(Tb, Vdb, Int3#sr{reg=load_vars(Vs, Int3#sr.reg)}, St4),
    {His,Haft,St6} = cg(Th, Vdb, Int3#sr{reg=load_vars(Evs, Int3#sr.reg)}, St5),
    Int4 = sr_merge(Baft, Haft),		%Merge stack/registers
    Aft = Int4,
    {[{'try',TryReg,{f,H}}] ++ Ais ++ 
     [{label,B},{try_end,TryReg}] ++ Bis ++
     [{label,H},{try_case,TryReg}] ++ His,
     clear_dead(Aft, Le#l.i, Vdb),
     St6#cg{break=St0#cg.break}}.     

%% catch_cg(CatchBlock, Ret, Le, Vdb, Bef, St) -> {[Ainstr],Aft,St}.

catch_cg(C, {var,R}, Le, Vdb, Bef, St0) ->
    {B,St1} = new_label(St0),
    CatchTag = Le#l.i,
    Int1 = Bef#sr{stk=put_catch(CatchTag, Bef#sr.stk)},
    CatchReg = fetch_stack({catch_tag,CatchTag}, Int1#sr.stk),
    {Cis,Int2,St2} = cg_block(C, Le#l.i, Le#l.vdb, Int1,
			      St1#cg{break=B,in_catch=true}),
    [] = Int2#sr.reg,				%Assertion.
    Aft = Int2#sr{reg=[{0,R}],stk=drop_catch(CatchTag, Int2#sr.stk)},
    {[{'catch',CatchReg,{f,B}}] ++ Cis ++
     [{label,B},{catch_end,CatchReg}],
     clear_dead(Aft, Le#l.i, Vdb),
     St2#cg{break=St1#cg.break,in_catch=St1#cg.in_catch}}.

%% set_cg([Var], Constr, Le, Vdb, Bef, St) -> {[Ainstr],Aft,St}.
%%  We have to be careful how a 'set' works. First the structure is
%%  built, then it is filled and finally things can be cleared. The
%%  annotation must reflect this and make sure that the return
%%  variable is allocated first.
%%
%%  put_list for constructing a cons is an atomic instruction
%%  which can safely resuse one of the source registers as target.
%%  Also binaries can reuse a source register as target.

set_cg([{var,R}], {cons,Es}, Le, Vdb, Bef, St) ->
    [S1,S2] = map(fun ({var,V}) -> fetch_var(V, Bef);
		      (Other) -> Other
		  end, Es),
    Int0 = clear_dead(Bef, Le#l.i, Vdb),
    Int1 = Int0#sr{reg=put_reg(R, Int0#sr.reg)},
    Ret = fetch_reg(R, Int1#sr.reg),
    {[{put_list,S1,S2,Ret}], Int1, St};
set_cg([{var,R}], {binary,Segs}, Le, Vdb, Bef, #cg{in_catch=InCatch}=St) ->
    Int0 = Bef#sr{reg=put_reg(R, Bef#sr.reg)},
    Target = fetch_reg(R, Int0#sr.reg),
    Fail = bif_fail(St#cg.btype, St#cg.bfail, 42),
    Temp = find_scratch_reg(Int0#sr.reg),
    PutCode = cg_bin_put(Segs, Fail, Bef),
    {Sis,Int1} =
	case InCatch of
	    true -> adjust_stack(Int0, Le#l.i, Le#l.i+1, Vdb);
	    false -> {[],Int0}
	end,
    MaxRegs = max_reg(Bef#sr.reg),
    Aft = clear_dead(Int1, Le#l.i, Vdb),
    Code = cg_binary(PutCode, Target, Temp, Fail, MaxRegs, Le#l.a),
    {Sis++Code,Aft,St};
set_cg([{var,R}], Con, Le, Vdb, Bef, St) ->
    %% Find a place for the return register first.
    Int = Bef#sr{reg=put_reg(R, Bef#sr.reg)},
    Ret = fetch_reg(R, Int#sr.reg),
    Ais = case Con of
	      {tuple,Es} ->
		  [{put_tuple,length(Es),Ret}] ++ cg_build_args(Es, Bef);
	      {var,V} ->			% Normally removed by kernel optimizer.
		  [{move,fetch_var(V, Int),Ret}];
	      {string,Str} ->
		  [{put_string,length(Str),{string,Str},Ret}];
	      Other ->
		  [{move,Other,Ret}]
	  end,
    {Ais,clear_dead(Int, Le#l.i, Vdb),St};
set_cg([], {binary,Segs}, Le, Vdb, Bef, St) ->
    Fail = bif_fail(St#cg.btype, St#cg.bfail, 42),
    Target = find_scratch_reg(Bef#sr.reg),
    Temp = find_scratch_reg(put_reg(Target, Bef#sr.reg)),
    PutCode = cg_bin_put(Segs, Fail, Bef),
    MaxRegs = max_reg(Bef#sr.reg),
    Code = cg_binary(PutCode, Target, Temp, Fail, MaxRegs, Le#l.a),
    Aft = clear_dead(Bef, Le#l.i, Vdb),
    {Code,Aft,St};
set_cg([], _, Le, Vdb, Bef, St) ->
    %% This should have been stripped by compiler, just cleanup.
    {[],clear_dead(Bef, Le#l.i, Vdb), St}.


%%%
%%% Code generation for constructing binaries.
%%%

cg_binary([{bs_put_binary,Fail,{atom,all},U,_Flags,Src}|PutCode],
	  Target, Temp, Fail, MaxRegs, Anno) ->
    Live = cg_live(Target, MaxRegs),
    SzCode = cg_bitstr_size(PutCode, Target, Temp, Fail, Live),
    BinFlags = {field_flags,[]},
    Code = SzCode ++
	[case member(single_use, Anno) of
	     true ->
		 {bs_private_append,Fail,Target,U,Src,BinFlags,Target};
	     false ->
		 {bs_append,Fail,Target,0,MaxRegs,U,Src,BinFlags,Target}
	 end] ++ PutCode,
    cg_bin_opt(Code);
cg_binary(PutCode, Target, Temp, Fail, MaxRegs, _Anno) ->
    Live = cg_live(Target, MaxRegs),
    {InitOp,SzCode} = cg_binary_size(PutCode, Target, Temp, Fail, Live),
    Code = SzCode ++ [{InitOp,Fail,Target,0,MaxRegs,{field_flags,[]},Target}|PutCode],
    cg_bin_opt(Code).

cg_live({x,X}, MaxRegs) when X =:= MaxRegs -> MaxRegs+1;
cg_live({x,X}, MaxRegs) when X < MaxRegs -> MaxRegs.


%% Generate code that calculate the size of the bitstr to be
%% built in BITS.

cg_bitstr_size(PutCode, Target, Temp, Fail, Live) ->
    {Bits,Es} = cg_bitstr_size_1(PutCode, 0, []),
    reverse(cg_gen_binsize(Es, Target, Temp, Fail, Live,
			   [{move,{integer,Bits},Target}])).

cg_bitstr_size_1([{_,_,S,U,_,Src}|Next], Bits, Acc) ->
    case S of
	{integer,N} -> cg_bitstr_size_1(Next, Bits+N*U, Acc);
	{atom,all} -> cg_bitstr_size_1(Next, Bits, [{bit_size,Src}|Acc]);
	_ when U =:= 1 -> cg_bitstr_size_1(Next, Bits, [S|Acc]);
	_ -> cg_bitstr_size_1(Next, Bits, [{'*',S,U}])
    end;
cg_bitstr_size_1([], Bits, Acc) -> {Bits,Acc}.

%% Generate code that calculate the size of the bitstr to be
%% built in BYTES or BITS (depending on what is easiest).

cg_binary_size(PutCode, Target, Temp, Fail, Live) ->
    {InitInstruction,Szs} = cg_binary_size_1(PutCode, 0, []),
    SizeExpr = reverse(cg_gen_binsize(Szs, Target, Temp, Fail, Live, [{move,{integer,0},Target}])),
    {InitInstruction,SizeExpr}.

cg_binary_size_1([{_Put,_Fail,S,U,_Flags,Src}|T], Bits, Acc) ->
    cg_binary_size_2(S, U, Src, T, Bits, Acc);
cg_binary_size_1([], Bits, Acc) ->
    Bytes = Bits div 8,
    RemBits = Bits rem 8,
    Sizes0 = sort([{1,{integer,RemBits}},{8,{integer,Bytes}}|Acc]),
    Sizes = filter(fun({_,{integer,0}}) -> false;
		      (_) -> true end, Sizes0),
    case Sizes of
	[{1,_}|_] ->
	    {bs_init_bits,cg_binary_bytes_to_bits(Sizes, [])};
	[{8,_}|_] ->
	    {bs_init2,[E || {8,E} <- Sizes]}
    end.

cg_binary_size_2({integer,N}, U, _, Next, Bits, Acc) ->
    cg_binary_size_1(Next, Bits+N*U, Acc);
cg_binary_size_2({atom,all}, U, E, Next, Bits, Acc) ->
    if 
	U rem 8 =:= 0 ->
	    cg_binary_size_1(Next, Bits, [{8,{byte_size,E}}|Acc]);
	true ->
	    cg_binary_size_1(Next, Bits, [{1,{bit_size,E}}|Acc])
    end;
cg_binary_size_2(Reg, 1, _, Next, Bits, Acc) ->
    cg_binary_size_1(Next, Bits, [{1,Reg}|Acc]);
cg_binary_size_2(Reg, 8, _, Next, Bits, Acc) ->
    cg_binary_size_1(Next, Bits, [{8,Reg}|Acc]);
cg_binary_size_2(Reg, U, _, Next, Bits, Acc) ->
    cg_binary_size_1(Next, Bits, [{1,{'*',Reg,U}}|Acc]).

cg_binary_bytes_to_bits([{8,{integer,N}}|T], Acc) ->
    cg_binary_bytes_to_bits(T, [{integer,8*N}|Acc]);
cg_binary_bytes_to_bits([{8,{byte_size,Reg}}|T], Acc) ->
    cg_binary_bytes_to_bits(T, [{bit_size,Reg}|Acc]);
cg_binary_bytes_to_bits([{8,Reg}|T], Acc) ->
    cg_binary_bytes_to_bits(T, [{'*',Reg,8}|Acc]);
cg_binary_bytes_to_bits([{1,Sz}|T], Acc) ->
    cg_binary_bytes_to_bits(T, [Sz|Acc]);
cg_binary_bytes_to_bits([], Acc) ->
    cg_binary_bytes_to_bits_1(sort(Acc)).

cg_binary_bytes_to_bits_1([{integer,I},{integer,J}|T]) ->
    cg_binary_bytes_to_bits_1([{integer,I+J}|T]);
cg_binary_bytes_to_bits_1([H|T]) ->
    [H|cg_binary_bytes_to_bits_1(T)];
cg_binary_bytes_to_bits_1([]) -> [].

cg_gen_binsize([{'*',A,B}|T], Target, Temp, Fail, Live, Acc) ->
    cg_gen_binsize(T, Target, Temp, Fail, Live,
		   [{bs_add,Fail,[Target,A,B],Target}|Acc]);
cg_gen_binsize([{bit_size,B}|T], Target, Temp, Fail, Live, Acc) ->
    cg_gen_binsize([Temp|T], Target, Temp, Fail, Live,
		   [{gc_bif,bit_size,Fail,Live,[B],Temp}|Acc]);
cg_gen_binsize([{byte_size,B}|T], Target, Temp, Fail, Live, Acc) ->
    cg_gen_binsize([Temp|T], Target, Temp, Fail, Live,
		   [{gc_bif,byte_size,Fail,Live,[B],Temp}|Acc]);
cg_gen_binsize([E0|T], Target, Temp, Fail, Live, Acc) ->
    cg_gen_binsize(T, Target, Temp, Fail, Live,
		   [{bs_add,Fail,[Target,E0,1],Target}|Acc]);
cg_gen_binsize([], _, _, _, _, Acc) -> Acc.

%% cg_gen_binsize_init([{'*',A,B}|T], Target, Fail, Live, Acc) ->
%%     {bs_add,Fail,[{integer,0},A,B],Target};
%% cg_gen_binsize_init([{bit_size,B}|T], Target, Fail, Live, Acc) ->
%%     {gc_bif,bit_size,Fail,Live,[B],Target};
%% cg_gen_binsize_init([{byte_size,B}|T], Target, Fail, Live, Acc) ->
%%     {gc_bif,byte_size,Fail,Live,[B],Target}.


%% cg_bin_opt(Code0) -> Code
%%  Optimize the size calculations for binary construction.

cg_bin_opt([{move,Size,D},{bs_append,Fail,D,Extra,Regs0,U,Bin,Flags,D}|Is]) ->
    Regs = cg_bo_newregs(Regs0, D),
    cg_bin_opt([{bs_append,Fail,Size,Extra,Regs,U,Bin,Flags,D}|Is]);
cg_bin_opt([{move,Size,D},{bs_private_append,Fail,D,U,Bin,Flags,D}|Is]) ->
    cg_bin_opt([{bs_private_append,Fail,Size,U,Bin,Flags,D}|Is]);
cg_bin_opt([{move,{integer,0},D},{bs_add,_,[D,{integer,_}=S,1],Dst}|Is]) ->
    cg_bin_opt([{move,S,Dst}|Is]);
cg_bin_opt([{move,{integer,0},D},{bs_add,Fail,[D,S,U],Dst}|Is]) ->
    cg_bin_opt([{bs_add,Fail,[{integer,0},S,U],Dst}|Is]);
cg_bin_opt([{move,{integer,Bytes},D},{Op,Fail,D,Extra,Regs0,Flags,D}|Is])
  when Op =:= bs_init2; Op =:= bs_init_bits ->
    Regs = cg_bo_newregs(Regs0, D),
    cg_bin_opt([{Op,Fail,Bytes,Extra,Regs,Flags,D}|Is]);
cg_bin_opt([{move,Src1,Dst},{bs_add,Fail,[Dst,Src2,U],Dst}|Is]) ->
    cg_bin_opt([{bs_add,Fail,[Src1,Src2,U],Dst}|Is]);
cg_bin_opt([I|Is]) ->
    [I|cg_bin_opt(Is)];
cg_bin_opt([]) -> [].

cg_bo_newregs(R, {x,X}) when R-1 =:= X -> R-1;
cg_bo_newregs(R, _) -> R.

%% Common for new and old binary code generation.

cg_bin_put({bin_seg,[],S0,U,T,Fs,[E0,Next]}, Fail, Bef) ->
    S1 = case S0 of
	     {var,Sv} -> fetch_var(Sv, Bef);
	     _ -> S0
	 end,
    E1 = case E0 of
	     {var,V} -> fetch_var(V, Bef);
	     Other ->   Other
	 end,
    Op = case T of
	     integer -> bs_put_integer;
	     binary  -> bs_put_binary;
	     float   -> bs_put_float
	 end,
    [{Op,Fail,S1,U,{field_flags,Fs},E1}|cg_bin_put(Next, Fail, Bef)];
cg_bin_put({bin_end,[]}, _, _) -> [].

cg_build_args(As, Bef) ->
    map(fun ({var,V}) -> {put,fetch_var(V, Bef)};
	    (Other) -> {put,Other}
	end, As).

%% return_cg([Val], Le, Vdb, Bef, St) -> {[Ainstr],Aft,St}.
%% break_cg([Val], Le, Vdb, Bef, St) -> {[Ainstr],Aft,St}.
%%  These are very simple, just put return/break values in registers
%%  from 0, then return/break.  Use the call setup to clean up stack,
%%  but must clear registers to ensure sr_merge works correctly.

return_cg(Rs, Le, Vdb, Bef, St) ->
    {Ms,Int} = cg_setup_call(Rs, Bef, Le#l.i, Vdb),
    {comment({return,Rs}) ++ Ms ++ [return],
     Int#sr{reg=clear_regs(Int#sr.reg)},St}.

break_cg(Bs, Le, Vdb, Bef, St) ->
    {Ms,Int} = cg_setup_call(Bs, Bef, Le#l.i, Vdb),
    {comment({break,Bs}) ++ Ms ++ [{jump,{f,St#cg.break}}],
     Int#sr{reg=clear_regs(Int#sr.reg)},St}.

%% cg_reg_arg(Arg0, Info) -> Arg
%% cg_reg_args([Arg0], Info) -> [Arg]
%%  Convert argument[s] into registers. Literal values are returned unchanged.

cg_reg_args(As, Bef) -> [cg_reg_arg(A, Bef) || A <- As].

cg_reg_arg({var,V}, Bef) -> fetch_var(V, Bef);
cg_reg_arg(Literal, _) -> Literal.

%% cg_setup_call([Arg], Bef, Cur, Vdb) -> {[Instr],Aft}.
%%  Do the complete setup for a call/enter.

cg_setup_call(As, Bef, I, Vdb) ->
    {Ms,Int0} = cg_call_args(As, Bef, I, Vdb),
    %% Have set up arguments, can now clean up, compress and save to stack.
    Int1 = Int0#sr{stk=clear_dead_stk(Int0#sr.stk, I, Vdb),res=[]},
    {Sis,Int2} = adjust_stack(Int1, I, I+1, Vdb),
    {Ms ++ Sis ++ [{'%live',length(As)}],Int2}.

%% cg_call_args([Arg], SrState) -> {[Instr],SrState}.
%%  Setup the arguments to a call/enter/bif. Put the arguments into
%%  consecutive registers starting at {x,0} moving any data which
%%  needs to be saved. Return a modified SrState structure with the
%%  new register contents.  N.B. the resultant register info will
%%  contain non-variable values when there are non-variable values.
%%
%%  This routine is complicated by unsaved values in x registers.
%%  We'll move away any unsaved values that are in the registers
%%  to be overwritten by the arguments.

cg_call_args(As, Bef, I, Vdb) ->
    Regs0 = load_arg_regs(Bef#sr.reg, As),
    Unsaved = unsaved_registers(Regs0, Bef#sr.stk, I, I+1, Vdb),
    {UnsavedMoves,Regs} = move_unsaved(Unsaved, Bef#sr.reg, Regs0),
    Moves0 = gen_moves(As, Bef),
    Moves = order_moves(Moves0, find_scratch_reg(Regs)),
    {UnsavedMoves ++ Moves,Bef#sr{reg=Regs}}.

%% load_arg_regs([Reg], Arguments) -> [Reg]
%%  Update the register descriptor to include the arguments (from {x,0}
%%  and upwards). Values in argument register are overwritten.
%%  Values in x registers above the arguments are preserved.

load_arg_regs(Regs, As) -> load_arg_regs(Regs, As, 0).

load_arg_regs([_|Rs], [{var,V}|As], I) -> [{I,V}|load_arg_regs(Rs, As, I+1)];
load_arg_regs([_|Rs], [A|As], I) -> [{I,A}|load_arg_regs(Rs, As, I+1)];
load_arg_regs([], [{var,V}|As], I) -> [{I,V}|load_arg_regs([], As, I+1)];
load_arg_regs([], [A|As], I) -> [{I,A}|load_arg_regs([], As, I+1)];
load_arg_regs(Rs, [], _) -> Rs.

%% Returns the variables must be saved and are currently in the
%% x registers that are about to be overwritten by the arguments.

unsaved_registers(Regs, Stk, Fb, Lf, Vdb) ->
    [V || {V,F,L} <- Vdb,
	  F < Fb,
	  L >= Lf,
	  not on_stack(V, Stk),
	  not in_reg(V, Regs)].

in_reg(V, Regs) -> keymember(V, 2, Regs).

%% Move away unsaved variables from the registers that are to be
%% overwritten by the arguments.
move_unsaved(Vs, OrigRegs, NewRegs) ->
    move_unsaved(Vs, OrigRegs, NewRegs, []).
    
move_unsaved([V|Vs], OrigRegs, NewRegs0, Acc) ->
    NewRegs = put_reg(V, NewRegs0),
    Src = fetch_reg(V, OrigRegs),
    Dst = fetch_reg(V, NewRegs),
    move_unsaved(Vs, OrigRegs, NewRegs, [{move,Src,Dst}|Acc]);
move_unsaved([], _, Regs, Acc) -> {Acc,Regs}.
    
%% gen_moves(As, Sr)
%%  Generate the basic move instruction to move the arguments
%%  to their proper registers. The list will be sorted on
%%  destinations. (I.e. the move to {x,0} will be first --
%%  see the comment to order_moves/2.)

gen_moves(As, Sr) -> gen_moves(As, Sr, 0, []).

gen_moves([{var,V}|As], Sr, I, Acc) ->
    case fetch_var(V, Sr) of
	{x,I} -> gen_moves(As, Sr, I+1, Acc);
	Reg -> gen_moves(As, Sr, I+1, [{move,Reg,{x,I}}|Acc])
    end;
gen_moves([A|As], Sr, I, Acc) ->
    gen_moves(As, Sr, I+1, [{move,A,{x,I}}|Acc]);
gen_moves([], _, _, Acc) -> lists:keysort(3, Acc).

%% order_moves([Move], ScratchReg) -> [Move]
%%  Orders move instruction so that source registers are not
%%  destroyed before they are used. If there are cycles
%%  (such as {move,{x,0},{x,1}}, {move,{x,1},{x,1}}),
%%  the scratch register is used to break up the cycle.
%%    If possible, the first move of the input list is placed
%%  last in the result list (to make the move to {x,0} occur
%%  just before the call to allow the Beam loader to coalesce
%%  the instructions).

order_moves(Ms, Scr) -> order_moves(Ms, Scr, []).

order_moves([{move,_,_}=M|Ms0], ScrReg, Acc0) ->
    {Chain,Ms} = collect_chain(Ms0, [M], ScrReg),
    Acc = reverse(Chain, Acc0),
    order_moves(Ms, ScrReg, Acc);
order_moves([], _, Acc) -> Acc.

collect_chain(Ms, Path, ScrReg) ->
    collect_chain(Ms, Path, [], ScrReg).

collect_chain([{move,Src,Same}=M|Ms0], [{move,Same,_}|_]=Path, Others, ScrReg) ->
    case keysearch(Src, 3, Path) of
	{value,_} ->				%We have a cycle.
	    {break_up_cycle(M, Path, ScrReg),reverse(Others, Ms0)};
	false ->
	    collect_chain(reverse(Others, Ms0), [M|Path], [], ScrReg)
    end;
collect_chain([M|Ms], Path, Others, ScrReg) ->
    collect_chain(Ms, Path, [M|Others], ScrReg);
collect_chain([], Path, Others, _) ->
    {Path,Others}.

break_up_cycle({move,Src,_}=M, Path, ScrReg) ->
    [{move,ScrReg,Src},M|break_up_cycle1(Src, Path, ScrReg)].

break_up_cycle1(Dst, [{move,Src,Dst}|Path], ScrReg) ->
    [{move,Src,ScrReg}|Path];
break_up_cycle1(Dst, [M|Path], LastMove) ->
    [M|break_up_cycle1(Dst, Path, LastMove)].

%% clear_dead(Sr, Until, Vdb) -> Aft.
%%  Remove all variables in Sr which have died AT ALL so far.

clear_dead(Sr, Until, Vdb) ->
    Sr#sr{reg=clear_dead_reg(Sr, Until, Vdb),
	  stk=clear_dead_stk(Sr#sr.stk, Until, Vdb)}.

clear_dead_reg(Sr, Until, Vdb) ->
    Reg = map(fun ({I,V}) ->
		      case vdb_find(V, Vdb) of
			  {V,_,L} when L > Until -> {I,V};
			  _ -> free		%Remove anything else
		      end;
		  ({reserved,I,V}) -> {reserved,I,V};
		  (free) -> free
	      end, Sr#sr.reg),
    reserve(Sr#sr.res, Reg, Sr#sr.stk).

clear_dead_stk(Stk, Until, Vdb) ->
    map(fun ({V}) ->
		case vdb_find(V, Vdb) of
		    {V,_,L} when L > Until -> {V};
		    _ -> dead			%Remove anything else
		end;
	    (free) -> free;
	    (dead) -> dead
	end, Stk).

%% sr_merge(Sr1, Sr2) -> Sr.
%%  Merge two stack/register states keeping the longest of both stack
%%  and register. Perform consistency check on both, elements must be
%%  the same.  Allow frame size 'void' to make easy creation of
%%  "empty" frame.

sr_merge(#sr{reg=R1,stk=S1,res=[]}, #sr{reg=R2,stk=S2,res=[]}) ->
    #sr{reg=longest(R1, R2),stk=longest(S1, S2),res=[]};
sr_merge(void, S2) -> S2#sr{res=[]}.

longest([H|T1], [H|T2]) -> [H|longest(T1, T2)];
longest([dead|T1], [free|T2]) -> [dead|longest(T1, T2)];
longest([free|T1], [dead|T2]) -> [dead|longest(T1, T2)];
longest([dead|T1], []) -> [dead|T1];
longest([], [dead|T2]) -> [dead|T2];
longest([free|T1], []) -> [free|T1];
longest([], [free|T2]) -> [free|T2];
longest([], []) -> [].

%% adjust_stack(Bef, FirstBefore, LastFrom, Vdb) -> {[Ainstr],Aft}.
%%  Do complete stack adjustment by compressing stack and adding
%%  variables to be saved.  Try to optimise ordering on stack by
%%  having reverse order to their lifetimes.
%%
%%  In Beam, there is a fixed stack frame and no need to do stack compression.

adjust_stack(Bef, Fb, Lf, Vdb) ->
    Stk0 = Bef#sr.stk,
    {Stk1,Saves} = save_stack(Stk0, Fb, Lf, Vdb),
    {saves(Saves, Bef#sr.reg, Stk1),
     Bef#sr{stk=Stk1}}.

%% save_stack(Stack, FirstBefore, LastFrom, Vdb) -> {[SaveVar],NewStack}.
%%  Save variables which are used past current point and which are not
%%  already on the stack.

save_stack(Stk0, Fb, Lf, Vdb) ->
    %% New variables that are in use but not on stack.
    New = [ {V,F,L} || {V,F,L} <- Vdb,
		   F < Fb,
		   L >= Lf,
		   not on_stack(V, Stk0) ],
    %% Add new variables that are not just dropped immediately.
    %% N.B. foldr works backwards from the end!!
    Saves = [ V || {V,_,_} <- keysort(3, New) ],
    Stk1 = foldr(fun (V, Stk) -> put_stack(V, Stk) end, Stk0, Saves),
    {Stk1,Saves}.

%% saves([SaveVar], Reg, Stk) -> [{move,Reg,Stk}].
%%  Generate move instructions to save variables onto stack.  The
%%  stack/reg info used is that after the new stack has been made.

saves(Ss, Reg, Stk) ->
    map(fun (V) ->
		{move,fetch_reg(V, Reg),fetch_stack(V, Stk)}
	end, Ss).

%% comment(C) -> ['%'{C}].

%comment(C) -> [{'%',C}].
comment(_) -> [].

%% fetch_var(VarName, StkReg) -> r{R} | sp{Sp}.
%% find_var(VarName, StkReg) -> ok{r{R} | sp{Sp}} | error.
%%  Fetch/find a variable in either the registers or on the
%%  stack. Fetch KNOWS it's there.

fetch_var(V, Sr) ->
    case find_reg(V, Sr#sr.reg) of
	{ok,R} -> R;
	error -> fetch_stack(V, Sr#sr.stk)
    end.

% find_var(V, Sr) ->
%     case find_reg(V, Sr#sr.reg) of
% 	{ok,R} -> {ok,R};
% 	error ->
% 	    case find_stack(V, Sr#sr.stk) of
% 		{ok,S} -> {ok,S};
% 		error -> error
% 	    end
%     end.

load_vars(Vs, Regs) ->
    foldl(fun ({var,V}, Rs) -> put_reg(V, Rs) end, Regs, Vs).

%% put_reg(Val, Regs) -> Regs.
%% free_reg(Val, Regs) -> Regs.
%% find_reg(Val, Regs) -> ok{r{R}} | error.
%% fetch_reg(Val, Regs) -> r{R}.
%%  Functions to interface the registers.
%%  put_reg puts a value into a free register,
%%  load_reg loads a value into a fixed register
%%  free_reg frees a register containing a specific value.

% put_regs(Vs, Rs) -> foldl(fun put_reg/2, Rs, Vs).

put_reg(V, Rs) -> put_reg_1(V, Rs, 0).

put_reg_1(V, [free|Rs], I) -> [{I,V}|Rs];
put_reg_1(V, [{reserved,I,V}|Rs], I) -> [{I,V}|Rs];
put_reg_1(V, [R|Rs], I) -> [R|put_reg_1(V, Rs, I+1)];
put_reg_1(V, [], I) -> [{I,V}].

% free_reg(V, [{I,V}|Rs]) -> [free|Rs];
% free_reg(V, [R|Rs]) -> [R|free_reg(V, Rs)];
% free_reg(V, []) -> [].

fetch_reg(V, [{I,V}|_]) -> {x,I};
fetch_reg(V, [_|SRs]) -> fetch_reg(V, SRs).

find_reg(V, [{I,V}|_]) -> {ok,{x,I}};
find_reg(V, [_|SRs]) -> find_reg(V, SRs);
find_reg(_, []) -> error.

%% For the bit syntax, we need a scratch register if we are constructing
%% a binary that will not be used.

find_scratch_reg(Rs) -> find_scratch_reg(Rs, 0).
    
find_scratch_reg([free|_], I) -> {x,I};
find_scratch_reg([_|Rs], I) -> find_scratch_reg(Rs, I+1);
find_scratch_reg([], I) -> {x,I}.

%%copy_reg(Val, R, Regs) -> load_reg(Val, R, Regs).
%%move_reg(Val, R, Regs) -> load_reg(Val, R, free_reg(Val, Regs)).

replace_reg_contents(Old, New, [{I,Old}|Rs]) -> [{I,New}|Rs];
replace_reg_contents(Old, New, [R|Rs]) -> [R|replace_reg_contents(Old, New, Rs)].

%%clear_regs(Regs) -> map(fun (R) -> free end, Regs).
clear_regs(_) -> [].

max_reg(Regs) ->
    foldl(fun ({I,_}, _) -> I;
	      (_, Max) -> Max end,
	  -1, Regs) + 1.

%% put_stack(Val, [{Val}]) -> [{Val}].
%% fetch_stack(Var, Stk) -> sp{S}.
%% find_stack(Var, Stk) -> ok{sp{S}} | error.
%%  Functions to interface the stack.

put_stack(Val, []) -> [{Val}];
put_stack(Val, [dead|Stk]) -> [{Val}|Stk];
put_stack(Val, [free|Stk]) -> [{Val}|Stk];
put_stack(Val, [NotFree|Stk]) -> [NotFree|put_stack(Val, Stk)].

put_stack_carefully(Val, Stk0) ->
    case catch put_stack_carefully1(Val, Stk0) of
	error -> error;
	Stk1 when is_list(Stk1) -> Stk1
    end.

put_stack_carefully1(_, []) -> throw(error);
put_stack_carefully1(Val, [dead|Stk]) -> [{Val}|Stk];
put_stack_carefully1(Val, [free|Stk]) -> [{Val}|Stk];
put_stack_carefully1(Val, [NotFree|Stk]) ->
    [NotFree|put_stack_carefully1(Val, Stk)].

fetch_stack(Var, Stk) -> fetch_stack(Var, Stk, 0).

fetch_stack(V, [{V}|_], I) -> {yy,I};
fetch_stack(V, [_|Stk], I) -> fetch_stack(V, Stk, I+1).

% find_stack(Var, Stk) -> find_stack(Var, Stk, 0).

% find_stack(V, [{V}|Stk], I) -> {ok,{yy,I}};
% find_stack(V, [O|Stk], I) -> find_stack(V, Stk, I+1);
% find_stack(V, [], I) -> error.

on_stack(V, Stk) -> keymember(V, 1, Stk).

%% put_catch(CatchTag, Stack) -> Stack'
%% drop_catch(CatchTag, Stack) -> Stack'
%%  Special interface for putting and removing catch tags, to ensure that
%%  catches nest properly. Also used for try tags.

put_catch(Tag, Stk0) -> put_catch(Tag, reverse(Stk0), []).

put_catch(Tag, [], Stk) ->
    put_stack({catch_tag,Tag}, Stk);
put_catch(Tag, [{{catch_tag,_}}|_]=RevStk, Stk) ->
    reverse(RevStk, put_stack({catch_tag,Tag}, Stk));
put_catch(Tag, [Other|Stk], Acc) ->
    put_catch(Tag, Stk, [Other|Acc]).

drop_catch(Tag, [{{catch_tag,Tag}}|Stk]) -> [free|Stk];
drop_catch(Tag, [Other|Stk]) -> [Other|drop_catch(Tag, Stk)].

%% new_label(St) -> {L,St}.

new_label(#cg{lcount=Next}=St) ->
    {Next,St#cg{lcount=Next+1}}.

flatmapfoldl(F, Accu0, [Hd|Tail]) ->
    {R,Accu1} = F(Hd, Accu0),
    {Rs,Accu2} = flatmapfoldl(F, Accu1, Tail),
    {R++Rs,Accu2};
flatmapfoldl(_, Accu, []) -> {[],Accu}.
