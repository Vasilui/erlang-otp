%%% -*- erlang-indent-level: 2 -*-
%%% $Id$

-module(hipe_sparc_cfg).

-export([init/1,
         labels/1, start_label/1,
         succ/2, succ_map/1,
         bb/2, bb_add/3]).
-export([postorder/1]).
-export([linearise/1]).
-export([params/1, reverse_postorder/1]).
-export([arity/1]). % for linear scan

%%% these tell cfg.inc what to define (ugly as hell)
-define(BREADTH_ORDER,true). % for linear scan
-define(PARAMS_NEEDED,true).
-define(START_LABEL_UPDATE_NEEDED,true).

-include("../main/hipe.hrl").
-include("../flow/cfg.hrl").
-include("../flow/cfg.inc").
-include("hipe_sparc.hrl").

%%----------------------------------------------------------------------------
%% CFG interface to SPARC
%%----------------------------------------------------------------------------

init(Defun) ->
  Code = hipe_sparc:defun_code(Defun),
  StartLab = hipe_sparc:label_label(hd(Code)),
  Data = hipe_sparc:defun_data(Defun),
  IsClosure = hipe_sparc:defun_is_closure(Defun),
  Name = hipe_sparc:defun_mfa(Defun),
  IsLeaf = hipe_sparc:defun_is_leaf(Defun),
  Formals = hipe_sparc:defun_formals(Defun),
  Extra = [],
  CFG = mk_empty_cfg(Name, StartLab, Data, IsClosure, IsLeaf, Formals, Extra),
  take_bbs(Code, CFG).

is_branch(I) ->
  case I of
    #bp{'cond'='a'} -> true;
    %% not br
    #call_tail{} -> true;
    #jmp{} -> true;
    %% not jmpl
    #pseudo_bp{} -> true; 
    %% #pseudo_br{} -> true;
    #pseudo_call{} -> true;
    #pseudo_ret{} -> true;
    #pseudo_tailcall{} -> true;
    _ -> false
  end.

branch_successors(Branch) ->
  case Branch of
    #bp{'cond'='a',label=Label} -> [Label];
    #call_tail{} -> [];
    #jmp{labels=Labels} -> Labels;
    #pseudo_bp{true_label=TrueLab,false_label=FalseLab} -> [FalseLab,TrueLab];
    %% #pseudo_br{true_label=TrueLab,false_label=FalseLab} -> [FalseLab,TrueLab];
    #pseudo_call{contlab=ContLab, sdesc=#sparc_sdesc{exnlab=ExnLab}} ->
      case ExnLab of
	[] -> [ContLab];
	_ -> [ContLab,ExnLab]
      end;
    #pseudo_ret{} -> [];
    #pseudo_tailcall{} -> []
  end.

-ifdef(REMOVE_TRIVIAL_BBS_NEEDED).
fails_to(_Instr) -> [].
-endif.

-ifdef(notdef).
redirect_jmp(I, Old, New) ->
  case I of
    #b_label{label=Label} ->
      if Old =:= Label -> I#b_label{label=New};
	 true -> I
      end;
    #pseudo_bc{true_label=TrueLab, false_label=FalseLab} ->
      I1 = if Old =:= TrueLab -> I#pseudo_bc{true_label=New};
	      true -> I
	   end,
      if Old =:= FalseLab -> I1#pseudo_bc{false_label=New};
	 true -> I1
      end;
    %% handle pseudo_call too?
    _ -> I
  end.
-endif.

mk_goto(Label) ->
  hipe_sparc:mk_b_label(Label).

is_label(I) ->
  hipe_sparc:is_label(I).

label_name(Label) ->
  hipe_sparc:label_label(Label).

mk_label(Name) ->
  hipe_sparc:mk_label(Name).

linearise(CFG) ->	% -> defun, not insn list
  Fun = function(CFG),
  Formals = params(CFG),
  Code = linearize_cfg(CFG),
  Data = data(CFG),
  VarRange = hipe_gensym:var_range(sparc),
  LabelRange = hipe_gensym:label_range(sparc),
  IsClosure = is_closure(CFG),
  IsLeaf = is_leaf(CFG),
  hipe_sparc:mk_defun(Fun, Formals, IsClosure, IsLeaf,
		      Code, Data, VarRange, LabelRange).

arity(CFG) ->
  #sparc_mfa{a=Arity} = function(CFG),
  Arity.
