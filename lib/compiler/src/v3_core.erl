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
%% Purpose : Transform normal Erlang to Core Erlang

%% At this stage all preprocessing has been done. All that is left are
%% "pure" Erlang functions.
%%
%% Core transformation is done in three stages:
%%
%% 1. Flatten expressions into an internal core form without doing
%%    matching.
%%
%% 2. Step "forwards" over the icore code annotating each "top-level"
%%    thing with variable usage.  Detect bound variables in matching
%%    and replace with explicit guard test.  Annotate "internal-core"
%%    expressions with variables they use and create.  Convert matches
%%    to cases when not pure assignments.
%%
%% 3. Step "backwards" over icore code using variable usage
%%    annotations to change implicit exported variables to explicit
%%    returns.
%%
%% To ensure the evaluation order we ensure that all arguments are
%% safe.  A "safe" is basically a core_lib simple with VERY restricted
%% binaries.
%%
%% We have to be very careful with matches as these create variables.
%% While we try not to flatten things more than necessary we must make
%% sure that all matches are at the top level.  For this we use the
%% type "novars" which are non-match expressions.  Cases and receives
%% can also create problems due to exports variables so they are not
%% "novars" either.  I.e. a novars will not export variables.
%%
%% Annotations in the #iset, #iletrec, and all other internal records
%% is kept in a record, #a, not in a list as in proper core.  This is
%% easier and faster and creates no problems as we have complete control
%% over all annotations.
%%
%% On output, the annotation for most Core Erlang terms will contain
%% the source line number. A few terms will be marked with the atom
%% atom 'compiler_generated', to indicate that the compiler has generated
%% them and that no warning should be generated if they are optimized
%% away.
%% 
%%
%% In this translation:
%%
%% call ops are safes
%% call arguments are safes
%% match arguments are novars
%% case arguments are novars
%% receive timeouts are novars
%% let/set arguments are expressions
%% fun is not a safe

-module(v3_core).

-export([module/2,format_error/1]).

-import(lists, [reverse/1,map/2,member/2,foldl/3,foldr/3,mapfoldl/3,
		splitwith/2,any/2]).
-import(ordsets, [add_element/2,del_element/2,is_element/2,
		  union/1,union/2,intersection/2,subtract/2]).

-include("core_parse.hrl").

%% Internal core expressions and help functions.
%% N.B. annotations fields in place as normal Core expressions.

-record(a, {us=[],ns=[],anno=[]}).		%Internal annotation

-record(iset, {anno=#a{},var,arg}).
-record(iletrec, {anno=#a{},defs,body}).
-record(imatch, {anno=#a{},pat,guard=[],arg,fc}).
-record(icase, {anno=#a{},args,clauses,fc}).
-record(iclause, {anno=#a{},pats,pguard=[],guard,body}).
-record(ifun, {anno=#a{},id,vars,clauses,fc}).
-record(iapply, {anno=#a{},op,args}).
-record(icall, {anno=#a{},module,name,args}).
-record(iprimop, {anno=#a{},name,args}).
-record(itry, {anno=#a{},args,vars,body,evars,handler}).
-record(icatch, {anno=#a{},body}).
-record(ireceive1, {anno=#a{},clauses}).
-record(ireceive2, {anno=#a{},clauses,timeout,action}).
-record(iprotect, {anno=#a{},body}).
-record(ibinary, {anno=#a{},segments}).		%Not used in patterns.

-record(core, {vcount=0,			%Variable counter
	       fcount=0,			%Function counter
	       in_guard=false,			%In guard or not.
	       ws=[],				%Warnings.
               file=[{file,""}]}).              %File

module({Mod,Exp,Forms}, _Opts) ->
    Cexp = map(fun ({N,A}) -> #c_fname{id=N,arity=A} end, Exp),
    {Kfs0,As0,Ws,_File} = foldl(fun form/2, {[],[],[],[]}, Forms),
    Kfs = reverse(Kfs0),
    As = reverse(As0),
    {ok,#c_module{name=#c_literal{val=Mod},exports=Cexp,attrs=As,defs=Kfs},Ws}.

form({function,_,_,_,_}=F0, {Fs,As,Ws0,File}) ->
    {F,Ws} = function(F0, Ws0, File),
    {[F|Fs],As,Ws,File};
form({attribute,_,file,{File,_Line}}, {Fs,As,Ws,_}) ->
    {Fs,As,Ws,File};
form({attribute,_,_,_}=F, {Fs,As,Ws,File}) ->
    {Fs,[attribute(F)|As],Ws,File}.

attribute({attribute,_,Name,Val}) ->
    {core_lib:make_literal(Name),core_lib:make_literal(Val)}.

function({function,_,Name,Arity,Cs0}, Ws0, File) ->
    %%ok = io:fwrite("~p - ", [{Name,Arity}]),
    St0 = #core{vcount=0,ws=Ws0,file=[{file,File}]},
    {B0,St1} = body(Cs0, Arity, St0),
    %%ok = io:fwrite("1", []),
    %%ok = io:fwrite("~w:~p~n", [?LINE,B0]),
    {B1,St2} = ubody(B0, St1),
    %%ok = io:fwrite("2", []),
    %%ok = io:fwrite("~w:~p~n", [?LINE,B1]),
    {B2,#core{ws=Ws}} = cbody(B1, St2),
    %%ok = io:fwrite("3~n", []),
    {{#c_fname{id=Name,arity=Arity},B2},Ws}.

body(Cs0, Arity, St0) ->
    Anno = lineno_anno(element(2, hd(Cs0)), St0),
    {Args,St1} = new_vars(Anno, Arity, St0),
    {Cs1,St2} = clauses(Cs0, St1),
    {Ps,St3} = new_vars(Arity, St2),    %Need new variables here
    Fc = fail_clause(Ps, #c_tuple{es=[#c_literal{val=function_clause}|Ps]}),
    {#ifun{anno=#a{anno=Anno},id=[],vars=Args,clauses=Cs1,fc=Fc},St3}.

%% clause(Clause, State) -> {Cclause,State} | noclause.
%% clauses([Clause], State) -> {[Cclause],State}.
%%  Convert clauses.  Trap bad pattern aliases and remove clause from
%%  clause list.

clauses([C0|Cs0], St0) ->
    case clause(C0, St0) of
	{noclause,St} -> clauses(Cs0, St);
	{C,St1} ->
	    {Cs,St2} = clauses(Cs0, St1),
	    {[C|Cs],St2}
    end;
clauses([], St) -> {[],St}.

clause({clause,Lc,H0,G0,B0}, St0) ->
    case catch head(H0, St0) of
	{'EXIT',_}=Exit -> exit(Exit);		%Propagate error
	nomatch ->
	    St = add_warning(Lc, nomatch, St0),
	    {noclause,St};			%Bad pattern
	H1 ->
	    {G1,St1} = guard(G0, St0),
	    {B1,St2} = exprs(B0, St1),
            Anno = lineno_anno(Lc, St2),
	    {#iclause{anno=#a{anno=Anno},pats=H1,guard=G1,body=B1},St2}
    end.

clause_arity({clause,_,H0,_,_}) -> length(H0).

%% head([P], State) -> [P].

head(Ps, St) -> pattern_list(Ps, St).

%% guard([Expr], State) -> {[Cexpr],State}.
%%  Build an explict and/or tree of guard alternatives, then traverse
%%  top-level and/or tree and "protect" inner tests.

guard([], St) -> {[],St};
guard(Gs0, St0) ->
    Gs1 = foldr(fun (Gt0, Rhs) ->
			Gt1 = guard_tests(Gt0),
			L = element(2, Gt1),
			{op,L,'or',Gt1,Rhs}
		end, guard_tests(last(Gs0)), first(Gs0)),
    {Gs,St} = gexpr_top(Gs1, St0#core{in_guard=true}),
    {Gs,St#core{in_guard=false}}.
    
guard_tests([]) -> [];
guard_tests(Gs) ->
    L = element(2, hd(Gs)),
    {protect,L,foldr(fun (G, Rhs) -> {op,L,'and',G,Rhs} end, last(Gs), first(Gs))}.

%% gexpr_top(Expr, State) -> {Cexpr,State}.
%%  Generate an internal core expression of a guard test.  Explicitly
%%  handle outer boolean expressions and "protect" inner tests in a
%%  reasonably smart way.

gexpr_top(E0, St0) ->
    {E1,Eps0,Bools,St1} = gexpr(E0, [], St0),
    {E,Eps,St} = force_booleans(Bools, E1, Eps0, St1),
    {Eps++[E],St}.

%% gexpr(Expr, Bools, State) -> {Cexpr,[PreExp],Bools,State}.
%%  Generate an internal core expression of a guard test.

gexpr({protect,Line,Arg}, Bools0, St0) ->
    case gexpr(Arg, [], St0) of
	{E0,[],Bools,St1} ->
	    {E,Eps,St} = force_booleans(Bools, E0, [], St1),
	    {E,Eps,Bools0,St};
	{E0,Eps0,Bools,St1} ->
	    {E,Eps,St} = force_booleans(Bools, E0, Eps0, St1),
            Anno = lineno_anno(Line, St),
	    {#iprotect{anno=#a{anno=Anno},body=Eps++[E]},[],Bools0,St}
    end;
gexpr({op,L,'andalso',E1,E2}, Bools, St0) ->
    {#c_var{name=V0},St} = new_var(L, St0),
    V = {var,L,V0},
    False = {atom,L,false},
    E = make_bool_switch_guard(L, E1, V,
			       make_bool_switch_guard(L, E2, V,
						      {atom,L,true}, False),
			       False),
    gexpr(E, Bools, St);
gexpr({op,L,'orelse',E1,E2}, Bools, St0) ->
    {#c_var{name=V0},St} = new_var(L, St0),
    V = {var,L,V0},
    True = {atom,L,true},
    E = make_bool_switch_guard(L, E1, V, True,
			       make_bool_switch_guard(L, E2, V,
						     True, {atom,L,false})),
    gexpr(E, Bools, St);
gexpr({op,Line,Op,L,R}=Call, Bools0, St0) ->
    case erl_internal:bool_op(Op, 2) of
	true ->
	    {Le,Lps,Bools1,St1} = gexpr(L, Bools0, St0),
	    {Ll,Llps,St2} = force_safe(Le, St1),
	    {Re,Rps,Bools,St3} = gexpr(R, Bools1, St2),
	    {Rl,Rlps,St4} = force_safe(Re, St3),
	    Anno = lineno_anno(Line, St4),
	    {#icall{anno=#a{anno=Anno},	%Must have an #a{}
		    module=#c_literal{anno=Anno,val=erlang},
		    name=#c_literal{anno=Anno,val=Op},
		    args=[Ll,Rl]},Lps ++ Llps ++ Rps ++ Rlps,Bools,St4};
	false ->
	    gexpr_test(Call, Bools0, St0)
    end;
gexpr({op,Line,Op,A}=Call, Bools0, St0) ->
    case erl_internal:bool_op(Op, 1) of
	true ->
	    {Ae,Aps,Bools,St1} = gexpr(A, Bools0, St0),
	    {Al,Alps,St2} = force_safe(Ae, St1),
	    Anno = lineno_anno(Line, St2),
	    {#icall{anno=#a{anno=Anno},	%Must have an #a{}
		    module=#c_literal{anno=Anno,val=erlang},
		    name=#c_literal{anno=Anno,val=Op},
		    args=[Al]},Aps ++ Alps,Bools,St2};
	false ->
	    gexpr_test(Call, Bools0, St0)
    end;
gexpr(E0, Bools, St0) ->
    gexpr_test(E0, Bools, St0).

%% gexpr_test(Expr, Bools, State) -> {Cexpr,[PreExp],Bools,State}.
%%  Generate a guard test.  At this stage we must be sure that we have
%%  a proper boolean value here so wrap things with an true test if we
%%  don't know, i.e. if it is not a comparison or a type test.

gexpr_test({atom,L,true}, Bools, St0) ->
    {#c_literal{anno=lineno_anno(L, St0),val=true},[],Bools,St0};
gexpr_test({atom,L,false}, Bools, St0) ->
    {#c_literal{anno=lineno_anno(L, St0),val=false},[],Bools,St0};
gexpr_test(E0, Bools0, St0) ->
    {E1,Eps0,St1} = expr(E0, St0),
    %% Generate "top-level" test and argument calls.
    case E1 of
	#icall{anno=Anno,module=#c_literal{val=erlang},name=#c_literal{val=N},args=As} ->
	    Ar = length(As),
	    case erl_internal:type_test(N, Ar) orelse
		erl_internal:comp_op(N, Ar) of
		true -> {E1,Eps0,Bools0,St1};
		false ->
		    Lanno = Anno#a.anno,
		    {New,St2} = new_var(Lanno, St1),
		    Bools = [New|Bools0],
		    {#icall{anno=Anno,	%Must have an #a{}
			    module=#c_literal{anno=Lanno,val=erlang},
			    name=#c_literal{anno=Lanno,val='=:='},
			    args=[New,#c_literal{anno=Lanno,val=true}]},
		     Eps0 ++ [#iset{anno=Anno,var=New,arg=E1}],Bools,St2}
	    end;
	_ ->
	    Anno = get_ianno(E1),
	    Lanno = get_lineno_anno(E1),
	    case core_lib:is_simple(E1) of
		true ->
		    Bools = [E1|Bools0],
		    {#icall{anno=Anno,	%Must have an #a{}
			    module=#c_literal{anno=Lanno,val=erlang},
			    name=#c_literal{anno=Lanno,val='=:='},
			    args=[E1,#c_literal{anno=Lanno,val=true}]},Eps0,Bools,St1};
		false ->
		    {New,St2} = new_var(Lanno, St1),
		    Bools = [New|Bools0],
		    {#icall{anno=Anno,	%Must have an #a{}
			    module=#c_literal{anno=Lanno,val=erlang},
			    name=#c_literal{anno=Lanno,val='=:='},
			    args=[New,#c_literal{anno=Lanno,val=true}]},
		     Eps0 ++ [#iset{anno=Anno,var=New,arg=E1}],Bools,St2}
	    end
    end.

force_booleans([], E, Eps, St) ->
    {E,Eps,St};
force_booleans([V|Vs], E0, Eps0, St0) ->
    {E1,Eps1,St1} = force_safe(E0, St0),
    Lanno = element(2, V),
    Anno = #a{anno=Lanno},
    Call = #icall{anno=Anno,module=#c_literal{anno=Lanno,val=erlang},
		  name=#c_literal{anno=Lanno,val=is_boolean},
		  args=[V]},
    {New,St} = new_var(Lanno, St1),
    Iset = #iset{anno=Anno,var=New,arg=Call},
    Eps = Eps0 ++ Eps1 ++ [Iset],
    E = #icall{anno=Anno,
	       module=#c_literal{anno=Lanno,val=erlang},name=#c_literal{anno=Lanno,val='and'},
	       args=[E1,New]},
    force_booleans(Vs, E, Eps, St).

%% exprs([Expr], State) -> {[Cexpr],State}.
%%  Flatten top-level exprs.

exprs([E0|Es0], St0) ->
    {E1,Eps,St1} = expr(E0, St0),
    {Es1,St2} = exprs(Es0, St1),
    {Eps ++ [E1] ++ Es1,St2};
exprs([], St) -> {[],St}.

%% expr(Expr, State) -> {Cexpr,[PreExp],State}.
%%  Generate an internal core expression.

expr({var,L,V}, St) -> {#c_var{anno=lineno_anno(L, St),name=V},[],St};
expr({char,L,C}, St) -> {#c_literal{anno=lineno_anno(L, St),val=C},[],St};
expr({integer,L,I}, St) -> {#c_literal{anno=lineno_anno(L, St),val=I},[],St};
expr({float,L,F}, St) -> {#c_literal{anno=lineno_anno(L, St),val=F},[],St};
expr({atom,L,A}, St) -> {#c_literal{anno=lineno_anno(L, St),val=A},[],St};
expr({nil,L}, St) -> {#c_literal{anno=lineno_anno(L, St),val=[]},[],St};
expr({string,L,S}, St) -> {#c_literal{anno=lineno_anno(L, St),val=S},[],St};
expr({cons,L,H0,T0}, St0) ->
    {H1,Hps,St1} = safe(H0, St0),
    {T1,Tps,St2} = safe(T0, St1),
    A = lineno_anno(L, St2),
    case {H1,T1,Hps,Tps} of
	{#c_literal{val=H2},#c_literal{val=T2},[],[]} ->
	    {#c_literal{anno=A,val=[H2|T2]},[],St2};
	_ ->
	    {#c_cons{anno=A,hd=H1,tl=T1},Hps ++ Tps,St2}
    end;
expr({lc,L,E,Qs}, St) ->
    lc_tq(L, E, Qs, {nil,L}, St);
expr({bc,L,E,Qs}, St) ->
    bc_tq(L, E, Qs, {nil,L}, St);
expr({tuple,L,Es0}, St0) ->
    {Es1,Eps,St1} = safe_list(Es0, St0),
    A = lineno_anno(L, St1),
    case Eps =:= [] andalso lists:all(fun(#c_literal{}) -> true;
					 (_) -> false end, Es1) of
	true ->
	    Tuple = list_to_tuple([V || #c_literal{val=V} <- Es1]),
	    {#c_literal{anno=A,val=Tuple},[],St1};
	false ->
	    {#c_tuple{anno=A,es=Es1},Eps,St1}
    end;
expr({bin,L,Es0}, St0) ->
    try expr_bin(Es0, #a{anno=lineno_anno(L, St0)}, St0) of
	{_,_,_}=Res -> Res
    catch
	throw:bad_binary ->
	    St1 = add_warning(L, bad_binary, St0),
	    LineAnno = lineno_anno(L, St1),
	    As = [#c_literal{anno=LineAnno,val=badarg}],
	    {#icall{anno=#a{anno=LineAnno},	%Must have an #a{}
		    module=#c_literal{anno=LineAnno,val=erlang},
		    name=#c_literal{anno=LineAnno,val=error},
		    args=As},[],St1}
    end;
expr({block,_,Es0}, St0) ->
    %% Inline the block directly.
    {Es1,St1} = exprs(first(Es0), St0),
    {E1,Eps,St2} = expr(last(Es0), St1),
    {E1,Es1 ++ Eps,St2};
expr({'if',L,Cs0}, St0) ->
    {Cs1,St1} = clauses(Cs0, St0),
    Fc = fail_clause([], #c_literal{val=if_clause}),
    Lanno = lineno_anno(L, St1),
    {#icase{anno=#a{anno=Lanno},args=[],clauses=Cs1,fc=Fc},[],St1};
expr({'case',L,E0,Cs0}, St0) ->
    {E1,Eps,St1} = novars(E0, St0),
    {Cs1,St2} = clauses(Cs0, St1),
    {Fpat,St3} = new_var(St2),
    Fc = fail_clause([Fpat], #c_tuple{es=[#c_literal{val=case_clause},Fpat]}),
    Lanno = lineno_anno(L, St3),
    {#icase{anno=#a{anno=Lanno},args=[E1],clauses=Cs1,fc=Fc},Eps,St3};
expr({'receive',L,Cs0}, St0) ->
    {Cs1,St1} = clauses(Cs0, St0),
    {#ireceive1{anno=#a{anno=lineno_anno(L, St1)},clauses=Cs1}, [], St1};
expr({'receive',L,Cs0,Te0,Tes0}, St0) ->
    {Te1,Teps,St1} = novars(Te0, St0),
    {Tes1,St2} = exprs(Tes0, St1),
    {Cs1,St3} = clauses(Cs0, St2),
    {#ireceive2{anno=#a{anno=lineno_anno(L, St3)},
		clauses=Cs1,timeout=Te1,action=Tes1},Teps,St3};
expr({'try',L,Es0,[],Ecs,[]}, St0) ->
    %% 'try ... catch ... end'
    {Es1,St1} = exprs(Es0, St0),
    {V,St2} = new_var(St1),		%This name should be arbitrary
    {Evs,Hs,St3} = try_exception(Ecs, St2),
    Lanno = lineno_anno(L, St3),
    {#itry{anno=#a{anno=Lanno},args=Es1,vars=[V],body=[V],
	   evars=Evs,handler=Hs},
     [],St3};
expr({'try',L,Es0,Cs0,Ecs,[]}, St0) ->
    %% 'try ... of ... catch ... end'
    {Es1,St1} = exprs(Es0, St0),
    {V,St2} = new_var(St1),		%This name should be arbitrary
    {Cs1,St3} = clauses(Cs0, St2),
    {Fpat,St4} = new_var(St3),
    Fc = fail_clause([Fpat], #c_tuple{es=[#c_literal{val=try_clause},Fpat]}),
    {Evs,Hs,St5} = try_exception(Ecs, St4),
    Lanno = lineno_anno(L, St1),
    {#itry{anno=#a{anno=lineno_anno(L, St5)},args=Es1,
	   vars=[V],body=[#icase{anno=#a{anno=Lanno},args=[V],clauses=Cs1,fc=Fc}],
	   evars=Evs,handler=Hs},
     [],St5};
expr({'try',L,Es0,[],[],As0}, St0) ->
    %% 'try ... after ... end'
    {Es1,St1} = exprs(Es0, St0),
    {As1,St2} = exprs(As0, St1),
    {Evs,Hs0,St3} = try_after(As1,St2),
    %% We must kill the id for any funs in the duplicated after body,
    %% to avoid getting two local functions having the same name.
    Hs = kill_id_anns(Hs0),
    {V,St4} = new_var(St3),		% (must not exist in As1)
    %% TODO: this duplicates the 'after'-code; should lift to function.
    Lanno = lineno_anno(L, St4),
    {#itry{anno=#a{anno=Lanno},args=Es1,vars=[V],body=As1++[V],
	   evars=Evs,handler=Hs},
     [],St4};
expr({'try',L,Es,Cs,Ecs,As}, St0) ->
    %% 'try ... [of ...] [catch ...] after ... end'
    expr({'try',L,[{'try',L,Es,Cs,Ecs,[]}],[],[],As}, St0);
expr({'catch',L,E0}, St0) ->
    {E1,Eps,St1} = expr(E0, St0),
    Lanno = lineno_anno(L, St1),
    {#icatch{anno=#a{anno=Lanno},body=Eps ++ [E1]},[],St1};
expr({'fun',L,{function,F,A},{_,_,_}=Id}, St) ->
    Lanno = lineno_anno(L, St),
    {#c_fname{anno=Lanno++[{id,Id}],id=F,arity=A},[],St};
expr({'fun',L,{clauses,Cs},Id}, St) ->
    fun_tq(Id, Cs, L, St);
expr({call,L,{remote,_,M,F},As0}, St0) ->
    {[M1,F1|As1],Aps,St1} = safe_list([M,F|As0], St0),
    Lanno = lineno_anno(L, St1),
    {#icall{anno=#a{anno=Lanno},module=M1,name=F1,args=As1},Aps,St1};
expr({call,Lc,{atom,Lf,F},As0}, St0) ->
    {As1,Aps,St1} = safe_list(As0, St0),
    Op = #c_fname{anno=lineno_anno(Lf, St1),id=F,arity=length(As1)},
    {#iapply{anno=#a{anno=lineno_anno(Lc, St1)},op=Op,args=As1},Aps,St1};
expr({call,L,FunExp,As0}, St0) ->
    {Fun,Fps,St1} = safe(FunExp, St0),
    {As1,Aps,St2} = safe_list(As0, St1),
    Lanno = lineno_anno(L, St2),
    {#iapply{anno=#a{anno=Lanno},op=Fun,args=As1},Fps ++ Aps,St2};
expr({match,L,P0,E0}, St0) ->
    %% First fold matches together to create aliases.
    {P1,E1} = fold_match(E0, P0),
    {E2,Eps,St1} = novars(E1, St0),
    P2 = (catch pattern(P1, St1)),
    {Fpat,St2} = new_var(St1),
    Fc = fail_clause([Fpat], #c_tuple{es=[#c_literal{val=badmatch},Fpat]}),
    Lanno = lineno_anno(L, St2),
    case P2 of
	{'EXIT',_}=Exit -> exit(Exit);		%Propagate error
	nomatch ->
	    St = add_warning(L, nomatch, St2),
	    {#icase{anno=#a{anno=Lanno},
		    args=[E2],clauses=[],fc=Fc},Eps,St};
	_Other ->
	    {#imatch{anno=#a{anno=Lanno},pat=P2,arg=E2,fc=Fc},Eps,St2}
    end;
expr({op,_,'++',{lc,Llc,E,Qs},L2}, St) ->
    %%  Optimise this here because of the list comprehension algorithm.
    lc_tq(Llc, E, Qs, L2, St);
expr({op,L,'andalso',E1,E2}, St0) ->
    {#c_var{name=V0},St} = new_var(L, St0),
    V = {var,L,V0},
    False = {atom,L,false},
    E = make_bool_switch(L, E1, V,
			 make_bool_switch(L, E2, V,
					  {atom,L,true}, False, St0),
			 False, St0),
    expr(E, St);
expr({op,L,'orelse',E1,E2}, St0) ->
    {#c_var{name=V0},St} = new_var(L, St0),
    V = {var,L,V0},
    True = {atom,L,true},
    E = make_bool_switch(L, E1, V, True,
			 make_bool_switch(L, E2, V,
					  True, {atom,L,false}, St0), St0),
    expr(E, St);
expr({op,L,Op,A0}, St0) ->
    {A1,Aps,St1} = safe(A0, St0),
    LineAnno = lineno_anno(L, St1),
    {#icall{anno=#a{anno=LineAnno},		%Must have an #a{}
	    module=#c_literal{anno=LineAnno,val=erlang},
	    name=#c_literal{anno=LineAnno,val=Op},args=[A1]},Aps,St1};
expr({op,L,Op,L0,R0}, St0) ->
    {As,Aps,St1} = safe_list([L0,R0], St0),
    LineAnno = lineno_anno(L, St1),
    {#icall{anno=#a{anno=LineAnno},		%Must have an #a{}
	    module=#c_literal{anno=LineAnno,val=erlang},
	    name=#c_literal{anno=LineAnno,val=Op},args=As},Aps,St1}.

make_bool_switch(L, E, V, T, F, #core{in_guard=true}) ->
    make_bool_switch_guard(L, E, V, T, F);
make_bool_switch(L, E, V, T, F, #core{}) ->
    make_bool_switch_body(L, E, V, T, F).

make_bool_switch_body(L, E, V, T, F) ->
    NegL = -abs(L),
    Error = {tuple,NegL,[{atom,NegL,badarg},V]},
    {'case',NegL,E,
     [{clause,NegL,[{atom,NegL,true}],[],[T]},
      {clause,NegL,[{atom,NegL,false}],[],[F]},
      {clause,NegL,[V],[],
       [{call,NegL,{remote,NegL,{atom,NegL,erlang},{atom,NegL,error}},
	 [Error]}]}]}.

make_bool_switch_guard(_, E, _, {atom,_,true}, {atom,_,false}) -> E;
make_bool_switch_guard(L, E, V, T, F) ->
    NegL = -abs(L),
    {'case',NegL,E,
     [{clause,NegL,[{atom,NegL,true}],[],[T]},
      {clause,NegL,[{atom,NegL,false}],[],[F]},
      {clause,NegL,[V],[],[V]}
     ]}.


%% try_exception([ExcpClause], St) -> {[ExcpVar],Handler,St}.

try_exception(Ecs0, St0) ->
    %% Note that Tag is not needed for rethrow - it is already in Info.
    {Evs,St1} = new_vars(3, St0), % Tag, Value, Info
    {Ecs1,St2} = clauses(Ecs0, St1),
    [_,Value,Info] = Evs,
    Ec = #iclause{anno=#a{anno=[compiler_generated]},
		  pats=[#c_tuple{es=Evs}],guard=[#c_literal{val=true}],
		  body=[#iprimop{anno=#a{},       %Must have an #a{}
				 name=#c_literal{val=raise},
				 args=[Info,Value]}]},
    Hs = [#icase{anno=#a{},args=[#c_tuple{es=Evs}],clauses=Ecs1,fc=Ec}],
    {Evs,Hs,St2}.

try_after(As, St0) ->
    %% See above.
    {Evs,St1} = new_vars(3, St0), % Tag, Value, Info
    [_,Value,Info] = Evs,
    B = As ++ [#iprimop{anno=#a{},       %Must have an #a{}
			 name=#c_literal{val=raise},
			 args=[Info,Value]}],
    Ec = #iclause{anno=#a{anno=[compiler_generated]},
		  pats=[#c_tuple{es=Evs}],guard=[#c_literal{val=true}],
		  body=B},
    Hs = [#icase{anno=#a{},args=[#c_tuple{es=Evs}],clauses=[],fc=Ec}],
    {Evs,Hs,St1}.

%% expr_bin([ArgExpr], St) -> {[Arg],[PreExpr],St}.
%%  Flatten the arguments of a bin. Do this straight left to right!

expr_bin(Es0, Anno, St0) ->
    case constant_bin(Es0) of
	error ->
	    {Es,Eps,St} = expr_bin_1(Es0, St0),
	    {#ibinary{anno=Anno,segments=Es},Eps,St};
	Bin when is_binary(Bin) ->
	    {#c_literal{anno=Anno,val=Bin},[],St0}
    end.

%% constant_bin([{bin_element,_,_,_,_}]) -> binary() | error
%%  If the binary construction is truly constant (no variables,
%%  no native fields), evaluate and return the binary; otherwise
%%  return 'error'.
%%
%%  Note: bistrs are not literals yet, to avoid problems with
%%  sequences such as '<<0:7>>, ok', which causes an exception with
%%  bit-level binaries disabled and returns 'ok' if they are
%%  enabled.

constant_bin(Es) ->
    IndefiniteEndian = fun({bin_element,_,_,_,Opts}) ->
			       not(member(big, Opts) orelse
				   member(little, Opts))
		       end,
    case any(IndefiniteEndian, Es) of
	true -> error;
	false ->
	    EmptyBindings = erl_eval:new_bindings(),
	    EvalFun = fun({integer,_,Sz}, B) -> {value,Sz,B} end,
	    case eval_bits:expr_grp(Es, EmptyBindings, EvalFun) of
		{value,Bin,EmptyBindings} when is_binary(Bin) ->
		    case erlang:bitsize(Bin) rem 8 =:= 0 of
			true -> Bin;
			false -> error
		    end;
		_ ->
		    error
	    end
    end.

expr_bin_1(Es, St) ->
    foldr(fun (E, {Ces,Esp,St0}) ->
		  {Ce,Ep,St1} = bitstr(E, St0),
		  {[Ce|Ces],Ep ++ Esp,St1}
	  end, {[],[],St}, Es).

bitstr({bin_element,_,E0,Size0,[Type,{unit,Unit}|Flags]}, St0) ->
    {E1,Eps,St1} = safe(E0, St0),
    {Size1,Eps2,St2} = safe(Size0, St1),
    case {Type,E1} of
	{_,#c_var{}} -> ok;
	{integer,#c_literal{val=I}} when is_integer(I) -> ok;
	{float,#c_literal{val=V}} when is_number(V) -> ok;
	{binary,#c_literal{val=V}} when is_binary(V) -> ok;
	{_,_} -> throw(bad_binary)
    end,
    {#c_bitstr{val=E1,size=Size1,
	       unit=core_lib:make_literal(Unit),
	       type=core_lib:make_literal(Type),
	       flags=core_lib:make_literal(Flags)},
     Eps ++ Eps2,St2}.

%% fun_tq(Id, [Clauses], Line, State) -> {Fun,[PreExp],State}.

fun_tq(Id, Cs0, L, St0) ->
    Arity = clause_arity(hd(Cs0)),
    {Cs1,St1} = clauses(Cs0, St0),
    {Args,St2} = new_vars(Arity, St1),
    {Ps,St3} = new_vars(Arity, St2),		%Need new variables here
    Fc = fail_clause(Ps, #c_tuple{es=[#c_literal{val=function_clause}|Ps]}),
    Fun = #ifun{anno=#a{anno=lineno_anno(L, St3)},
		id=[{id,Id}],				%We KNOW!
		vars=Args,clauses=Cs1,fc=Fc},
    {Fun,[],St3}.

%% lc_tq(Line, Exp, [Qualifier], More, State) -> {LetRec,[PreExp],State}.
%%  This TQ from Simon PJ pp 127-138.  
%%  This gets a bit messy as we must transform all directly here.  We
%%  recognise guard tests and try to fold them together and join to a
%%  preceding generators, this should give us better and more compact
%%  code.
%%  More could be transformed before calling lc_tq.

lc_tq(Line, E, [{generate,Lg,P,G}|Qs0], More, St0) ->
    {Gs,Qs1} =  splitwith(fun is_guard_test/1, Qs0),
    {Name,St1} = new_fun_name("lc", St0),
    {Head,St2} = new_var(St1),
    {Tname,St3} = new_var_name(St2),
    LA = lineno_anno(Line, St2),
    LAnno = #a{anno=LA},
    Tail = #c_var{anno=LA,name=Tname},
    {Arg,St4} = new_var(St3),
    NewMore = {call,Lg,{atom,Lg,Name},[{var,Lg,Tname}]},
    {Guardc,St5} = lc_guard_tests(Gs, St4),	%These are always flat!
    {Lc,Lps,St6} = lc_tq(Line, E, Qs1, NewMore, St5),
    {Mc,Mps,St7} = expr(More, St6),
    {Nc,Nps,St8} = expr(NewMore, St7),
    case catch pattern(P, St8) of
	{'EXIT',_}=Exit ->
	    St9 = St8,
	    Pc = nomatch,
	    exit(Exit);		%Propagate error
	nomatch ->
	    St9 = add_warning(Line, nomatch, St8),
	    Pc = nomatch;
	Pc ->
	    St9 = St8
    end,
    {Gc,Gps,St10} = safe(G, St9),		%Will be a function argument!
    Fc = fail_clause([Arg], #c_tuple{anno=LA,
				     es=[#c_literal{val=function_clause},Arg]}),
    %% Avoid constructing a default clause if the list comprehension
    %% only has a variable as generator and there are no guard
    %% tests. In other words, if the comprehension is equivalent to
    %% lists:map/2.
    case {Guardc, Pc} of
	{[], #c_var{}} ->
	    Cs0 = [#iclause{anno=LAnno,
			    pats=[#c_literal{anno=LA,val=[]}],guard=[],
			    body=Mps ++ [Mc]}];
	_ ->
	    Cs0 = [#iclause{anno=#a{anno=[compiler_generated|LA]},
			    pats=[#c_cons{anno=LA,hd=Head,tl=Tail}],
			    guard=[],
			    body=Nps ++ [Nc]},
		   #iclause{anno=LAnno,
			    pats=[#c_literal{anno=LA,val=[]}],guard=[],
			    body=Mps ++ [Mc]}]
    end,
    Cs = case Pc of
	     nomatch -> Cs0;
	     _ ->
		 [#iclause{anno=LAnno,
			   pats=[#c_cons{anno=LA,hd=Pc,tl=Tail}],
			   guard=Guardc,
			   body=Lps ++ [Lc]}|Cs0]
	 end,
    Fun = #ifun{anno=LAnno,id=[],vars=[Arg],clauses=Cs,fc=Fc},
    {#iletrec{anno=LAnno,defs=[{Name,Fun}],
	      body=Gps ++ [#iapply{anno=LAnno,
				   op=#c_fname{anno=LA,id=Name,arity=1},
				   args=[Gc]}]},
     [],St10};
lc_tq(Line, E, [{b_generate,Lg,P,G}|Qs0], More, St0) ->
  {Gs,Qs1} =  splitwith(fun is_guard_test/1, Qs0),
  {Name,St1} = new_fun_name("blc", St0),
  {Tname,St2} = new_var_name(St1),
  LA = lineno_anno(Line, St2),
  LAnno = #a{anno=LA},
  HeadBinPattern = pattern(P,St2),
  #c_binary{segments=Ps} = HeadBinPattern,
  {EPs,St3} = emasculate_semgments(Ps,St2),
  Tail = #c_var{anno=LA,name=Tname},
  TailSegment = #c_bitstr{val=Tail,size=core_lib:make_literal(all),
			  unit=core_lib:make_literal(1),
			  type=core_lib:make_literal(binary),
			  flags=core_lib:make_literal([big,unsigned])},
  Pattern = HeadBinPattern#c_binary{segments=Ps ++ [TailSegment]},
   EPattern = HeadBinPattern#c_binary{segments=EPs ++ [TailSegment]},
  {Arg,St4} = new_var(St3),
  {Guardc,St5} = lc_guard_tests(Gs, St4),	%These are always flat!
  NewMore = {call,Lg,{atom,Lg,Name},[{var,Lg,Tname}]},
  {Bc,Bps,St6} = lc_tq(Line, E, Qs1, NewMore, St5),
  {Mc,Mps,St7} = expr(More, St6),
  {Gc,Gps,St10} = safe(G, St7),		%Will be a function argument!
  Fc = fail_clause([Arg], #c_tuple{anno=LA,
				   es=[#c_literal{val=function_clause},Arg]}),
  Cs = [#iclause{anno=#a{anno=[compiler_generated|LA]},
		 pats=[Pattern],
		 guard=Guardc,
		 body=Bps ++ [Bc]},
	#iclause{anno=#a{anno=[compiler_generated|LA]},
		 pats=[EPattern],
		 guard=[],
		 body=[#iapply{anno=LAnno,
			       op=#c_fname{anno=LA,id=Name,arity=1},
			       args=[Tail]}]},
	#iclause{anno=LAnno,
		 pats=[#c_binary{anno=LA, segments=[TailSegment]}],guard=[],
		 body=Mps ++ [Mc]}],
  Fun = #ifun{anno=LAnno,id=[],vars=[Arg],clauses=Cs,fc=Fc},
  {#iletrec{anno=LAnno,defs=[{Name,Fun}],
	    body=Gps ++ [#iapply{anno=LAnno,
				 op=#c_fname{anno=LA,id=Name,arity=1},
				 args=[Gc]}]},
   [],St10};
lc_tq(Line, E, [Fil0|Qs0], More, St0) ->
    %% Special case sequences guard tests.
    LA = lineno_anno(Line, St0),
    LAnno = #a{anno=LA},
    case is_guard_test(Fil0) of
	true ->
	    {Gs0,Qs1} = splitwith(fun is_guard_test/1, Qs0),
	    {Lc,Lps,St1} = lc_tq(Line, E, Qs1, More, St0),
	    {Mc,Mps,St2} = expr(More, St1),
	    {Gs,St3} = lc_guard_tests([Fil0|Gs0], St2), %These are always flat!
	    {#icase{anno=LAnno,
		    args=[],
		    clauses=[#iclause{anno=LAnno,pats=[],
				      guard=Gs,body=Lps ++ [Lc]}],
		    fc=#iclause{anno=LAnno,pats=[],guard=[],body=Mps ++ [Mc]}},
	     [],St3};
	false ->
	    {Lc,Lps,St1} = lc_tq(Line, E, Qs0, More, St0),
	    {Mc,Mps,St2} = expr(More, St1),
	    {Fpat,St3} = new_var(St2),
	    Fc = fail_clause([Fpat], #c_tuple{es=[#c_literal{val=case_clause},Fpat]}),
	    %% Do a novars little optimisation here.
	    case Fil0 of
		{op,_,'not',Fil1} ->
		    {Filc,Fps,St4} = novars(Fil1, St3),
		    {#icase{anno=LAnno,
			    args=[Filc],
			    clauses=[#iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=true}],
					      guard=[],
					      body=Mps ++ [Mc]},
				     #iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=false}],
					      guard=[],
					      body=Lps ++ [Lc]}],
			    fc=Fc},
		     Fps,St4};
		_Other ->
		    {Filc,Fps,St4} = novars(Fil0, St3),
		    {#icase{anno=LAnno,
			    args=[Filc],
			    clauses=[#iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=true}],
					      guard=[],
					      body=Lps ++ [Lc]},
				     #iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=false}],
					      guard=[],
					      body=Mps ++ [Mc]}],
			    fc=Fc},
		     Fps,St4}
	    end
    end;
lc_tq(Line, E, [], More, St) ->
    expr({cons,Line,E,More}, St).

%% bc_tq(Line, Exp, [Qualifier], More, State) -> {LetRec,[PreExp],State}.
%%  This TQ from Gustafsson ERLANG'05.  
%%  This gets a bit messy as we must transform all directly here.  We
%%  recognise guard tests and try to fold them together and join to a
%%  preceding generators, this should give us better and more compact
%%  code.
%%  More could be transformed before calling bc_tq.

bc_tq(Line, Exp, Qualifiers, More, St0) ->
    {LetRec,PreExp,St1} = bc_tq1(Line, Exp, Qualifiers, More, St0),
    LineAnno = lineno_anno(Line, St1),
    {Arg,St2} = new_var(St1),
    {#icall{anno=#a{anno=LineAnno},
	    module=#c_literal{anno=LineAnno,val=erlang},
	    name=#c_literal{anno=LineAnno,val=list_to_bitstr},
	    args=[Arg]}, 
      PreExp++[#iset{anno=#a{anno=LineAnno},var=Arg,arg=LetRec}], St2}.

bc_tq1(Line, E, [{generate,Lg,P,G}|Qs0], More, St0) ->
    {Gs,Qs1} =  splitwith(fun is_guard_test/1, Qs0),
    {Name,St1} = new_fun_name("lbc", St0),
    {Head,St2} = new_var(St1),
    {Tname,St3} = new_var_name(St2),
    LA = lineno_anno(Line, St3),
    LAnno = #a{anno=LA},
    Tail = #c_var{anno=LA,name=Tname},
    {Arg,St4} = new_var(St3),
    NewMore = {call,Lg,{atom,Lg,Name},[{var,Lg,Tname}]},
    {Guardc,St5} = lc_guard_tests(Gs, St4),	%These are always flat!
    {Lc,Lps,St6} = bc_tq1(Line, E, Qs1, NewMore, St5),
    {Mc,Mps,St7} = expr(More, St6),
    {Nc,Nps,St8} = expr(NewMore, St7),
    case catch pattern(P,St8) of
	{'EXIT',_}=Exit ->
	    St9 = St8,
	    Pc = nomatch,
	    exit(Exit);		%Propagate error
	nomatch ->
	    St9 = add_warning(Line, nomatch, St8),
	    Pc = nomatch;
	Pc ->
	    St9 = St8
    end,
    {Gc,Gps,St10} = safe(G, St9),		%Will be a function argument!
    Fc = fail_clause([Arg], #c_tuple{anno=LA,
				     es=[#c_literal{val=function_clause},Arg]}),
  case {Guardc, Pc} of
    {[], #c_var{}} ->
      Cs0 = [#iclause{anno=LAnno,
		      pats=[#c_literal{anno=LA,val=[]}],guard=[],
		      body=Mps ++ [Mc]}];
    _ ->
      Cs0 = [#iclause{anno=#a{anno=[compiler_generated|LA]},
		      pats=[#c_cons{anno=LA,hd=Head,tl=Tail}],
		      guard=[],
		      body=Nps ++ [Nc]},
	     #iclause{anno=LAnno,
		      pats=[#c_literal{anno=LA,val=[]}],guard=[],
		      body=Mps ++ [Mc]}]
  end,
  Cs = case Pc of
	 nomatch -> Cs0;
	 _ ->
	   [#iclause{anno=LAnno,
		     pats=[#c_cons{anno=LA,hd=Pc,tl=Tail}],
		     guard=Guardc,
		     body=Lps ++ [Lc]}|Cs0]
       end,
  Fun = #ifun{anno=LAnno,id=[],vars=[Arg],clauses=Cs,fc=Fc},
  {#iletrec{anno=LAnno,defs=[{Name,Fun}],
	    body=Gps ++ [#iapply{anno=LAnno,
				 op=#c_fname{anno=LA,id=Name,arity=1},
				 args=[Gc]}]},
   [],St10};   
bc_tq1(Line, E, [{b_generate,Lg,P,G}|Qs0], More, St0) ->
  {Gs,Qs1} =  splitwith(fun is_guard_test/1, Qs0),
  {Name,St1} = new_fun_name("bc", St0),
  {Tname,St2} = new_var_name(St1),
  LA = lineno_anno(Line, St2),
  LAnno = #a{anno=LA},
  HeadBinPattern = pattern(P,St2),
  #c_binary{segments=Ps} = HeadBinPattern,
  {EPs,St3} = emasculate_semgments(Ps,St2),
  Tail = #c_var{anno=LA,name=Tname},
  TailSegment = #c_bitstr{val=Tail,size=core_lib:make_literal(all),
			  unit=core_lib:make_literal(1),
			  type=core_lib:make_literal(binary),
			  flags=core_lib:make_literal([big,unsigned])},
  Pattern = HeadBinPattern#c_binary{segments=Ps ++ [TailSegment]},
  EPattern = HeadBinPattern#c_binary{segments=EPs ++ [TailSegment]},
  {Arg,St4} = new_var(St3),
  {Guardc,St5} = lc_guard_tests(Gs, St4),	%These are always flat!
  NewMore = {call,Lg,{atom,Lg,Name},[{var,Lg,Tname}]},
  {Bc,Bps,St6} = bc_tq1(Line, E, Qs1, NewMore, St5),
  {Mc,Mps,St7} = expr(More, St6),
  {Gc,Gps,St10} = safe(G, St7),		%Will be a function argument!
  Fc = fail_clause([Arg], #c_tuple{anno=LA,
				   es=[#c_literal{val=function_clause},Arg]}),
  Cs = [#iclause{anno=#a{anno=[compiler_generated|LA]},
		 pats=[Pattern],
		 guard=Guardc,
		 body=Bps ++ [Bc]},
	#iclause{anno=#a{anno=[compiler_generated|LA]},
		 pats=[EPattern],
		 guard=[],
		 body=[#iapply{anno=LAnno,
			       op=#c_fname{anno=LA,id=Name,arity=1},
			       args=[Tail]}]},
	#iclause{anno=LAnno,
		 pats=[#c_binary{anno=LA, segments=[TailSegment]}],guard=[],
		 body=Mps ++ [Mc]}],
  Fun = #ifun{anno=LAnno,id=[],vars=[Arg],clauses=Cs,fc=Fc},
  {#iletrec{anno=LAnno,defs=[{Name,Fun}],
	    body=Gps ++ [#iapply{anno=LAnno,
				 op=#c_fname{anno=LA,id=Name,arity=1},
				 args=[Gc]}]},
   [],St10};
bc_tq1(Line, E, [Fil0|Qs0], More, St0) ->
    %% Special case sequences guard tests.
    LA = lineno_anno(Line, St0),
    LAnno = #a{anno=LA},
    case is_guard_test(Fil0) of
	true ->
	    {Gs0,Qs1} = splitwith(fun is_guard_test/1, Qs0),
	    {Bc,Bps,St1} = bc_tq1(Line, E, Qs1, More, St0),
	    {Mc,Mps,St2} = expr(More, St1),
	    {Gs,St3} = lc_guard_tests([Fil0|Gs0], St2), %These are always flat!
	    {#icase{anno=LAnno,
		    args=[],
		    clauses=[#iclause{anno=LAnno,pats=[],
				      guard=Gs,body=Bps ++ [Bc]}],
		    fc=#iclause{anno=LAnno,pats=[],guard=[],body=Mps ++ [Mc]}},
	     [],St3};
	false ->
	    {Bc,Bps,St1} = bc_tq1(Line, E, Qs0, More, St0),
	    {Mc,Mps,St2} = expr(More, St1),
	    {Fpat,St3} = new_var(St2),
	    Fc = fail_clause([Fpat], #c_tuple{es=[#c_literal{val=case_clause},Fpat]}),
	    %% Do a novars little optimisation here.
	    case Fil0 of
		{op,_,'not',Fil1} ->
		    {Filc,Fps,St4} = novars(Fil1, St3),
		    {#icase{anno=LAnno,
			    args=[Filc],
			    clauses=[#iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=true}],
					      guard=[],
					      body=Mps ++ [Mc]},
				     #iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=false}],
					      guard=[],
					      body=Bps ++ [Bc]}],
			    fc=Fc},
		     Fps,St4};
		_Other ->
		    {Filc,Fps,St4} = novars(Fil0, St3),
		    {#icase{anno=LAnno,
			    args=[Filc],
			    clauses=[#iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=true}],
					      guard=[],
					      body=Bps ++ [Bc]},
				     #iclause{anno=LAnno,
					      pats=[#c_literal{anno=LA,val=false}],
					      guard=[],
					      body=Mps ++ [Mc]}],
			    fc=Fc},
		     Fps,St4}
	    end
    end;
bc_tq1(Line, Bin = {bin,_Line,_Elements} , [], More, St) ->
  expr({cons,Line,Bin,More}, St).

emasculate_semgments(Segs,St) ->
  emasculate_semgments(Segs,St,[]).

emasculate_semgments([#c_bitstr{val=#c_var{}}=B|Rest],St,Acc) ->
  emasculate_semgments(Rest,St,[B|Acc]);
emasculate_semgments([B|Rest],St0,Acc) ->
  {Var,St1} = new_var(St0),
  emasculate_semgments(Rest,St1,[B#c_bitstr{val=Var}|Acc]);
emasculate_semgments([],St,Acc) ->
  {lists:reverse(Acc),St}.

lc_guard_tests([], St) -> {[],St};
lc_guard_tests(Gs0, St) ->
    Gs = guard_tests(Gs0),
    gexpr_top(Gs, St).

%% is_guard_test(Expression) -> true | false.
%%  Test if a general expression is a guard test.  Use erl_lint here
%%  as it now allows sys_pre_expand transformed source.

is_guard_test(E) -> erl_lint:is_guard_test(E).

%% novars(Expr, State) -> {Novars,[PreExpr],State}.
%%  Generate a novars expression, basically a call or a safe.  At this
%%  level we do not need to do a deep check.

novars(E0, St0) ->
    {E1,Eps,St1} = expr(E0, St0),
    {Se,Sps,St2} = force_novars(E1, St1),
    {Se,Eps ++ Sps,St2}.

force_novars(#iapply{}=App, St) -> {App,[],St};
force_novars(#icall{}=Call, St) -> {Call,[],St};
force_novars(#ifun{}=Fun, St) -> {Fun,[],St};	%These are novars too
force_novars(#ibinary{}=Bin, St) -> {Bin,[],St};
force_novars(Ce, St) ->
    force_safe(Ce, St).

%% safe(Expr, State) -> {Safe,[PreExpr],State}.
%%  Generate an internal safe expression.  These are simples without
%%  binaries which can fail.  At this level we do not need to do a
%%  deep check.  Must do special things with matches here.

safe(E0, St0) ->
    {E1,Eps,St1} = expr(E0, St0),
    {Se,Sps,St2} = force_safe(E1, St1),
    {Se,Eps ++ Sps,St2}.

safe_list(Es, St) ->
    foldr(fun (E, {Ces,Esp,St0}) ->
		  {Ce,Ep,St1} = safe(E, St0),
		  {[Ce|Ces],Ep ++ Esp,St1}
	  end, {[],[],St}, Es).

force_safe(#imatch{anno=Anno,pat=P,arg=E,fc=Fc}, St0) ->
    {Le,Lps,St1} = force_safe(E, St0),
    {Le,Lps ++ [#imatch{anno=Anno,pat=P,arg=Le,fc=Fc}],St1};
force_safe(Ce, St0) ->
    case is_safe(Ce) of
	true -> {Ce,[],St0};
	false ->
	    {V,St1} = new_var(St0),
	    {V,[#iset{var=V,arg=Ce}],St1}
    end.

is_safe(#c_cons{}) -> true;
is_safe(#c_tuple{}) -> true;
is_safe(#c_var{}) -> true;
is_safe(#c_literal{}) -> true;
is_safe(#c_fname{}) -> true;
is_safe(_) -> false.

%% fold_match(MatchExpr, Pat) -> {MatchPat,Expr}.
%%  Fold nested matches into one match with aliased patterns.

fold_match({match,L,P0,E0}, P) ->
    {P1,E1} = fold_match(E0, P),
    {{match,L,P0,P1},E1};
fold_match(E, P) -> {P,E}.

%% pattern(Pattern, State) -> CorePat.
%% Transform a pattern by removing line numbers.  We also normalise
%% aliases in patterns to standard form, {alias,Pat,[Var]}.

pattern({var,L,V}, St) -> #c_var{anno=lineno_anno(L, St),name=V};
pattern({char,L,C}, St) -> #c_literal{anno=lineno_anno(L, St),val=C};
pattern({integer,L,I}, St) -> #c_literal{anno=lineno_anno(L, St),val=I};
pattern({float,L,F}, St) -> #c_literal{anno=lineno_anno(L, St),val=F};
pattern({atom,L,A}, St) -> #c_literal{anno=lineno_anno(L, St),val=A};
pattern({string,L,S}, St) -> #c_literal{anno=lineno_anno(L, St),val=S};
pattern({nil,L}, St) -> #c_literal{anno=lineno_anno(L, St),val=[]};
pattern({cons,L,H,T}, St) ->
    #c_cons{anno=lineno_anno(L, St),hd=pattern(H, St),tl=pattern(T, St)};
pattern({tuple,L,Ps}, St) ->
    #c_tuple{anno=lineno_anno(L, St),es=pattern_list(Ps, St)};
pattern({bin,L,Ps}, St) ->
    %% We don't create a #ibinary record here, since there is
    %% no need to hold any used/new annoations in a pattern.
    #c_binary{anno=lineno_anno(L, St),segments=pat_bin(Ps, St)};
pattern({match,_,P1,P2}, St) ->
    pat_alias(pattern(P1, St), pattern(P2, St)).

%% pat_bin([BinElement], State) -> [BinSeg].

pat_bin(Ps, St) -> map(fun(P) -> pat_segment(P, St) end, Ps).

pat_segment({bin_element,_,Term,Size,[Type,{unit,Unit}|Flags]}, St) ->
    #c_bitstr{val=pattern(Term, St),size=pattern(Size, St),
	      unit=core_lib:make_literal(Unit),
	      type=core_lib:make_literal(Type),
	      flags=core_lib:make_literal(Flags)}.

%% pat_alias(CorePat, CorePat) -> AliasPat.
%%  Normalise aliases.  Trap bad aliases by throwing 'nomatch'.

pat_alias(#c_var{name=V1}, P2) -> #c_alias{var=#c_var{name=V1},pat=P2};
pat_alias(P1, #c_var{name=V2}) -> #c_alias{var=#c_var{name=V2},pat=P1};
pat_alias(#c_cons{}=Cons, #c_literal{anno=A,val=[H|T]}=S) ->
    pat_alias(Cons, #c_cons{anno=A,hd=#c_literal{anno=A,val=H},
			    tl=S#c_literal{val=T}});
pat_alias(#c_literal{anno=A,val=[H|T]}=S, #c_cons{}=Cons) ->
    pat_alias(#c_cons{anno=A,hd=#c_literal{anno=A,val=H},
		      tl=S#c_literal{val=T}}, Cons);
pat_alias(#c_cons{anno=A,hd=H1,tl=T1}, #c_cons{hd=H2,tl=T2}) ->
    #c_cons{anno=A,hd=pat_alias(H1, H2),tl=pat_alias(T1, T2)};
pat_alias(#c_tuple{es=Es1}, #c_tuple{es=Es2}) ->
    #c_tuple{es=pat_alias_list(Es1, Es2)};
pat_alias(#c_binary{segments=Segs1}=Bin, #c_binary{segments=Segs2}) ->
    Bin#c_binary{segments=pat_alias_list(Segs1, Segs2)};
pat_alias(#c_bitstr{val=P1,size=Sz,unit=U,type=T,flags=F}=Bitstr,
	  #c_bitstr{val=P2,size=Sz,unit=U,type=T,flags=F}) ->
    Bitstr#c_bitstr{val=pat_alias(P1, P2)};
pat_alias(#c_alias{var=V1,pat=P1},
	   #c_alias{var=V2,pat=P2}) ->
    if V1 =:= V2 -> pat_alias(P1, P2);
       true -> #c_alias{var=V1,pat=#c_alias{var=V2,pat=pat_alias(P1, P2)}}
    end;
pat_alias(#c_alias{var=V1,pat=P1}, P2) ->
    #c_alias{var=V1,pat=pat_alias(P1, P2)};
pat_alias(P1, #c_alias{var=V2,pat=P2}) ->
    #c_alias{var=V2,pat=pat_alias(P1, P2)};
pat_alias(P1, P2) ->
    case {core_lib:set_anno(P1, []),core_lib:set_anno(P2, [])} of
	{P,P} -> P;
	_ -> throw(nomatch)
    end.

%% pat_alias_list([A1], [A2]) -> [A].

pat_alias_list([A1|A1s], [A2|A2s]) ->
    [pat_alias(A1, A2)|pat_alias_list(A1s, A2s)];
pat_alias_list([], []) -> [];
pat_alias_list(_, _) -> throw(nomatch).

%% pattern_list([P], State) -> [P].

pattern_list(Ps, St) -> map(fun(P) -> pattern(P, St) end, Ps).

%% first([A]) -> [A].
%% last([A]) -> A.

first([_]) -> [];
first([H|T]) -> [H|first(T)].

last([L]) -> L;
last([_|T]) -> last(T).

%% make_vars([Name]) -> [{Var,Name}].

make_vars(Vs) -> [ #c_var{name=V} || V <- Vs ].

%% new_fun_name(Type, State) -> {FunName,State}.

new_fun_name(Type, #core{fcount=C}=St) ->
    {list_to_atom(Type ++ "$^" ++ integer_to_list(C)),St#core{fcount=C+1}}.

%% new_var_name(State) -> {VarName,State}.

new_var_name(#core{vcount=C}=St) ->
    {list_to_atom("cor" ++ integer_to_list(C)),St#core{vcount=C + 1}}.

%% new_var(State) -> {{var,Name},State}.
%% new_var(LineAnno, State) -> {{var,Name},State}.

new_var(St) ->
    new_var([], St).

new_var(Anno, St0) ->
    {New,St} = new_var_name(St0),
    {#c_var{anno=Anno,name=New},St}.

%% new_vars(Count, State) -> {[Var],State}.
%% new_vars(Anno, Count, State) -> {[Var],State}.
%%  Make Count new variables.

new_vars(N, St) -> new_vars_1(N, [], St, []).
new_vars(Anno, N, St) -> new_vars_1(N, Anno, St, []).

new_vars_1(N, Anno, St0, Vs) when N > 0 ->
    {V,St1} = new_var(Anno, St0),
    new_vars_1(N-1, Anno, St1, [V|Vs]);
new_vars_1(0, _, St, Vs) -> {Vs,St}.

fail_clause(Pats, A) ->
    #iclause{anno=#a{anno=[compiler_generated]},
	     pats=Pats,guard=[],
	     body=[#iprimop{anno=#a{},name=#c_literal{val=match_fail},args=[A]}]}.

ubody(B, St) -> uexpr(B, [], St).

%% uclauses([Lclause], [KnownVar], State) -> {[Lclause],State}.

uclauses(Lcs, Ks, St0) ->
    mapfoldl(fun (Lc, St) -> uclause(Lc, Ks, St) end, St0, Lcs).

%% uclause(Lclause, [KnownVar], State) -> {Lclause,State}.

uclause(Cl0, Ks, St0) ->
    {Cl1,_Pvs,Used,New,St1} = uclause(Cl0, Ks, Ks, St0),
    A0 = get_ianno(Cl1),
    A = A0#a{us=Used,ns=New},
    {Cl1#iclause{anno=A},St1}.

uclause(#iclause{anno=Anno,pats=Ps0,guard=G0,body=B0}, Pks, Ks0, St0) ->
    {Ps1,Pg,Pvs,Pus,St1} = upattern_list(Ps0, Pks, St0),
    Pu = union(Pus, intersection(Pvs, Ks0)),
    Pn = subtract(Pvs, Pu),
    Ks1 = union(Pn, Ks0),
    {G1,St2} = uguard(Pg, G0, Ks1, St1),
    Gu = used_in_any(G1),
    Gn = new_in_any(G1),
    Ks2 = union(Gn, Ks1),
    {B1,St3} = uexprs(B0, Ks2, St2),
    Used = intersection(union([Pu,Gu,used_in_any(B1)]), Ks0),
    New = union([Pn,Gn,new_in_any(B1)]),
    {#iclause{anno=Anno,pats=Ps1,guard=G1,body=B1},Pvs,Used,New,St3}.

%% uguard([Test], [Kexpr], [KnownVar], State) -> {[Kexpr],State}.
%%  Build a guard expression list by folding in the equality tests.

uguard([], [], _, St) -> {[],St};
uguard(Pg, [], Ks, St) ->
    %% No guard, so fold together equality tests.
    uguard(first(Pg), [last(Pg)], Ks, St);
uguard(Pg, Gs0, Ks, St0) ->
    %% Gs0 must contain at least one element here.
    {Gs3,St5} = foldr(fun (T, {Gs1,St1}) ->
			      {L,St2} = new_var(St1),
			      {R,St3} = new_var(St2),
			      {[#iset{var=L,arg=T}] ++ first(Gs1) ++
			       [#iset{var=R,arg=last(Gs1)},
				#icall{anno=#a{}, %Must have an #a{}
				       module=#c_literal{val=erlang},
				       name=#c_literal{val='and'},
				       args=[L,R]}],
			       St3}
		      end, {Gs0,St0}, Pg),
    %%ok = io:fwrite("core ~w: ~p~n", [?LINE,Gs3]),
    uexprs(Gs3, Ks, St5).

%% uexprs([Kexpr], [KnownVar], State) -> {[Kexpr],State}.

uexprs([#imatch{anno=A,pat=P0,arg=Arg,fc=Fc}|Les], Ks, St0) ->
    %% Optimise for simple set of unbound variable.
    case upattern(P0, Ks, St0) of
	{#c_var{},[],_Pvs,_Pus,_} ->
	    %% Throw our work away and just set to iset.
	    uexprs([#iset{var=P0,arg=Arg}|Les], Ks, St0);
	_Other ->
	    %% Throw our work away and set to icase.
	    if
		Les =:= [] ->
		    %% Need to explicitly return match "value", make
		    %% safe for efficiency.
		    {La,Lps,St1} = force_safe(Arg, St0),
		    Mc = #iclause{anno=A,pats=[P0],guard=[],body=[La]},
		    uexprs(Lps ++ [#icase{anno=A,
					  args=[La],clauses=[Mc],fc=Fc}], Ks, St1);
		true ->
		    Mc = #iclause{anno=A,pats=[P0],guard=[],body=Les},
		    uexprs([#icase{anno=A,args=[Arg],
				   clauses=[Mc],fc=Fc}], Ks, St0)
	    end
    end;
uexprs([Le0|Les0], Ks, St0) ->
    {Le1,St1} = uexpr(Le0, Ks, St0),
    {Les1,St2} = uexprs(Les0, union((core_lib:get_anno(Le1))#a.ns, Ks), St1),
    {[Le1|Les1],St2};
uexprs([], _, St) -> {[],St}.

uexpr(#iset{anno=A,var=V,arg=A0}, Ks, St0) ->
    {A1,St1} = uexpr(A0, Ks, St0),
    {#iset{anno=A#a{us=del_element(V#c_var.name, (core_lib:get_anno(A1))#a.us),
		    ns=add_element(V#c_var.name, (core_lib:get_anno(A1))#a.ns)},
	   var=V,arg=A1},St1};
%% imatch done in uexprs.
uexpr(#iletrec{anno=A,defs=Fs0,body=B0}, Ks, St0) ->
    %%ok = io:fwrite("~w: ~p~n", [?LINE,{Fs0,B0}]),
    {Fs1,St1} = mapfoldl(fun ({Name,F0}, S0) ->
				 {F1,S1} = uexpr(F0, Ks, S0),
				 {{Name,F1},S1}
			 end, St0, Fs0),
    {B1,St2} = uexprs(B0, Ks, St1),
    Used = used_in_any(map(fun ({_,F}) -> F end, Fs1) ++ B1),
    {#iletrec{anno=A#a{us=Used,ns=[]},defs=Fs1,body=B1},St2};
uexpr(#icase{anno=A,args=As0,clauses=Cs0,fc=Fc0}, Ks, St0) ->
    %% As0 will never generate new variables.
    {As1,St1} = uexpr_list(As0, Ks, St0),
    {Cs1,St2} = uclauses(Cs0, Ks, St1),
    {Fc1,St3} = uclause(Fc0, Ks, St2),
    Used = union(used_in_any(As1), used_in_any(Cs1)),
    New = new_in_all(Cs1),
    {#icase{anno=A#a{us=Used,ns=New},args=As1,clauses=Cs1,fc=Fc1},St3};
uexpr(#ifun{anno=A,id=Id,vars=As,clauses=Cs0,fc=Fc0}, Ks0, St0) ->
    Avs = lit_list_vars(As),
    Ks1 = union(Avs, Ks0),
    {Cs1,St1} = ufun_clauses(Cs0, Ks1, St0),
    {Fc1,St2} = ufun_clause(Fc0, Ks1, St1),
    Used = subtract(intersection(used_in_any(Cs1), Ks0), Avs),
    {#ifun{anno=A#a{us=Used,ns=[]},id=Id,vars=As,clauses=Cs1,fc=Fc1},St2};
uexpr(#iapply{anno=A,op=Op,args=As}, _, St) ->
    Used = union(lit_vars(Op), lit_list_vars(As)),
    {#iapply{anno=A#a{us=Used},op=Op,args=As},St};
uexpr(#iprimop{anno=A,name=Name,args=As}, _, St) ->
    Used = lit_list_vars(As),
    {#iprimop{anno=A#a{us=Used},name=Name,args=As},St};
uexpr(#icall{anno=A,module=Mod,name=Name,args=As}, _, St) ->
    Used = union([lit_vars(Mod),lit_vars(Name),lit_list_vars(As)]),
    {#icall{anno=A#a{us=Used},module=Mod,name=Name,args=As},St};
uexpr(#itry{anno=A,args=As0,vars=Vs,body=Bs0,evars=Evs,handler=Hs0}, Ks, St0) ->
    %% Note that we export only from body and exception.
    {As1,St1} = uexprs(As0, Ks, St0),
    {Bs1,St2} = uexprs(Bs0, Ks, St1),
    {Hs1,St3} = uexprs(Hs0, Ks, St2),
    Used = intersection(used_in_any(Bs1++Hs1++As1), Ks),
    New = new_in_all(Bs1++Hs1),
    {#itry{anno=A#a{us=Used,ns=New},
	   args=As1,vars=Vs,body=Bs1,evars=Evs,handler=Hs1},St3};
uexpr(#icatch{anno=A,body=Es0}, Ks, St0) ->
    {Es1,St1} = uexprs(Es0, Ks, St0),
    {#icatch{anno=A#a{us=used_in_any(Es1)},body=Es1},St1};
uexpr(#ireceive1{anno=A,clauses=Cs0}, Ks, St0) ->
    {Cs1,St1} = uclauses(Cs0, Ks, St0),
    {#ireceive1{anno=A#a{us=used_in_any(Cs1),ns=new_in_all(Cs1)},
		clauses=Cs1},St1};
uexpr(#ireceive2{anno=A,clauses=Cs0,timeout=Te0,action=Tes0}, Ks, St0) ->
    %% Te0 will never generate new variables.
    {Te1,St1} = uexpr(Te0, Ks, St0),
    {Cs1,St2} = uclauses(Cs0, Ks, St1),
    {Tes1,St3} = uexprs(Tes0, Ks, St2),
    Used = union([used_in_any(Cs1),used_in_any(Tes1),
		  (core_lib:get_anno(Te1))#a.us]),
    New = case Cs1 of
	      [] -> new_in_any(Tes1);
	      _ -> intersection(new_in_all(Cs1), new_in_any(Tes1))
	  end,
    {#ireceive2{anno=A#a{us=Used,ns=New},
		clauses=Cs1,timeout=Te1,action=Tes1},St3};
uexpr(#iprotect{anno=A,body=Es0}, Ks, St0) ->
    {Es1,St1} = uexprs(Es0, Ks, St0),
    Used = used_in_any(Es1),
    {#iprotect{anno=A#a{us=Used},body=Es1},St1}; %No new variables escape!
uexpr(#ibinary{anno=A,segments=Ss}, _, St) ->
    Used = bitstr_vars(Ss),
    {#ibinary{anno=A#a{us=Used},segments=Ss},St};
uexpr(#c_literal{}=Lit, _, St) ->
    Anno = core_lib:get_anno(Lit),
    {core_lib:set_anno(Lit, #a{us=[],anno=Anno}),St};
uexpr(Lit, _, St) ->
    case core_lib:is_simple(Lit) of
	false ->
	    io:format("~p\n", [Lit]);
	true ->
	    ok
    end,
    true = core_lib:is_simple(Lit),		%Sanity check!
    Vs = lit_vars(Lit),
    Anno = core_lib:get_anno(Lit),
    {core_lib:set_anno(Lit, #a{us=Vs,anno=Anno}),St}.

uexpr_list(Les0, Ks, St0) ->
    mapfoldl(fun (Le, St) -> uexpr(Le, Ks, St) end, St0, Les0).

%% ufun_clauses([Lclause], [KnownVar], State) -> {[Lclause],State}.

ufun_clauses(Lcs, Ks, St0) ->
    mapfoldl(fun (Lc, St) -> ufun_clause(Lc, Ks, St) end, St0, Lcs).

%% ufun_clause(Lclause, [KnownVar], State) -> {Lclause,State}.

ufun_clause(Cl0, Ks, St0) ->
    {Cl1,Pvs,Used,_,St1} = uclause(Cl0, [], Ks, St0),
    A0 = get_ianno(Cl1),
    A = A0#a{us=subtract(intersection(Used, Ks), Pvs),ns=[]},
    {Cl1#iclause{anno=A},St1}.

%% upattern(Pat, [KnownVar], State) ->
%%              {Pat,[GuardTest],[NewVar],[UsedVar],State}.

upattern(#c_var{name='_'}, _, St0) ->
    {New,St1} = new_var_name(St0),
    {#c_var{name=New},[],[New],[],St1};
upattern(#c_var{name=V}=Var, Ks, St0) ->
    case is_element(V, Ks) of
	true ->
	    {N,St1} = new_var_name(St0),
	    New = #c_var{name=N},
	    Test = #icall{anno=#a{us=add_element(N, [V])},
			  module=#c_literal{val=erlang},
			  name=#c_literal{val='=:='},
			  args=[New,Var]},
	    %% Test doesn't need protecting.
	    {New,[Test],[N],[],St1};
	false -> {Var,[],[V],[],St0}
    end;
upattern(#c_cons{hd=H0,tl=T0}=Cons, Ks, St0) ->
    {H1,Hg,Hv,Hu,St1} = upattern(H0, Ks, St0),
    {T1,Tg,Tv,Tu,St2} = upattern(T0, union(Hv, Ks), St1),
    {Cons#c_cons{hd=H1,tl=T1},Hg ++ Tg,union(Hv, Tv),union(Hu, Tu),St2};
upattern(#c_tuple{es=Es0}=Tuple, Ks, St0) ->
    {Es1,Esg,Esv,Eus,St1} = upattern_list(Es0, Ks, St0),
    {Tuple#c_tuple{es=Es1},Esg,Esv,Eus,St1};
upattern(#c_binary{segments=Es0}=Bin, Ks, St0) ->
    {Es1,Esg,Esv,Eus,St1} = upat_bin(Es0, Ks, St0),
    {Bin#c_binary{segments=Es1},Esg,Esv,Eus,St1};
upattern(#c_alias{var=V0,pat=P0}=Alias, Ks, St0) ->
    {V1,Vg,Vv,Vu,St1} = upattern(V0, Ks, St0),
    {P1,Pg,Pv,Pu,St2} = upattern(P0, union(Vv, Ks), St1),
    {Alias#c_alias{var=V1,pat=P1},Vg ++ Pg,union(Vv, Pv),union(Vu, Pu),St2};
upattern(Other, _, St) -> {Other,[],[],[],St}.	%Constants

%% upattern_list([Pat], [KnownVar], State) ->
%%                        {[Pat],[GuardTest],[NewVar],[UsedVar],State}.

upattern_list([P0|Ps0], Ks, St0) ->
    {P1,Pg,Pv,Pu,St1} = upattern(P0, Ks, St0),
    {Ps1,Psg,Psv,Psu,St2} = upattern_list(Ps0, union(Pv, Ks), St1),
    {[P1|Ps1],Pg ++ Psg,union(Pv, Psv),union(Pu, Psu),St2};
upattern_list([], _, St) -> {[],[],[],[],St}.    

%% upat_bin([Pat], [KnownVar], State) ->
%%                        {[Pat],[GuardTest],[NewVar],[UsedVar],State}.
upat_bin(Es0, Ks, St0) ->
  upat_bin(Es0, Ks, [], St0).

%% upat_bin([Pat], [KnownVar], [LocalVar], State) ->
%%                        {[Pat],[GuardTest],[NewVar],[UsedVar],State}.
upat_bin([P0|Ps0], Ks, Bs, St0) ->
    {P1,Pg,Pv,Pu,Bs1,St1} = upat_element(P0, Ks, Bs, St0),
    {Ps1,Psg,Psv,Psu,St2} = upat_bin(Ps0, union(Pv, Ks), Bs1, St1),
    {[P1|Ps1],Pg ++ Psg,union(Pv, Psv),union(Pu, Psu),St2};
upat_bin([], _, _, St) -> {[],[],[],[],St}.    


%% upat_element(Segment, [KnownVar], [LocalVar], State) ->
%%                        {Segment,[GuardTest],[NewVar],[UsedVar],[LocalVar],State}
upat_element(#c_bitstr{val=H0,size=Sz}=Seg, Ks, Bs, St0) ->
  {H1,Hg,Hv,[],St1} = upattern(H0, Ks, St0),
  Bs1 = case H0 of
	  #c_var{name=Hname} ->
	    case H1 of
	      #c_var{name=Hname} ->
		Bs;
	      #c_var{name=Other} ->
		[{Hname, Other}|Bs]
	    end;
	  _ ->
	    Bs
	end,
  {Sz1, Us} = case Sz of
		  #c_var{name=Vname} -> 
		    rename_bitstr_size(Vname, Bs);
		  _Other -> {Sz, []}
		end,
  {Seg#c_bitstr{val=H1, size=Sz1},Hg,Hv,Us,Bs1,St1}.

rename_bitstr_size(V, [{V, N}|_]) ->
   New = #c_var{name=N},
  {New, [N]};
rename_bitstr_size(V, [_|Rest]) ->
  rename_bitstr_size(V, Rest);
rename_bitstr_size(V, []) ->
  Old = #c_var{name=V},
  {Old, [V]}.
 
used_in_any(Les) ->
    foldl(fun (Le, Ns) -> union((core_lib:get_anno(Le))#a.us, Ns) end,
	  [], Les).

new_in_any(Les) ->
    foldl(fun (Le, Ns) -> union((core_lib:get_anno(Le))#a.ns, Ns) end,
	  [], Les).

new_in_all([Le|Les]) ->
    foldl(fun (L, Ns) -> intersection((core_lib:get_anno(L))#a.ns, Ns) end,
	  (core_lib:get_anno(Le))#a.ns, Les);
new_in_all([]) -> [].

%% The AfterVars are the variables which are used afterwards.  We need
%% this to work out which variables are actually exported and used
%% from case/receive.  In subblocks/clauses the AfterVars of the block
%% are just the exported variables.

cbody(B0, St0) ->
    {B1,_,_,St1} = cexpr(B0, [], St0),
    {B1,St1}.

%% cclause(Lclause, [AfterVar], State) -> {Cclause,State}.
%%  The AfterVars are the exported variables.

cclause(#iclause{anno=#a{anno=Anno},pats=Ps,guard=G0,body=B0}, Exp, St0) ->
    {B1,_Us1,St1} = cexprs(B0, Exp, St0),
    {G1,St2} = cguard(G0, St1),
    {#c_clause{anno=Anno,pats=Ps,guard=G1,body=B1},St2}.

cclauses(Lcs, Es, St0) ->
    mapfoldl(fun (Lc, St) -> cclause(Lc, Es, St) end, St0, Lcs).

cguard([], St) -> {#c_literal{val=true},St};
cguard(Gs, St0) ->
    {G,_,St1} = cexprs(Gs, [], St0),
    {G,St1}.
 
%% cexprs([Lexpr], [AfterVar], State) -> {Cexpr,[AfterVar],State}.
%%  Must be sneaky here at the last expr when combining exports for the
%%  whole sequence and exports for that expr.

cexprs([#iset{var=#c_var{name=Name}=Var}=Iset], As, St) ->
    %% Make return value explicit, and make Var true top level.
    cexprs([Iset,Var#c_var{anno=#a{us=[Name]}}], As, St);
cexprs([Le], As, St0) ->
    {Ce,Es,Us,St1} = cexpr(Le, As, St0),
    Exp = make_vars(As),			%The export variables
    if
	Es =:= [] -> {core_lib:make_values([Ce|Exp]),union(Us, As),St1};
	true ->
	    {R,St2} = new_var(St1),
	    {#c_let{anno=get_lineno_anno(Ce),
		    vars=[R|make_vars(Es)],arg=Ce,
		    body=core_lib:make_values([R|Exp])},
	     union(Us, As),St2}
    end;
cexprs([#iset{anno=#a{anno=A},var=V,arg=A0}|Les], As0, St0) ->
    {Ces,As1,St1} = cexprs(Les, As0, St0),
    {A1,Es,Us,St2} = cexpr(A0, As1, St1),
    {#c_let{anno=A,vars=[V|make_vars(Es)],arg=A1,body=Ces},
     union(Us, As1),St2};
cexprs([Le|Les], As0, St0) ->
    {Ces,As1,St1} = cexprs(Les, As0, St0),
    {Ce,Es,Us,St2} = cexpr(Le, As1, St1),
    if
	Es =:= [] ->
	    {#c_seq{arg=Ce,body=Ces},union(Us, As1),St2};
	true ->
	    {R,St3} = new_var(St2),
	    {#c_let{vars=[R|make_vars(Es)],arg=Ce,body=Ces},
	     union(Us, As1),St3}
    end.

%% cexpr(Lexpr, [AfterVar], State) -> {Cexpr,[ExpVar],[UsedVar],State}.

cexpr(#iletrec{anno=A,defs=Fs0,body=B0}, As, St0) ->
    {Fs1,{_,St1}} = mapfoldl(fun ({Name,F0}, {Used,S0}) ->
				     {F1,[],Us,S1} = cexpr(F0, [], S0),
				     {{#c_fname{id=Name,arity=1},F1},
				      {union(Us, Used),S1}}
			     end, {[],St0}, Fs0),
    Exp = intersection(A#a.ns, As),
    {B1,_Us,St2} = cexprs(B0, Exp, St1),
    {#c_letrec{anno=A#a.anno,defs=Fs1,body=B1},Exp,A#a.us,St2};
cexpr(#icase{anno=A,args=Largs,clauses=Lcs,fc=Lfc}, As, St0) ->
    Exp = intersection(A#a.ns, As),		%Exports
    {Cargs,St1} = foldr(fun (La, {Cas,Sta}) ->
				{Ca,[],_Us1,Stb} = cexpr(La, As, Sta),
				{[Ca|Cas],Stb}
			end, {[],St0}, Largs),
    {Ccs,St2} = cclauses(Lcs, Exp, St1),
    {Cfc,St3} = cclause(Lfc, [], St2),		%Never exports
    {#c_case{anno=A#a.anno,
	     arg=core_lib:make_values(Cargs),clauses=Ccs ++ [Cfc]},
     Exp,A#a.us,St3};
cexpr(#ireceive1{anno=A,clauses=Lcs}, As, St0) ->
    Exp = intersection(A#a.ns, As),		%Exports
    {Ccs,St1} = cclauses(Lcs, Exp, St0),
    {#c_receive{anno=A#a.anno,
		clauses=Ccs,
	       timeout=#c_literal{val=infinity},action=#c_literal{val=true}},
     Exp,A#a.us,St1};
cexpr(#ireceive2{anno=A,clauses=Lcs,timeout=Lto,action=Les}, As, St0) ->
    Exp = intersection(A#a.ns, As),		%Exports
    {Cto,[],_Us1,St1} = cexpr(Lto, As, St0),
    {Ccs,St2} = cclauses(Lcs, Exp, St1),
    {Ces,_Us2,St3} = cexprs(Les, Exp, St2),
    {#c_receive{anno=A#a.anno,
		clauses=Ccs,timeout=Cto,action=Ces},
     Exp,A#a.us,St3};
cexpr(#itry{anno=A,args=La,vars=Vs,body=Lb,evars=Evs,handler=Lh}, As, St0) ->
    Exp = intersection(A#a.ns, As),           %Exports
    {Ca,_Us1,St1} = cexprs(La, [], St0),
    {Cb,_Us2,St2} = cexprs(Lb, Exp, St1),
    {Ch,_Us3,St3} = cexprs(Lh, Exp, St2),
    {#c_try{anno=A#a.anno,arg=Ca,vars=Vs,body=Cb,evars=Evs,handler=Ch},
     Exp,A#a.us,St3};
cexpr(#icatch{anno=A,body=Les}, _As, St0) ->
    {Ces,_Us1,St1} = cexprs(Les, [], St0),	%Never export!
    {#c_catch{body=Ces},[],A#a.us,St1};
cexpr(#ifun{anno=A,id=Id,vars=Args,clauses=Lcs,fc=Lfc}, _As, St0) ->
    {Ccs,St1} = cclauses(Lcs, [], St0),		%NEVER export!
    {Cfc,St2} = cclause(Lfc, [], St1),
    Anno = A#a.anno,
    {#c_fun{anno=Id++Anno,vars=Args,
	    body=#c_case{anno=Anno,
			 arg=core_lib:set_anno(core_lib:make_values(Args), Anno),
			 clauses=Ccs ++ [Cfc]}},
     [],A#a.us,St2};
cexpr(#iapply{anno=A,op=Op,args=Args}, _As, St) ->
    {#c_apply{anno=A#a.anno,op=Op,args=Args},[],A#a.us,St};
cexpr(#icall{anno=A,module=Mod,name=Name,args=Args}, _As, St) ->
    {#c_call{anno=A#a.anno,module=Mod,name=Name,args=Args},[],A#a.us,St};
cexpr(#iprimop{anno=A,name=Name,args=Args}, _As, St) ->
    {#c_primop{anno=A#a.anno,name=Name,args=Args},[],A#a.us,St};
cexpr(#iprotect{anno=A,body=Es}, _As, St0) ->
    {Ce,_,St1} = cexprs(Es, [], St0),
    V = #c_var{name='Try'},		%The names are arbitrary
    Vs = [#c_var{name='T'},#c_var{name='R'}],
    {#c_try{anno=A#a.anno,arg=Ce,vars=[V],body=V,
	    evars=Vs,handler=#c_literal{val=false}},
     [],A#a.us,St1};
cexpr(#ibinary{anno=#a{anno=Anno,us=Us},segments=Segs}, _As, St) ->
    {#c_binary{anno=Anno,segments=Segs},[],Us,St};
cexpr(#c_literal{}=Lit, _As, St) ->
    Anno = core_lib:get_anno(Lit),
    Vs = Anno#a.us,
    {core_lib:set_anno(Lit, Anno#a.anno),[],Vs,St};
cexpr(Lit, _As, St) ->
    true = core_lib:is_simple(Lit),		%Sanity check!
    Anno = core_lib:get_anno(Lit),
    Vs = Anno#a.us,
    %%Vs = lit_vars(Lit),
    {core_lib:set_anno(Lit, Anno#a.anno),[],Vs,St}.

%% Kill the id annotations for any fun inside the expression.
%% Necessary when duplicating code in try ... after.

kill_id_anns(#ifun{clauses=Cs0}=Fun) ->
    Cs = kill_id_anns(Cs0),
    Fun#ifun{clauses=Cs,id=[]};
kill_id_anns(#a{}=A) ->
    %% Optimization: Don't waste time searching for funs inside annotations.
    A;
kill_id_anns([H|T]) ->
    [kill_id_anns(H)|kill_id_anns(T)];
kill_id_anns([]) -> [];
kill_id_anns(Tuple) when is_tuple(Tuple) ->
    L0 = tuple_to_list(Tuple),
    L = kill_id_anns(L0),
    list_to_tuple(L);
kill_id_anns(Other) -> Other.

%% lit_vars(Literal) -> [Var].

lit_vars(Lit) -> lit_vars(Lit, []).

lit_vars(#c_cons{hd=H,tl=T}, Vs) -> lit_vars(H, lit_vars(T, Vs));
lit_vars(#c_tuple{es=Es}, Vs) -> lit_list_vars(Es, Vs);
lit_vars(#c_var{name=V}, Vs) -> add_element(V, Vs); 
lit_vars(_, Vs) -> Vs.				%These are atomic

% lit_bin_vars(Segs, Vs) ->
%     foldl(fun (#c_bitstr{val=V,size=S}, Vs0) ->
% 		  lit_vars(V, lit_vars(S, Vs0))
% 	  end, Vs, Segs).

lit_list_vars(Ls) -> lit_list_vars(Ls, []).

lit_list_vars(Ls, Vs) ->
    foldl(fun (L, Vs0) -> lit_vars(L, Vs0) end, Vs, Ls).

bitstr_vars(Segs) ->
    bitstr_vars(Segs, []).

bitstr_vars(Segs, Vs) ->
    foldl(fun (#c_bitstr{val=V,size=S}, Vs0) ->
 		  lit_vars(V, lit_vars(S, Vs0))
	  end, Vs, Segs).

lineno_anno(L, St) when is_integer(L) ->
    [L] ++ St#core.file.

get_ianno(Ce) ->
    case core_lib:get_anno(Ce) of
	#a{}=A -> A;
	A when is_list(A) -> #a{anno=A}
    end.

get_lineno_anno(Ce) ->
    case core_lib:get_anno(Ce) of
	#a{anno=A} -> A;
	A when is_list(A) -> A
    end.



%%%
%%% Handling of warnings.
%%%

format_error(nomatch) ->
    "pattern cannot possibly match";
format_error(bad_binary) ->
    "binary construction will fail because of a type mismatch".

add_warning(Line, Term, #core{ws=Ws,file=[{file,File}]}=St) when Line >= 0 ->
    St#core{ws=[{File,[{Line,?MODULE,Term}]}|Ws]};
add_warning(_, _, St) -> St.
