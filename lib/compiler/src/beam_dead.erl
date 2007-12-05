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
%% Portions created by Ericsson are Copyright 2002, Ericsson AB.
%% All Rights Reserved.''
%% 
%%     $Id$
%%

-module(beam_dead).

-export([module/2]).

%%% The following optimisations are done:
%%%
%%% (1) In this code
%%%
%%%     	move DeadValue {x,0}
%%%     	jump L2
%%%        .
%%%        .
%%%        .
%%%     L2:	move Anything {x,0}
%%%        .
%%%        .
%%%        .
%%%
%%%     the first assignment to {x,0} has no effect (is dead),
%%%     so it can be removed. Besides removing a move instruction,
%%%     if the move was preceeded by a label, the resulting code
%%%	will look this
%%%
%%%     L1:	jump L2
%%%        .
%%%        .
%%%        .
%%%     L2:	move Anything {x,0}
%%%        .
%%%        .
%%%        .
%%%
%%%	which can be further optimized by the jump optimizer (beam_jump).
%%%
%%% (2) In this code
%%%
%%%     L1:	move AtomLiteral {x,0}
%%%     	jump L2
%%%        .
%%%        .
%%%        .
%%%     L2:	test is_atom FailLabel {x,0}
%%%    		select_val {x,0}, FailLabel [... AtomLiteral => L3...]
%%%        .
%%%        .
%%%        .
%%%	L3:	...
%%%
%%%     FailLabel: ...
%%%
%%%	the first code fragment can be changed to
%%%
%%%     L1:	move AtomLiteral {x,0}
%%%     	jump L3
%%%
%%%     If the literal is not included in the table of literals in the
%%%     select_val instruction, the first code fragment will instead be
%%%     rewritten as:
%%%
%%%     L1:	move AtomLiteral {x,0}
%%%     	jump FailLabel
%%%
%%%	The move instruction will be removed by optimization (1) above,
%%%	if the code following the L3 label overwrites {x,0}.
%%%
%%% 	The code following the L2 label will be kept, but it will be removed later
%%%	by the jump optimizer.
%%%
%%% (3) In this code
%%%
%%%     	test is_eq_exact ALabel Src Dst
%%%     	move Src Dst
%%%
%%%	the move instruction can be removed.
%%%     Same thing for
%%%
%%%     	test is_nil ALabel Dst
%%%     	move [] Dst
%%%
%%%
%%% (4) In this code
%%%
%%%    		select_val {x,Reg}, ALabel [... Literal => L1...]
%%%        .
%%%        .
%%%        .
%%%	L1:	move Literal {x,Reg}
%%%
%%%     we can remove the move instruction.
%%%
%%% (5) In the following code
%%%
%%%     	bif '=:=' Fail Src1 Src2 {x,0}
%%%    		jump L1
%%%	   .
%%%	   .
%%%	   .
%%%        L1:	select_val {x,0}, ALabel [... true => L2..., ...false => L3...]
%%%	   .
%%%	   .
%%%	   .
%%%        L2: ....      L3: ....
%%%
%%%  the first two instructions can be replaced with
%%%
%%%		test is_eq_exact L3 Src1 Src2
%%%		jump L2
%%%
%%%  provided that {x,0} is killed at both L2 and L3.
%%%
%%% (6) Remove redundant is_boolean such as the one in
%%%
%%%		test is_eq_exact Fail Reg true
%%%		test is_boolean Fail Reg
%%%
%%%	The following sequence
%%%
%%%		test is_ne_eq_exact Fail Reg true
%%%		test is_boolean Fail Reg
%%%
%%%	can be rewritten to
%%%
%%%		test is_eq_exact Fail Reg false
%%%
%%%	(The idea is that both tests end up in the same place if they fail,
%%%	and that the is_boolean test never can fail if the first test succeeds;
%%%	therefore the is_boolean test is redundant.)
%%%

-import(lists, [map/2,mapfoldl/3,reverse/1,reverse/2,keysearch/3,foreach/2]).

module({Mod,Exp,Attr,Fs0,_}, _Opts) ->
    Fs1 = map(fun split_blocks/1, Fs0),
    {Fs2,Lc1} = beam_clean:clean_labels(Fs1),
    {Fs,Lc} = mapfoldl(fun function/2, Lc1, Fs2),
    %%{Fs,Lc} = {Fs2,Lc1},
    {ok,{Mod,Exp,Attr,Fs,Lc}}.

function({function,Name,Arity,CLabel,Is0}, Lc0) ->
    Is1 = beam_jump:remove_unused_labels(Is0),
    Is2 = bopt(Is1),

    %% Optimize away dead code.
    {Is3,Lc} = forward(Is2, Lc0),
    Is4 = backward(Is3),
    Is = move_move_into_block(Is4, []),
    {{function,Name,Arity,CLabel,Is},Lc}.

%%%
%%% Remove redundant is_boolean tests.
%%%

bopt(Is) ->
    bopt_1(Is, []).

bopt_1([{test,is_boolean,_,_}=I|Is], Acc0) ->
    case opt_is_bool(I, Acc0) of
	no -> bopt_1(Is, [I|Acc0]);
	yes -> bopt_1(Is, Acc0);
	{yes,Acc} -> bopt_1(Is, Acc)
    end;
bopt_1([I|Is], Acc) -> bopt_1(Is, [I|Acc]);
bopt_1([], Acc) -> reverse(Acc).

opt_is_bool({test,is_boolean,{f,Lbl},[Reg]}, Acc) ->
    opt_is_bool_1(Acc, Reg, Lbl).

opt_is_bool_1([{test,is_eq_exact,{f,Lbl},[Reg,{atom,true}]}|_], Reg, Lbl) ->
    %% Instruction not needed in this context.
    yes;
opt_is_bool_1([{test,is_ne_exact,{f,Lbl},[Reg,{atom,true}]}|Acc], Reg, Lbl) ->
    %% Rewrite to shorter test.
    {yes,[{test,is_eq_exact,{f,Lbl},[Reg,{atom,false}]}|Acc]};
opt_is_bool_1([{test,_,{f,Lbl},_}=Test|Acc0], Reg, Lbl) ->
    case opt_is_bool_1(Acc0, Reg, Lbl) of
	{yes,Acc} -> {yes,[Test|Acc]};
	Other -> Other
    end;
opt_is_bool_1(_, _, _) -> no.

%% We must split the basic block when we encounter instructions with labels,
%% such as catches and BIFs. All labels must be visible outside the blocks.
%% Also remove empty blocks.

split_blocks({function,Name,Arity,CLabel,Is0}) ->
    Is = split_blocks(Is0, []),
    {function,Name,Arity,CLabel,Is}.

split_blocks([{block,[{'%live',_}=Live]}|Is], Acc) ->
    split_blocks(Is, [Live|Acc]);
split_blocks([{block,[]}|Is], Acc) ->
    split_blocks(Is, Acc);
split_blocks([{block,Bl}|Is], Acc0) ->
    Acc = split_block(Bl, [], Acc0),
    split_blocks(Is, Acc);
split_blocks([I|Is], Acc) ->
    split_blocks(Is, [I|Acc]);
split_blocks([], Acc) -> reverse(Acc).

split_block([{set,[R],[_,_,_]=As,{bif,is_record,{f,Lbl}}}|Is], Bl, Acc) ->
    %% is_record/3 must be translated by beam_clean; therefore,
    %% it must be outside of any block.
    split_block(Is, [], [{bif,is_record,{f,Lbl},As,R}|make_block(Bl, Acc)]);
split_block([{set,[R],As,{bif,N,{f,Lbl}=Fail}}|Is], Bl, Acc) when Lbl =/= 0 ->
    split_block(Is, [], [{bif,N,Fail,As,R}|make_block(Bl, Acc)]);
split_block([{set,[R],As,{alloc,Live,{gc_bif,N,{f,Lbl}=Fail}}}|Is], Bl, Acc)
  when Lbl =/= 0 ->
    split_block(Is, [], [{gc_bif,N,Fail,Live,As,R}|make_block(Bl, Acc)]);
split_block([{set,[R],[],{'catch',L}}|Is], Bl, Acc) ->
    split_block(Is, [], [{'catch',R,L}|make_block(Bl, Acc)]);
split_block([I|Is], Bl, Acc) ->
    split_block(Is, [I|Bl], Acc);
split_block([], Bl, Acc) -> make_block(Bl, Acc).

make_block([], Acc) -> Acc;
make_block([{'%live',_},{set,[D],Ss,{bif,Op,Fail}}|Bl]=Bl0, Acc) ->
    %% If the last instruction in the block is a comparison or boolean operator
    %% (such as '=:='), move it out of the block to faciliate further
    %% optimizations.
    Arity = length(Ss),
    case erl_internal:comp_op(Op, Arity) orelse
	erl_internal:new_type_test(Op, Arity) orelse
	erl_internal:bool_op(Op, Arity) of
	false ->
	    [{block,reverse(Bl0)}|Acc];
	true ->
	    I = {bif,Op,Fail,Ss,D},
	    case Bl =:= [] of
		true -> [I|Acc];
		false -> [I,{block,reverse(Bl)}|Acc]
	    end
    end;
make_block([{'%live',_},{set,[Dst],[Src],move}|Bl], Acc) ->
    %% Make optimization of {move,Src,Dst}, {jump,...} possible.
    I = {move,Src,Dst},
    case Bl =:= [] of
	true -> [I|Acc];
	false -> [I,{block,reverse(Bl)}|Acc]
    end;
make_block(Bl, Acc) -> [{block,reverse(Bl)}|Acc].

%% 'move' instructions outside of blocks may thwart the jump optimizer.
%% Move them back into the block.

move_move_into_block([{block,Bl0},{move,S,D}|Is], Acc) ->
    Bl = Bl0 ++ [{set,[D],[S],move}],
    move_move_into_block([{block,Bl}|Is], Acc);
move_move_into_block([{move,S,D}|Is], Acc) ->
    Bl = [{set,[D],[S],move}],
    move_move_into_block([{block,Bl}|Is], Acc);
move_move_into_block([I|Is], Acc) ->
    move_move_into_block(Is, [I|Acc]);
move_move_into_block([], Acc) -> reverse(Acc).

%%%
%%% Scan instructions in execution order and remove dead code.
%%%

forward(Is, Lc) ->
    forward(Is, gb_trees:empty(), Lc, []).

forward([{'%live',_}|Is], D, Lc, Acc) ->
    %% Remove - prevents optimizations.
    forward(Is, D, Lc, Acc);
forward([{block,[{'%live',_}]}|Is], D, Lc, Acc) ->
    %% Empty blocks can prevent optimizations.
    forward(Is, D, Lc, Acc);
forward([{select_val,Reg,_,{list,List}}=I|Is], D0, Lc, Acc) ->
    D = update_value_dict(List, Reg, D0),
    forward(Is, D, Lc, [I|Acc]);
forward([{label,Lbl}=LblI,{block,[{set,[Dst],[Lit],move}|BlkIs]}=Blk|Is], D, Lc, Acc) ->
    Block = case gb_trees:lookup({Lbl,Dst}, D) of
		{value,Lit} ->
		    %% The move instruction seems to be redundant, but also make
		    %% sure that the instruction preceeding the label
		    %% cannot fall through to the move instruction.
		    case is_unreachable_after(Acc) of
			false -> Blk;	  %Must keep move instruction.
			true ->  {block,BlkIs}	%Safe to remove move instruction.
		    end;
		_ -> Blk		       %Keep move instruction.
	    end,
    forward([Block|Is], D, Lc, [LblI|Acc]);
forward([{test,is_eq_exact,_,[Dst,Src]}=I,
	 {block,[{set,[Dst],[Src],move}|Bl]}|Is], D, Lc, Acc) ->
    forward([I,{block,Bl}|Is], D, Lc, Acc);
forward([{test,is_nil,_,[Dst]}=I,
	 {block,[{set,[Dst],[nil],move}|Bl]}|Is], D, Lc, Acc) ->
    forward([I,{block,Bl}|Is], D, Lc, Acc);
forward([{test,is_eq_exact,_,[Dst,Src]}=I,{move,Src,Dst}|Is], D, Lc, Acc) ->
    forward([I|Is], D, Lc, Acc);
forward([{test,is_nil,_,[Dst]}=I,{move,nil,Dst}|Is], D, Lc, Acc) ->
    forward([I|Is], D, Lc, Acc);
forward([{test,is_eq_exact,_,[_,{atom,_}]}=I|Is], D, Lc, [{label,_}|_]=Acc) ->
    case Is of
	[{label,_}|_] -> forward(Is, D, Lc, [I|Acc]);
	_ -> forward(Is, D, Lc+1, [{label,Lc},I|Acc])
    end;
forward([{test,is_ne_exact,_,[_,{atom,_}]}=I|Is], D, Lc, [{label,_}|_]=Acc) ->
    case Is of
	[{label,_}|_] -> forward(Is, D, Lc, [I|Acc]);
	_ -> forward(Is, D, Lc+1, [{label,Lc},I|Acc])
    end;
forward([I|Is], D, Lc, Acc) ->
    forward(Is, D, Lc, [I|Acc]);
forward([], _, Lc, Acc) -> {Acc,Lc}.

update_value_dict([Lit,{f,Lbl}|T], Reg, D0) ->
    Key = {Lbl,Reg},
    D = case gb_trees:lookup(Key, D0) of
	    none -> gb_trees:insert(Key, Lit, D0); %New.
	    {value,Lit} -> D0;			%Already correct.
	    {value,inconsistent} -> D0;		%Inconsistent.
	    {value,_} -> gb_trees:update(Key, inconsistent, D0)
	end,
    update_value_dict(T, Reg, D);
update_value_dict([], _, D) -> D.

is_unreachable_after([I|_]) ->
    beam_jump:is_unreachable_after(I).

%%%
%%% Scan instructions in reverse execution order and remove dead code.
%%%

backward(Is) ->
    backward(Is, beam_utils:empty_label_index(), []).

backward([{label,Lbl}=L|Is], D, Acc) ->
    backward(Is, beam_utils:index_label(Lbl, Acc, D), [L|Acc]);
backward([{select_val,Reg,{f,Fail0},{list,List0}}|Is], D, Acc) ->
    List = shortcut_select_list(List0, Reg, D, []),
    Fail1 = shortcut_label(Fail0, D),
    Fail = shortcut_bs_test(Fail1, Is, D),
    Sel = {select_val,Reg,{f,Fail},{list,List}},
    backward(Is, D, [Sel|Acc]);
backward([{jump,{f,To0}},{move,Src,Reg}=Move0|Is], D, Acc) ->
    {To,Move} = case Src of
		    {atom,Val0} ->
			To1 = shortcut_select_label(To0, Reg, Val0, D),
			{To2,Val} = shortcut_boolean_label(To1, Reg, Val0, D),
			{To2,{move,{atom,Val},Reg}};
		    _ ->
			{shortcut_label(To0, D),Move0}
		end,
    Jump = {jump,{f,To}},
    case beam_utils:is_killed_at(Reg, To, D) of
	false -> backward([Move|Is], D, [Jump|Acc]);
	true -> backward([Jump|Is], D, Acc)
    end;
backward([{jump,{f,To}}=J|[{bif,Op,_,Ops,Reg}|Is]=Is0], D, Acc) ->
    try replace_comp_op(To, Reg, Op, Ops, D) of
	I -> backward(Is, D, I++Acc)
    catch
	throw:not_possible -> backward(Is0, D, [J|Acc])
    end;
backward([{test,bs_start_match2,{f,To0},[Src|_]=Info}|Is], D, Acc) ->
    To = shortcut_bs_start_match(To0, Src, D),
    I = {test,bs_start_match2,{f,To},Info},
    backward(Is, D, [I|Acc]);
backward([{test,Op,{f,To0},Ops}|Is], D, Acc) ->
    To = shortcut_bs_test(To0, Is, D),
    I = {test,Op,{f,To},Ops},
    backward(Is, D, [I|Acc]);
backward([{block,[{'%live',_}]}|Is], D, Acc) ->
    %% A redundant block could prevent some jump optimizations in beam_jump.
    %% Ge rid of it.
    backward(Is, D, Acc);
backward([{kill,_}=I|Is], D, [Exit|_]=Acc) ->
    case beam_jump:is_exit_instruction(Exit) of
	false -> backward(Is, D, [I|Acc]);
	true -> backward(Is, D, Acc)
    end;
backward([{'%live',_}|Is], D, Acc) ->
    backward(Is, D, Acc);
backward([I|Is], D, Acc) ->
    backward(Is, D, [I|Acc]);
backward([], _D, Acc) -> Acc.

shortcut_select_list([{_,Val}=Lit,{f,To0}|T], Reg, D, Acc) ->
    To = shortcut_select_label(To0, Reg, Val, D),
    shortcut_select_list(T, Reg, D, [{f,To},Lit|Acc]);
shortcut_select_list([], _, _, Acc) -> reverse(Acc).

shortcut_label(To0, D) ->
    case beam_utils:code_at(To0, D) of
  	[{jump,{f,To}}|_] -> shortcut_label(To, D);
	_ -> To0
    end.

shortcut_select_label(To0, Reg, Val, D) ->
    case beam_utils:code_at(To0, D) of
 	[{jump,{f,To}}|_] ->
 	    shortcut_select_label(To, Reg, Val, D);
	[{test,is_atom,_,[Reg]},{select_val,Reg,{f,Fail},{list,Map}}|_] ->
	    To = find_select_val(Map, Val, Fail),
	    shortcut_select_label(To, Reg, Val, D);
  	[{test,is_eq_exact,{f,_},[Reg,{atom,Val}]},{label,To}|_] when is_atom(Val) ->
	    shortcut_select_label(To, Reg, Val, D);
  	[{test,is_eq_exact,{f,To},[Reg,{atom,_}]}|_] when is_atom(Val) ->
	    shortcut_select_label(To, Reg, Val, D);
  	[{test,is_ne_exact,{f,To},[Reg,{atom,Val}]}|_] when is_atom(Val) ->
	    shortcut_select_label(To, Reg, Val, D);
  	[{test,is_ne_exact,{f,_},[Reg,{atom,_}]},{label,To}|_] when is_atom(Val) ->
	    shortcut_select_label(To, Reg, Val, D);
	[{test,is_tuple,{f,To},[Reg]}|_] when is_atom(Val) ->
	    shortcut_select_label(To, Reg, Val, D);
	_ ->
	    To0
    end.

shortcut_boolean_label(To0, Reg, Bool0, D) when is_boolean(Bool0) ->
    case beam_utils:code_at(To0, D) of
	[{bif,'not',_,[Reg],Reg},{jump,{f,To}}|_] ->
	    Bool = not Bool0,
	    {shortcut_select_label(To, Reg, Bool, D),Bool};
	_ ->
	    {To0,Bool0}
    end;
shortcut_boolean_label(To, _, Bool, _) -> {To,Bool}.

find_select_val([{_,Val},{f,To}|_], Val, _) -> To;
find_select_val([{_,_}, {f,_}|T], Val, Fail) ->
    find_select_val(T, Val, Fail);
find_select_val([], _, Fail) -> Fail.

replace_comp_op(To, Reg, Op, Ops, D) ->
    False = comp_op_find_shortcut(To, Reg, false, D),
    True = comp_op_find_shortcut(To, Reg, true, D),
    [bif_to_test(Op, Ops, False),{jump,{f,True}}].

comp_op_find_shortcut(To0, Reg, Val, D) ->
    case shortcut_select_label(To0, Reg, Val, D) of
	To0 ->
	    not_possible();
	To ->
	    case beam_utils:is_killed_at(Reg, To, D) of
		false -> not_possible();
		true -> To
	    end
    end.

bif_to_test(Name, Args, Fail) ->
    try
	beam_utils:bif_to_test(Name, Args, {f,Fail})
    catch
	error:_ -> not_possible()
    end.

not_possible() -> throw(not_possible).


%% shortcut_bs_test(TargetLabel, [Instruction], D) -> TargetLabel'
%%  Try to shortcut the failure label for a bit syntax matching.
%%  We know that the binary contains at least Bits bits after
%%  the latest save point.

shortcut_bs_test(To, Is, D) ->
    shortcut_bs_test_1(beam_utils:code_at(To, D), Is, To, D).

shortcut_bs_test_1(none, _, To, _) ->
    %% Probably the func_info label.
    To;
shortcut_bs_test_1([{bs_restore2,Reg,SavePoint}|Is], PrevIs, To, D) ->
    shortcut_bs_test_2(Is, {Reg,SavePoint}, PrevIs, To, D);
shortcut_bs_test_1([_|_], _, To, _) -> To.

shortcut_bs_test_2([{label,_}|Is], Save, PrevIs, To, D) ->
    shortcut_bs_test_2(Is, Save, PrevIs, To, D);
shortcut_bs_test_2([{test,bs_test_tail2,{f,To},[_,TailBits]}|_],
		   {Reg,Point}, PrevIs, To0, D) ->
    case count_bits_matched(PrevIs, {Reg,Point}, 0) of
	Bits when Bits > TailBits ->
	    %% This instruction will fail. We know because a restore has been
	    %% done from the previous point SavePoint in the binary, and we also know
	    %% that the binary contains at least Bits bits from SavePoint.
	    %%
	    %% Since we will skip a bs_restore2 if we shortcut to label To,
	    %% we must now make sure that code at To does not depend on the position
	    %% in the context in any way.
	    case shortcut_bs_pos_used(To, Reg, D) of
		false -> To;
		true -> To0
	    end;
	_Bits ->
	    To0
    end;
shortcut_bs_test_2([_|_], _, _, To, _) -> To.

count_bits_matched([{test,_,_,[_,_,Sz,U,{field_flags,_},_]}|Is], SavePoint, Bits) ->
    case Sz of
	{integer,N} -> count_bits_matched(Is, SavePoint, Bits+N*U);
	_ -> count_bits_matched(Is, SavePoint, Bits)
    end;
count_bits_matched([{test,_,_,_}|Is], SavePoint, Bits) ->
    count_bits_matched(Is, SavePoint, Bits);
count_bits_matched([{bs_save2,_,SavePoint}|_], SavePoint, Bits) ->
    %% The save point we are looking for - we are done.
    Bits;
count_bits_matched([{bs_save2,_,_}|Is], SavePoint, Bits) ->
    %% Another save point - keep counting.
    count_bits_matched(Is, SavePoint, Bits);
count_bits_matched([_|_], _, Bits) -> Bits.

shortcut_bs_pos_used(To, Reg, D) ->
    shortcut_bs_pos_used_1(beam_utils:code_at(To, D), Reg, D).

shortcut_bs_pos_used_1([{bs_restore2,Reg,_}|_], Reg, _) ->
    false;
shortcut_bs_pos_used_1([{bs_context_to_binary,Reg}|_], Reg, _) ->
    false;
shortcut_bs_pos_used_1(Is, Reg, D) ->
    not beam_utils:is_killed(Reg, Is, D).

%% shortcut_bs_start_match(TargetLabel, Reg) -> TargetLabel
%%  A failing bs_start_match2 instruction means that the source
%%  cannot be a binary, so there is no need to jump bs_context_to_binary/1
%%  or another bs_start_match2 instruction.

shortcut_bs_start_match(To, Reg, D) ->
    shortcut_bs_start_match_1(beam_utils:code_at(To, D), Reg, To).

shortcut_bs_start_match_1([{bs_context_to_binary,Reg}|Is], Reg, To) ->
    shortcut_bs_start_match_2(Is, Reg, To);
shortcut_bs_start_match_1(_, _, To) -> To.

shortcut_bs_start_match_2([{jump,{f,To}}|_], _, _) ->
    To;
shortcut_bs_start_match_2([{test,bs_start_match2,{f,To},[Reg|_]}|_], Reg, _) ->
    To;
shortcut_bs_start_match_2(_Is, _Reg, To) ->
    To.
