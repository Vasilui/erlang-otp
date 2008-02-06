-module(megaco_text_parser_v1).
-export([parse/1, parse_and_scan/1, format_error/1]).
-file("megaco_text_parser_v1.yrl", 1290).

%% The following directive is needed for (significantly) faster compilation
%% of the generated .erl file by the HiPE compiler.  Please do not remove.
-compile([{hipe,[{regalloc,linear_scan}]}]).

-include("megaco_text_parser_v1.hrl").

%i(F) ->
%    i(F, []).

%i(F, A) ->
%    i(get(dbg), F, A).

%i(true, F, A) ->
%    io:format("DBG:~p:" ++ F ++ "~n", [?MODULE|A]);
%i(_, _, _) ->
%    ok.


-file("/ldisk/daily_build/otp_prebuild_r12b.2008-02-05_20/otp_src_R12B-1/bootstrap/lib/parsetools/include/yeccpre.hrl", 0).
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
%%     $Id $
%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The parser generator will insert appropriate declarations before this line.%

parse(Tokens) ->
    yeccpars0(Tokens, false).

parse_and_scan({F, A}) -> % Fun or {M, F}
    yeccpars0([], {F, A});
parse_and_scan({M, F, A}) ->
    yeccpars0([], {{M, F}, A}).

format_error(Message) ->
    case io_lib:deep_char_list(Message) of
	true ->
	    Message;
	_ ->
	    io_lib:write(Message)
    end.

% To be used in grammar files to throw an error message to the parser
% toplevel. Doesn't have to be exported!
-compile({nowarn_unused_function,{return_error,2}}).
-spec(return_error/2 :: (integer(), any()) -> no_return()).
return_error(Line, Message) ->
    throw({error, {Line, ?MODULE, Message}}).

-define(CODE_VERSION, "1.2").

yeccpars0(Tokens, MFA) ->
    try yeccpars1(Tokens, MFA, 0, [], [])
    catch 
        error: Error ->
            Stacktrace = erlang:get_stacktrace(),
            try yecc_error_type(Error, Stacktrace) of
                {syntax_error, Token} ->
                    yeccerror(Token);
                {missing_in_goto_table=Tag, State} ->
                    Desc = {State, Tag},
                    erlang:raise(error, {yecc_bug, ?CODE_VERSION, Desc},
                                Stacktrace);
                {missing_in_goto_table=Tag, Symbol, State} ->
                    Desc = {Symbol, State, Tag},
                    erlang:raise(error, {yecc_bug, ?CODE_VERSION, Desc},
                                Stacktrace)
            catch _:_ -> erlang:raise(error, Error, Stacktrace)
            end;
        throw: {error, {_Line, ?MODULE, _M}} = Error -> 
            Error % probably from return_error/2
    end.

yecc_error_type(function_clause, [{?MODULE,F,[_,_,_,_,Token,_,_]} | _]) ->
    "yeccpars2" ++ _ = atom_to_list(F),
    {syntax_error, Token};
yecc_error_type({case_clause,{State}}, [{?MODULE,yeccpars2,_}|_]) ->
    %% Inlined goto-function
    {missing_in_goto_table, State};
yecc_error_type(function_clause, [{?MODULE,F,[State]}|_]) ->
    "yeccgoto_" ++ SymbolL = atom_to_list(F),
    {ok,[{atom,_,Symbol}]} = erl_scan:string(SymbolL),
    {missing_in_goto_table, Symbol, State}.

yeccpars1([Token | Tokens], Tokenizer, State, States, Vstack) ->
    yeccpars2(State, element(1, Token), States, Vstack, Token, Tokens, 
              Tokenizer);
yeccpars1([], {F, A}, State, States, Vstack) ->
    case apply(F, A) of
        {ok, Tokens, _Endline} ->
	    yeccpars1(Tokens, {F, A}, State, States, Vstack);
        {eof, _Endline} ->
            yeccpars1([], false, State, States, Vstack);
        {error, Descriptor, _Endline} ->
            {error, Descriptor}
    end;
yeccpars1([], false, State, States, Vstack) ->
    yeccpars2(State, '$end', States, Vstack, {'$end', 999999}, [], false).

%% yeccpars1/7 is called from generated code.
%%
%% When using the {includefile, Includefile} option, make sure that
%% yeccpars1/7 can be found by parsing the file without following
%% include directives. yecc will otherwise assume that an old
%% yeccpre.hrl is included (one which defines yeccpars1/5).
yeccpars1(State1, State, States, Vstack, Stack1, [Token | Tokens], 
          Tokenizer) ->
    yeccpars2(State, element(1, Token), [State1 | States],
              [Stack1 | Vstack], Token, Tokens, Tokenizer);
yeccpars1(State1, State, States, Vstack, Stack1, [], {F, A}) ->
    case apply(F, A) of
        {ok, Tokens, _Endline} ->
	    yeccpars1(State1, State, States, Vstack, Stack1, Tokens, {F, A});
        {eof, _Endline} ->
            yeccpars1(State1, State, States, Vstack, Stack1, [], false);
        {error, Descriptor, _Endline} ->
            {error, Descriptor}
    end;
yeccpars1(State1, State, States, Vstack, Stack1, [], false) ->
    yeccpars2(State, '$end', [State1 | States], [Stack1 | Vstack],
              {'$end', 999999}, [], false).

% For internal use only.
yeccerror(Token) ->
    {error,
     {element(2, Token), ?MODULE,
      ["syntax error before: ", yecctoken2string(Token)]}}.

yecctoken2string({atom, _, A}) -> io_lib:write(A);
yecctoken2string({integer,_,N}) -> io_lib:write(N);
yecctoken2string({float,_,F}) -> io_lib:write(F);
yecctoken2string({char,_,C}) -> io_lib:write_char(C);
yecctoken2string({var,_,V}) -> io_lib:format('~s', [V]);
yecctoken2string({string,_,S}) -> io_lib:write_string(S);
yecctoken2string({reserved_symbol, _, A}) -> io_lib:format('~w', [A]);
yecctoken2string({_Cat, _, Val}) -> io_lib:format('~w', [Val]);
yecctoken2string({'dot', _}) -> io_lib:format('~w', ['.']);
yecctoken2string({'$end', _}) ->
    [];
yecctoken2string({Other, _}) when is_atom(Other) ->
    io_lib:format('~w', [Other]);
yecctoken2string(Other) ->
    io_lib:write(Other).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



-file("./megaco_text_parser_v1.erl", 167).

yeccpars2(0=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_0(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(1=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_1(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(2=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_2(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(3=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_3(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(4=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(5=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_5(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(6=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(7=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_7(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(8=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_8(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(9=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_9(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(10=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_10(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(11=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_11(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(12=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_12(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(13=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_13(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(14=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_14(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(15=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_15(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(16=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_16(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(17=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_17(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(18=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_18(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(19=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_19(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(20=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_20(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(21=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_21(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(22=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_22(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(23=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_23(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(24=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_24(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(25=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_25(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(26=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_26(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(27=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_27(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(28=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_28(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(29=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_29(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(30=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_30(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(31=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_31(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(32=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_32(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(33=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_33(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(34=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_34(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(35=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_35(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(36=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_36(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(37=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_37(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(38=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_38(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(39=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_39(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(40=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_40(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(41=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_41(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(42=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_42(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(43=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_43(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(44=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_44(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(45=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_45(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(46=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_46(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(47=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_47(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(48=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_48(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(49=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_49(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(50=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_50(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(51=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_51(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(52=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_52(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(53=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_53(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(54=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_54(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(55=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_55(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(56=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_56(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(57=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_57(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(58=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_58(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(59=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_59(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(60=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_60(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(61=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_61(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(62=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_62(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(63=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_63(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(64=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_64(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(65=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_65(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(66=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_66(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(67=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_67(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(68=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_68(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(69=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_69(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(70=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_70(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(71=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_71(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(72=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_72(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(73=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_73(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(74=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_74(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(75=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_75(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(76=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_76(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(77=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_77(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(78=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_78(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(79=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_79(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(80=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_80(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(81=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_81(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(82=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_82(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(83=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_83(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(84=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_84(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(85=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_85(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(86=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_86(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(87=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_87(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(88=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_88(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(89=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_89(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(90=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_90(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(91=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_91(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(92=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_92(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(93=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_93(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(94=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_94(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(95=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_95(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(96=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_96(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(97=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_97(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(98=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_98(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(99=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_99(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(100=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_100(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(101=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_101(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(102=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(103=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_103(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(104=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(105=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_105(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(106=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_106(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(107=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_107(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(108=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_108(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(109=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_109(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(110=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_110(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(111=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_111(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(112=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_112(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(113=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_113(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(114=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(115=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_115(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(116=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_116(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(117=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_117(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(118=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_118(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(119=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_119(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(120=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_120(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(121=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(122=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_122(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(123=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_123(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(124=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_124(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(125=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_125(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(126=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_126(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(127=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_127(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(128=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(129=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_129(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(130=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_130(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(131=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_131(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(132=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_132(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(133=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_133(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(134=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_134(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(135=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_135(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(136=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_136(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(137=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_137(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(138=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_138(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(139=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_139(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(140=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_140(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(141=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_141(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(142=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_142(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(143=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_143(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(144=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_144(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(145=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_145(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(146=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_146(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(147=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_147(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(148=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(149=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_149(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(150=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_150(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(151=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_151(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(152=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_152(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(153=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_153(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(154=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_154(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(155=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_155(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(156=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_156(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(157=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_157(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(158=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_158(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(159=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_159(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(160=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_160(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(161=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_161(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(162=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_162(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(163=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_163(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(164=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_164(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(165=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_165(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(166=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_166(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(167=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_167(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(168=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_168(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(169=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_169(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(170=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_170(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(171=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_171(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(172=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_172(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(173=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_173(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(174=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_174(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(175=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_175(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(176=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(177=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_177(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(178=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_178(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(179=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_179(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(180=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_180(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(181=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(182=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_182(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(183=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_183(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(184=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_184(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(185=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_185(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(186=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_186(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(187=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_187(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(188=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_188(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(189=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_189(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(190=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(191=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_191(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(192=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_192(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(193=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_193(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(194=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(195=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_195(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(196=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_196(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(197=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_197(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(198=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_198(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(199=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_199(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(200=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_200(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(201=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_201(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(202=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_202(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(203=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_203(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(204=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_204(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(205=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_205(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(206=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_206(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(207=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_207(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(208=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_208(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(209=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_209(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(210=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_210(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(211=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_211(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(212=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_212(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(213=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_213(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(214=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_214(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(215=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_215(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(216=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_216(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(217=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_217(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(218=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_218(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(219=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_219(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(220=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(221=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_221(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(222=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_222(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(223=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_223(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(224=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_224(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(225=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_225(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(226=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_226(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(227=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_227(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(228=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_228(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(229=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_229(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(230=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_230(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(231=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_231(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(232=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_232(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(233=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_233(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(234=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_234(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(235=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_235(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(236=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_236(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(237=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_237(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(238=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_238(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(239=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_239(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(240=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_240(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(241=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_241(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(242=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_242(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(243=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_243(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(244=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_244(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(245=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_245(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(246=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(247=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_247(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(248=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_248(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(249=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_249(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(250=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_250(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(251=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(252=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_252(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(253=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_253(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(254=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_254(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(255=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(256=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_256(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(257=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_257(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(258=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_258(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(259=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(260=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_260(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(261=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(262=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_262(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(263=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_263(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(264=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_264(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(265=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(266=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(267=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(268=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_268(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(269=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_269(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(270=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_270(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(271=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_271(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(272=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_272(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(273=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(274=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(275=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_275(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(276=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_276(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(277=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(278=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(279=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_279(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(280=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_280(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(281=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_281(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(282=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_282(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(283=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_283(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(284=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_284(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(285=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_285(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(286=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_286(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(287=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_287(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(288=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_225(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(289=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_289(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(290=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_290(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(291=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_291(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(292=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_292(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(293=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(294=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_294(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(295=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(296=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_296(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(297=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_297(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(298=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_298(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(299=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_299(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(300=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_300(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(301=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_301(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(302=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(303=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_303(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(304=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_304(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(305=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_305(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(306=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_306(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(307=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_307(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(308=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_308(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(309=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_309(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(310=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_310(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(311=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_311(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(312=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_312(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(313=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_313(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(314=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_314(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(315=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_315(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(316=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(317=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_317(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(318=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_318(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(319=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(320=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_320(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(321=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_321(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(322=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_322(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(323=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_236(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(324=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_324(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(325=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_325(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(326=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(327=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_327(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(328=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_328(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(329=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_329(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(330=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_330(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(331=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_331(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(332=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_332(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(333=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_333(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(334=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_334(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(335=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_335(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(336=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_336(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(337=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_337(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(338=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_338(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(339=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_339(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(340=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_334(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(341=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_341(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(342=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_342(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(343=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_343(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(344=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(345=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_345(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(346=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_346(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(347=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(348=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_348(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(349=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_349(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(350=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_350(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(351=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_151(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(352=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_352(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(353=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_353(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(354=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_354(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(355=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(356=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_356(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(357=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_357(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(358=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_358(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(359=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_359(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(360=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_360(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(361=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_361(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(362=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_362(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(363=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_363(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(364=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_364(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(365=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_365(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(366=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_366(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(367=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_367(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(368=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_368(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(369=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_369(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(370=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_370(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(371=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_371(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(372=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_372(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(373=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_373(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(374=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_374(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(375=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_375(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(376=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_376(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(377=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_377(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(378=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_378(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(379=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_379(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(380=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_380(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(381=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_381(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(382=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(383=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_383(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(384=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_384(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(385=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(386=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_386(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(387=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_387(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(388=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_388(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(389=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(390=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_390(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(391=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_391(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(392=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_392(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(393=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_393(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(394=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_394(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(395=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_236(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(396=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_396(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(397=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_397(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(398=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_398(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(399=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_399(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(400=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_400(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(401=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(402=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_402(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(403=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_403(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(404=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_404(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(405=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_405(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(406=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_406(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(407=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_407(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(408=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_408(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(409=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_409(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(410=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_410(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(411=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_411(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(412=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_412(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(413=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_413(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(414=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_414(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(415=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_415(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(416=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_416(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(417=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_410(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(418=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_418(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(419=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_419(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(420=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_420(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(421=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(422=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_422(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(423=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_423(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(424=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_424(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(425=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_393(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(426=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_426(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(427=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_427(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(428=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_428(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(429=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_429(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(430=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_375(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(431=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_431(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(432=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_432(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(433=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_433(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(434=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(435=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_435(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(436=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_436(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(437=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_437(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(438=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(439=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_439(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(440=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_440(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(441=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(442=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_442(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(443=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_443(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(444=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_444(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(445=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(446=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(447=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_447(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(448=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_448(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(449=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_449(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(450=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(451=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_451(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(452=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_452(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(453=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_453(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(454=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_454(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(455=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(456=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_456(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(457=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_236(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(458=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_458(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(459=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_459(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(460=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(461=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_461(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(462=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_462(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(463=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_463(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(464=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_464(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(465=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_465(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(466=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_466(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(467=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_467(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(468=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_468(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(469=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_469(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(470=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_470(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(471=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_471(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(472=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_472(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(473=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_473(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(474=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_474(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(475=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_475(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(476=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_476(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(477=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_477(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(478=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_478(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(479=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_479(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(480=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_480(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(481=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_481(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(482=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_482(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(483=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_483(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(484=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_484(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(485=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_485(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(486=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_486(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(487=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_487(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(488=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_488(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(489=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_489(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(490=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_490(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(491=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_491(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(492=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_492(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(493=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_493(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(494=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_477(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(495=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_495(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(496=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_496(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(497=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_497(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(498=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(499=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_499(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(500=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_500(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(501=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_501(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(502=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_502(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(503=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_500(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(504=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_504(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(505=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_505(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(506=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_506(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(507=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_507(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(508=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_508(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(509=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_509(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(510=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_510(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(511=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_511(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(512=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_512(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(513=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_513(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(514=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_514(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(515=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_515(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(516=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_516(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(517=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_513(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(518=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_518(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(519=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_519(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(520=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_520(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(521=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_521(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(522=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_522(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(523=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_523(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(524=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_524(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(525=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_525(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(526=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_526(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(527=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_507(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(528=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_528(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(529=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_529(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(530=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_530(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(531=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_531(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(532=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_466(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(533=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_533(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(534=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_534(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(535=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_535(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(536=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(537=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_537(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(538=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(539=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_539(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(540=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_540(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(541=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_541(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(542=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_542(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(543=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_543(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(544=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_544(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(545=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_545(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(546=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_546(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(547=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_547(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(548=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_548(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(549=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_549(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(550=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_550(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(551=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_551(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(552=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_552(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(553=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_553(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(554=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_554(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(555=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(556=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_556(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(557=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(558=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_558(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(559=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_559(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(560=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_560(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(561=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_561(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(562=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_562(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(563=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_563(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(564=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_564(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(565=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_565(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(566=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_566(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(567=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_567(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(568=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_568(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(569=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_569(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(570=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_570(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(571=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_571(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(572=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_561(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(573=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_573(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(574=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_574(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(575=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_575(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(576=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_576(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(577=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(578=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_578(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(579=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_579(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(580=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_580(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(581=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_581(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(582=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_582(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(583=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_583(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(584=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_584(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(585=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_585(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(586=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_586(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(587=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_542(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(588=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_588(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(589=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_589(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(590=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_590(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(591=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_591(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(592=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(593=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_593(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(594=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_594(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(595=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_595(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(596=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_596(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(597=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_597(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(598=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_598(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(599=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_599(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(600=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_600(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(601=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_601(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(602=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_602(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(603=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_603(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(604=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_604(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(605=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_358(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(606=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_606(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(607=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_607(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(608=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_608(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(609=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_609(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(610=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_145(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(611=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_611(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(612=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_612(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(613=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_613(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(614=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_614(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(615=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_615(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(616=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_145(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(617=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_617(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(618=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_618(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(619=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_619(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(620=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_145(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(621=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_621(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(622=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_622(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(623=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_623(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(624=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(625=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_625(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(626=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_626(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(627=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_627(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(628=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(629=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_629(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(630=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_630(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(631=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_631(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(632=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(633=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_633(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(634=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_634(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(635=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_635(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(636=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_636(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(637=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_637(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(638=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_638(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(639=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_639(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(640=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_640(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(641=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_641(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(642=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(643=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_643(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(644=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_644(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(645=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_645(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(646=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_646(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(647=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_647(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(648=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_648(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(649=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_649(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(650=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_650(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(651=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_651(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(652=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_652(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(653=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_653(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(654=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_654(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(655=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_655(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(656=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_656(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(657=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_657(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(658=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_658(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(659=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_659(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(660=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_660(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(661=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_661(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(662=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(663=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_663(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(664=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_664(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(665=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_665(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(666=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_666(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(667=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_667(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(668=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_668(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(669=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_669(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(670=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_670(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(671=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_671(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(672=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_672(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(673=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_673(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(674=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_674(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(675=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_675(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(676=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_676(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(677=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_677(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(678=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_678(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(679=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_679(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(680=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_680(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(681=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_669(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(682=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_682(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(683=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_683(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(684=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_684(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(685=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_685(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(686=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_686(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(687=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(688=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_688(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(689=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_689(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(690=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_690(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(691=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_691(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(692=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_692(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(693=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_693(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(694=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_694(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(695=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_695(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(696=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_696(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(697=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_697(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(698=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_698(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(699=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_699(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(700=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_700(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(701=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_701(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(702=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(703=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_703(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(704=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_704(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(705=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_705(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(706=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_706(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(707=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_707(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(708=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_708(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(709=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_709(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(710=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_710(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(711=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_711(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(712=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_712(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(713=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_713(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(714=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_714(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(715=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_715(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(716=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_716(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(717=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_717(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(718=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_718(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(719=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_719(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(720=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_720(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(721=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_721(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(722=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_722(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(723=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_723(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(724=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_724(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(725=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_725(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(726=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_726(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(727=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_727(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(728=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_728(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(729=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_729(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(730=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_730(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(731=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(732=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_732(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(733=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_733(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(734=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_251(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(735=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_735(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(736=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_736(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(737=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(738=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_738(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(739=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_739(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(740=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_740(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(741=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(742=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_742(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(743=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_743(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(744=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_744(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(745=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(746=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_746(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(747=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_747(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(748=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_748(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(749=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_749(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(750=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_710(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(751=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_751(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(752=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_752(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(753=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_753(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(754=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_754(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(755=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_755(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(756=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_756(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(757=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_757(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(758=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_758(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(759=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(760=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_760(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(761=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_761(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(762=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_710(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(763=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_763(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(764=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_764(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(765=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_765(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(766=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_644(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(767=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_767(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(768=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_768(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(769=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_769(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(770=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_770(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(771=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_771(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(772=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_772(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(773=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_773(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(774=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_774(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(775=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(776=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_776(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(777=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_777(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(778=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_778(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(779=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_779(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(780=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_780(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(781=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_781(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(782=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_782(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(783=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_783(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(784=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_784(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(785=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_785(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(786=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_786(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(Other, _, _, _, _, _, _) ->
 erlang:error({yecc_bug,"1.2",{missing_state_in_action_table, Other}}).

yeccpars2_0(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_0(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_0_(Stack),
 yeccpars2(1, Cat, [0 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_1(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 5, Ss, Stack, T, Ts, Tzr);
yeccpars2_1(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_1_(Stack),
 yeccpars2(4, Cat, [1 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_2(_S, '$end', _Ss, Stack,  _T, _Ts, _Tzr) ->
 {ok, hd(Stack)}.

yeccpars2_3(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_3_(Stack),
 yeccpars2(yeccgoto_optSep(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_4(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_5(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 6, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_6: see yeccpars2_4

yeccpars2_7(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 102, Ss, Stack, T, Ts, Tzr).

yeccpars2_8(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_8_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_9(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_9_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_10(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_10_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_11(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_11_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_12(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_12_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_13(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_13_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_14(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_14_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_15(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_15_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_16(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_16_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_17(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_17_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_18(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_18_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_19(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_19_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_20(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_20_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_21(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_21_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_22(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_22_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_23(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_23_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_24(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_24_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_25(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_25_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_26(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_26_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_27(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_27_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_28(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_28_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_29(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_29_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_30(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_30_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_31(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_31_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_32(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_32_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_33(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_33_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_34(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_34_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_35(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_35_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_36(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_36_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_37(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_37_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_38(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_38_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_39(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_39_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_40(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_40_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_41(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_41_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_42(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_42_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_43(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_43_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_44(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_44_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_45(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_45_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_46(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_46_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_47(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_47_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_48(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_48_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_49(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_49_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_50(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_50_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_51(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_51_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_52(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_52_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_53(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_53_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_54(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_54_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_55(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_55_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_56(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_56_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_57(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_57_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_58(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_58_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_59(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_59_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_60(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_60_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_61(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_61_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_62(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_62_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_63(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_63_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_64(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_64_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_65(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_65_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_66(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_66_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_67(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_67_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_68(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_68_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_69(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_69_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_70(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_70_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_71(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_71_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_72(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_72_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_73(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_73_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_74(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_74_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_75(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_75_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_76(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_76_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_77(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_77_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_78(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_78_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_79(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_79_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_80(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_80_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_81(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_81_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_82(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_82_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_83(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_83_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_84(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_84_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_85(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_85_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_86(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_86_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_87(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_87_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_88(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_88_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_89(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_89_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_90(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_90_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_91(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_91_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_92(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_92_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_93(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_93_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_94(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_94_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_95(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_95_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_96(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_96_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_97(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_97_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_98(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_98_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_99(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_99_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_100(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_100_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_101(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_101_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_102: see yeccpars2_4

yeccpars2_103(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 104, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_104: see yeccpars2_4

yeccpars2_105(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_105(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_105_(Stack),
 yeccpars2(106, Cat, [105 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_106(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_106_(Stack),
 Nss = lists:nthtail(7, Ss),
 yeccpars2(yeccgoto_authenticationHeader(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_107(S, 'LESSER', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 114, Ss, Stack, T, Ts, Tzr);
yeccpars2_107(S, 'LSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 115, Ss, Stack, T, Ts, Tzr);
yeccpars2_107(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_107(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_107_(Stack),
 yeccpars2(110, Cat, [107 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_108(S, endOfMessage, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 109, Ss, Stack, T, Ts, Tzr).

yeccpars2_109(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_109_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_megacoMessage(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_110(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'MtpAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 784, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_110(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_111(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 139, Ss, Stack, T, Ts, Tzr);
yeccpars2_111(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 140, Ss, Stack, T, Ts, Tzr);
yeccpars2_111(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 141, Ss, Stack, T, Ts, Tzr);
yeccpars2_111(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 142, Ss, Stack, T, Ts, Tzr);
yeccpars2_111(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 143, Ss, Stack, T, Ts, Tzr).

yeccpars2_112(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_mId(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_113(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_mId(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_114: see yeccpars2_4

yeccpars2_115(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 118, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_115_(Stack),
 yeccpars2(117, Cat, [115 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_116(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 118, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_116(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_116_(Stack),
 yeccpars2(125, Cat, [116 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_117(S, 'RSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 120, Ss, Stack, T, Ts, Tzr).

yeccpars2_118(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 118, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_118(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_118_(Stack),
 yeccpars2(119, Cat, [118 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_119(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_119_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_daddr(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_120(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 121, Ss, Stack, T, Ts, Tzr);
yeccpars2_120(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_120_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_domainAddress(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_121: see yeccpars2_4

yeccpars2_122(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_122_(Stack),
 yeccpars2(yeccgoto_portNumber(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_123(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_123(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_123_(Stack),
 yeccpars2(124, Cat, [123 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_124(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_124_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_domainAddress(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_125(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_125_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_daddr(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_126(S, 'GREATER', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 127, Ss, Stack, T, Ts, Tzr).

yeccpars2_127(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 128, Ss, Stack, T, Ts, Tzr);
yeccpars2_127(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_127_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_domainName(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_128: see yeccpars2_4

yeccpars2_129(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_129(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_129_(Stack),
 yeccpars2(130, Cat, [129 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_130(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_130_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_domainName(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_131(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_131_(Stack),
 yeccpars2(yeccgoto_transactionItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_132(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_132_(Stack),
 yeccpars2(yeccgoto_transactionItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_133(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_133_(Stack),
 yeccpars2(yeccgoto_transactionItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_134(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_134_(Stack),
 yeccpars2(yeccgoto_transactionItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_135(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_135_(Stack),
 yeccpars2(yeccgoto_messageBody(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_136(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 140, Ss, Stack, T, Ts, Tzr);
yeccpars2_136(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 141, Ss, Stack, T, Ts, Tzr);
yeccpars2_136(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 142, Ss, Stack, T, Ts, Tzr);
yeccpars2_136(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 143, Ss, Stack, T, Ts, Tzr);
yeccpars2_136(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_136_(Stack),
 yeccpars2(yeccgoto_transactionList(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_137(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_137_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_message(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_138(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_138_(Stack),
 yeccpars2(yeccgoto_messageBody(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_139(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 702, Ss, Stack, T, Ts, Tzr).

yeccpars2_140(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 775, Ss, Stack, T, Ts, Tzr).

yeccpars2_141(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 632, Ss, Stack, T, Ts, Tzr).

yeccpars2_142(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 624, Ss, Stack, T, Ts, Tzr).

yeccpars2_143(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 144, Ss, Stack, T, Ts, Tzr);
yeccpars2_143(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 145, Ss, Stack, T, Ts, Tzr).

yeccpars2_144(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 616, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_144(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_145(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 147, Ss, Stack, T, Ts, Tzr).

yeccpars2_146(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 610, Ss, Stack, T, Ts, Tzr);
yeccpars2_146(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_146_(Stack),
 yeccpars2(609, Cat, [146 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_147(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 148, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_148: see yeccpars2_4

yeccpars2_149(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_149_(Stack),
 yeccpars2(yeccgoto_contextID(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_150(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 151, Ss, Stack, T, Ts, Tzr).

yeccpars2_151(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 164, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 165, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 166, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 167, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 168, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 169, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 170, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 171, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 172, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 173, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 174, Ss, Stack, T, Ts, Tzr);
yeccpars2_151(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 175, Ss, Stack, T, Ts, Tzr).

yeccpars2_152(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_152_(Stack),
 yeccpars2(yeccgoto_contextProperty(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_153(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_commandRequest(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_154(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_commandRequest(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_155(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_155_(Stack),
 yeccpars2(yeccgoto_contextProperty(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_156(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_commandRequest(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_157(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_actionRequestItem(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_158(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_actionRequestItem(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_159(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_actionRequestItem(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_160(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_commandRequest(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_161(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 355, Ss, Stack, T, Ts, Tzr).

yeccpars2_162(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_commandRequest(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_163(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 351, Ss, Stack, T, Ts, Tzr);
yeccpars2_163(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_163_(Stack),
 yeccpars2(350, Cat, [163 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_164(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_164_(Stack),
 yeccpars2(yeccgoto_ammToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_165(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 347, Ss, Stack, T, Ts, Tzr).

yeccpars2_166(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 344, Ss, Stack, T, Ts, Tzr).

yeccpars2_167(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 334, Ss, Stack, T, Ts, Tzr).

yeccpars2_168(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_168_(Stack),
 yeccpars2(yeccgoto_contextProperty(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_169(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_169_(Stack),
 yeccpars2(yeccgoto_ammToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_170(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_170_(Stack),
 yeccpars2(yeccgoto_ammToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_171(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 295, Ss, Stack, T, Ts, Tzr).

yeccpars2_172(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 293, Ss, Stack, T, Ts, Tzr).

yeccpars2_173(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 220, Ss, Stack, T, Ts, Tzr).

yeccpars2_174(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 194, Ss, Stack, T, Ts, Tzr).

yeccpars2_175(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 176, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_176: see yeccpars2_4

yeccpars2_177(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 190, Ss, Stack, T, Ts, Tzr);
yeccpars2_177(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_177_(Stack),
 yeccpars2(189, Cat, [177 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_178(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_terminationA(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_179(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 181, Ss, Stack, T, Ts, Tzr).

yeccpars2_180(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_180_(Stack),
 yeccpars2(yeccgoto_terminationID(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_181: see yeccpars2_4

yeccpars2_182(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_terminationB(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_183(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 184, Ss, Stack, T, Ts, Tzr).

yeccpars2_184(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 186, Ss, Stack, T, Ts, Tzr);
yeccpars2_184(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 187, Ss, Stack, T, Ts, Tzr);
yeccpars2_184(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 188, Ss, Stack, T, Ts, Tzr).

yeccpars2_185(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_185_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_topologyTriple(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_186(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_186_(Stack),
 yeccpars2(yeccgoto_topologyDirection(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_187(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_187_(Stack),
 yeccpars2(yeccgoto_topologyDirection(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_188(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_188_(Stack),
 yeccpars2(yeccgoto_topologyDirection(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_189(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 193, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_190: see yeccpars2_4

yeccpars2_191(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 190, Ss, Stack, T, Ts, Tzr);
yeccpars2_191(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_191_(Stack),
 yeccpars2(192, Cat, [191 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_192(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_192_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_topologyTripleList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_193(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_193_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_topologyDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_194: see yeccpars2_4

yeccpars2_195(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 197, Ss, Stack, T, Ts, Tzr);
yeccpars2_195(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_195_(Stack),
 yeccpars2(196, Cat, [195 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_196(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_196_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_subtractRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_197(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 199, Ss, Stack, T, Ts, Tzr).

yeccpars2_198(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 219, Ss, Stack, T, Ts, Tzr).

yeccpars2_199(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 200, Ss, Stack, T, Ts, Tzr).

yeccpars2_200(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 204, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 205, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 206, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 207, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 208, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 209, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 210, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 211, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 212, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 213, Ss, Stack, T, Ts, Tzr);
yeccpars2_200(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_200_(Stack),
 yeccpars2(203, Cat, [200 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_201(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_auditItem(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_202(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 216, Ss, Stack, T, Ts, Tzr);
yeccpars2_202(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_202_(Stack),
 yeccpars2(215, Cat, [202 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_203(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 214, Ss, Stack, T, Ts, Tzr).

yeccpars2_204(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_204_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_205(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_205_(Stack),
 yeccpars2(yeccgoto_auditItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_206(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_206_(Stack),
 yeccpars2(yeccgoto_auditItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_207(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_207_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_208(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_208_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_209(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_209_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_210(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_210_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_211(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_211_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_212(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_212_(Stack),
 yeccpars2(yeccgoto_auditItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_213(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_213_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_214(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_214_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_auditDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_215(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_215_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_auditDescriptorBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_216(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 204, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 205, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 206, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 207, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 208, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 209, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 210, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 211, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 212, Ss, Stack, T, Ts, Tzr);
yeccpars2_216(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 213, Ss, Stack, T, Ts, Tzr).

yeccpars2_217(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 216, Ss, Stack, T, Ts, Tzr);
yeccpars2_217(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_217_(Stack),
 yeccpars2(218, Cat, [217 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_218(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_218_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_auditItemList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_219(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_219_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_optAuditDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_220: see yeccpars2_4

yeccpars2_221(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 222, Ss, Stack, T, Ts, Tzr).

yeccpars2_222(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 224, Ss, Stack, T, Ts, Tzr).

yeccpars2_223(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 292, Ss, Stack, T, Ts, Tzr).

yeccpars2_224(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 225, Ss, Stack, T, Ts, Tzr).

yeccpars2_225(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 238, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 239, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 240, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 241, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 242, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 243, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'TimeStampToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 244, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_225(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 245, Ss, Stack, T, Ts, Tzr).

yeccpars2_226(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_226_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_227(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_227_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_228(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_228_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_229(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_229_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_230(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 288, Ss, Stack, T, Ts, Tzr);
yeccpars2_230(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_230_(Stack),
 yeccpars2(287, Cat, [230 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_231(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_231_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_232(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_232_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_233(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_233_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_234(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_234_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_235(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_235_(Stack),
 yeccpars2(yeccgoto_extensionParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_236(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 264, Ss, Stack, T, Ts, Tzr);
yeccpars2_236(S, 'GREATER', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 265, Ss, Stack, T, Ts, Tzr);
yeccpars2_236(S, 'LESSER', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 266, Ss, Stack, T, Ts, Tzr);
yeccpars2_236(S, 'NEQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 267, Ss, Stack, T, Ts, Tzr).

yeccpars2_237(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_237_(Stack),
 yeccpars2(yeccgoto_serviceChangeParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_238(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 261, Ss, Stack, T, Ts, Tzr);
yeccpars2_238(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_238_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_239(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 259, Ss, Stack, T, Ts, Tzr);
yeccpars2_239(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_239_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_240(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 257, Ss, Stack, T, Ts, Tzr);
yeccpars2_240(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_240_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_241(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 255, Ss, Stack, T, Ts, Tzr);
yeccpars2_241(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_241_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_242(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 251, Ss, Stack, T, Ts, Tzr);
yeccpars2_242(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_242_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_243(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 248, Ss, Stack, T, Ts, Tzr);
yeccpars2_243(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_243_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_244(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_244_(Stack),
 yeccpars2(yeccgoto_timeStamp(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_245(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 246, Ss, Stack, T, Ts, Tzr);
yeccpars2_245(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_245_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_246: see yeccpars2_4

yeccpars2_247(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_247_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeVersion(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_248(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'LESSER', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 114, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'LSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 115, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_248(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_248_(Stack),
 yeccpars2(110, Cat, [248 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_249(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_249_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeAddress(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_250(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_250_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeAddress(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_251(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'QuotedChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 254, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_251(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_252(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_252_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeReason(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_253(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_253_(Stack),
 yeccpars2(yeccgoto_value(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_254(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_254_(Stack),
 yeccpars2(yeccgoto_value(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_255: see yeccpars2_4

yeccpars2_256(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_256_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeProfile(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_257(S, 'LESSER', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 114, Ss, Stack, T, Ts, Tzr);
yeccpars2_257(S, 'LSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 115, Ss, Stack, T, Ts, Tzr);
yeccpars2_257(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_257(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_257_(Stack),
 yeccpars2(110, Cat, [257 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_258(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_258_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeMgcId(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_259: see yeccpars2_4

yeccpars2_260(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_260_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeMethod(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_261: see yeccpars2_4

yeccpars2_262(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_262_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeDelay(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_263(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_263_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_extension(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_264(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 273, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'LSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 274, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'QuotedChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 254, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_264(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_265: see yeccpars2_251

%% yeccpars2_266: see yeccpars2_251

%% yeccpars2_267: see yeccpars2_251

yeccpars2_268(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_268_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_parmValue(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_269(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_269_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_parmValue(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_270(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_270_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_parmValue(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_271(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_271_(Stack),
 yeccpars2(yeccgoto_alternativeValue(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_272(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_272_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_parmValue(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_273: see yeccpars2_251

%% yeccpars2_274: see yeccpars2_251

yeccpars2_275(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 277, Ss, Stack, T, Ts, Tzr);
yeccpars2_275(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 278, Ss, Stack, T, Ts, Tzr);
yeccpars2_275(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_275_(Stack),
 yeccpars2(276, Cat, [275 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_276(S, 'RSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 283, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_277: see yeccpars2_251

%% yeccpars2_278: see yeccpars2_251

yeccpars2_279(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 278, Ss, Stack, T, Ts, Tzr);
yeccpars2_279(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_279_(Stack),
 yeccpars2(280, Cat, [279 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_280(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_280_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_valueList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_281(S, 'RSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 282, Ss, Stack, T, Ts, Tzr).

yeccpars2_282(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_282_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_alternativeValue(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_283(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_283_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_alternativeValue(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_284(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 278, Ss, Stack, T, Ts, Tzr);
yeccpars2_284(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_284_(Stack),
 yeccpars2(285, Cat, [284 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_285(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 286, Ss, Stack, T, Ts, Tzr).

yeccpars2_286(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_286_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_alternativeValue(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_287(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 291, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_288: see yeccpars2_225

yeccpars2_289(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 288, Ss, Stack, T, Ts, Tzr);
yeccpars2_289(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_289_(Stack),
 yeccpars2(290, Cat, [289 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_290(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_290_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeParms(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_291(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_291_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_serviceChangeDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_292(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_292_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_serviceChangeRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_293: see yeccpars2_4

yeccpars2_294(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_294_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_priority(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_295: see yeccpars2_4

yeccpars2_296(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 297, Ss, Stack, T, Ts, Tzr).

yeccpars2_297(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 139, Ss, Stack, T, Ts, Tzr);
yeccpars2_297(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 301, Ss, Stack, T, Ts, Tzr).

yeccpars2_298(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_298_(Stack),
 yeccpars2(yeccgoto_notifyRequestBody(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_299(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 333, Ss, Stack, T, Ts, Tzr).

yeccpars2_300(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_300_(Stack),
 yeccpars2(yeccgoto_notifyRequestBody(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_301(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 302, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_302: see yeccpars2_4

yeccpars2_303(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_303_(Stack),
 yeccpars2(yeccgoto_requestID(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_304(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 305, Ss, Stack, T, Ts, Tzr).

yeccpars2_305(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'TimeStampToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 244, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_305(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_305_(Stack),
 yeccpars2(309, Cat, [305 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_306(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_306(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_306_(Stack),
 yeccpars2(331, Cat, [306 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_307(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_307_(Stack),
 yeccpars2(yeccgoto_pkgdName(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_308(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 319, Ss, Stack, T, Ts, Tzr);
yeccpars2_308(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_308_(Stack),
 yeccpars2(330, Cat, [308 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_309(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_309(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_309_(Stack),
 yeccpars2(316, Cat, [309 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_310(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 312, Ss, Stack, T, Ts, Tzr);
yeccpars2_310(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_310_(Stack),
 yeccpars2(311, Cat, [310 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_311(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 315, Ss, Stack, T, Ts, Tzr).

yeccpars2_312(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'TimeStampToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 244, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_312(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_312_(Stack),
 yeccpars2(309, Cat, [312 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_313(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 312, Ss, Stack, T, Ts, Tzr);
yeccpars2_313(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_313_(Stack),
 yeccpars2(314, Cat, [313 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_314(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_314_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_observedEvents(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_315(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_315_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_observedEventsDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_316: see yeccpars2_4

yeccpars2_317(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 319, Ss, Stack, T, Ts, Tzr);
yeccpars2_317(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_317_(Stack),
 yeccpars2(318, Cat, [317 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_318(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_318_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_observedEvent(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_319: see yeccpars2_4

yeccpars2_320(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_320_(Stack),
 yeccpars2(yeccgoto_eventParameterName(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_321(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 326, Ss, Stack, T, Ts, Tzr);
yeccpars2_321(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_321_(Stack),
 yeccpars2(325, Cat, [321 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_322(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_observedEventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_323: see yeccpars2_236

yeccpars2_324(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_324_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_eventStreamOrOther(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_325(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 329, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_326: see yeccpars2_4

yeccpars2_327(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 326, Ss, Stack, T, Ts, Tzr);
yeccpars2_327(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_327_(Stack),
 yeccpars2(328, Cat, [327 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_328(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_328_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_observedEventParameters(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_329(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_329_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_observedEventBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_330(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_330_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_observedEvent(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_331(S, 'COLON', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 332, Ss, Stack, T, Ts, Tzr).

yeccpars2_332(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_332_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_observedEventTimeStamp(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_333(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_333_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_notifyRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_334(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 336, Ss, Stack, T, Ts, Tzr);
yeccpars2_334(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 337, Ss, Stack, T, Ts, Tzr);
yeccpars2_334(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 338, Ss, Stack, T, Ts, Tzr).

yeccpars2_335(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 340, Ss, Stack, T, Ts, Tzr);
yeccpars2_335(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_335_(Stack),
 yeccpars2(339, Cat, [335 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_336(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_336_(Stack),
 yeccpars2(yeccgoto_contextAuditProperty(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_337(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_337_(Stack),
 yeccpars2(yeccgoto_contextAuditProperty(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_338(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_338_(Stack),
 yeccpars2(yeccgoto_contextAuditProperty(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_339(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 343, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_340: see yeccpars2_334

yeccpars2_341(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 340, Ss, Stack, T, Ts, Tzr);
yeccpars2_341(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_341_(Stack),
 yeccpars2(342, Cat, [341 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_342(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_342_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_contextAuditProperties(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_343(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_343_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_contextAudit(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_344: see yeccpars2_4

yeccpars2_345(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 197, Ss, Stack, T, Ts, Tzr);
yeccpars2_345(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_345_(Stack),
 yeccpars2(346, Cat, [345 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_346(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_346_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_auditRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_347: see yeccpars2_4

yeccpars2_348(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 197, Ss, Stack, T, Ts, Tzr);
yeccpars2_348(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_348_(Stack),
 yeccpars2(349, Cat, [348 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_349(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_349_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_auditRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_350(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 354, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_351: see yeccpars2_151

yeccpars2_352(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 351, Ss, Stack, T, Ts, Tzr);
yeccpars2_352(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_352_(Stack),
 yeccpars2(353, Cat, [352 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_353(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_353_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_actionRequestItems(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_354(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_354_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_actionRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_355: see yeccpars2_4

yeccpars2_356(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 358, Ss, Stack, T, Ts, Tzr);
yeccpars2_356(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_356_(Stack),
 yeccpars2(357, Cat, [356 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_357(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_357_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_ammRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_358(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 199, Ss, Stack, T, Ts, Tzr);
yeccpars2_358(S, 'DigitMapDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 368, Ss, Stack, T, Ts, Tzr);
yeccpars2_358(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 369, Ss, Stack, T, Ts, Tzr);
yeccpars2_358(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 370, Ss, Stack, T, Ts, Tzr);
yeccpars2_358(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 371, Ss, Stack, T, Ts, Tzr);
yeccpars2_358(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 372, Ss, Stack, T, Ts, Tzr);
yeccpars2_358(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 373, Ss, Stack, T, Ts, Tzr);
yeccpars2_358(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 374, Ss, Stack, T, Ts, Tzr).

yeccpars2_359(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_359_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_360(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_360_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_361(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_361_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_362(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_362_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_363(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_363_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_364(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_364_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_365(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_365_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_366(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_366_(Stack),
 yeccpars2(yeccgoto_ammParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_367(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 605, Ss, Stack, T, Ts, Tzr);
yeccpars2_367(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_367_(Stack),
 yeccpars2(604, Cat, [367 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_368(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_368_(Stack),
 yeccpars2(yeccgoto_digitMapDescriptor(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_369(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 596, Ss, Stack, T, Ts, Tzr);
yeccpars2_369(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_369_(Stack),
 yeccpars2(yeccgoto_eventBufferDescriptor(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_370(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 536, Ss, Stack, T, Ts, Tzr);
yeccpars2_370(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_370_(Stack),
 yeccpars2(yeccgoto_eventsDescriptor(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_371(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 466, Ss, Stack, T, Ts, Tzr).

yeccpars2_372(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 445, Ss, Stack, T, Ts, Tzr);
yeccpars2_372(S, 'LSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 446, Ss, Stack, T, Ts, Tzr).

yeccpars2_373(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 434, Ss, Stack, T, Ts, Tzr).

yeccpars2_374(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 375, Ss, Stack, T, Ts, Tzr);
yeccpars2_374(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_374_(Stack),
 yeccpars2(yeccgoto_signalsDescriptor(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_375(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 381, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_375(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_376(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_376_(Stack),
 yeccpars2(yeccgoto_signalParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_377(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 430, Ss, Stack, T, Ts, Tzr);
yeccpars2_377(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_377_(Stack),
 yeccpars2(429, Cat, [377 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_378(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 393, Ss, Stack, T, Ts, Tzr);
yeccpars2_378(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_378_(Stack),
 yeccpars2(yeccgoto_signalRequest(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_379(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_379_(Stack),
 yeccpars2(yeccgoto_signalParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_380(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_signalName(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_381(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 382, Ss, Stack, T, Ts, Tzr);
yeccpars2_381(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_381_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_382: see yeccpars2_4

yeccpars2_383(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 385, Ss, Stack, T, Ts, Tzr).

yeccpars2_384(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_384_(Stack),
 yeccpars2(yeccgoto_signalListId(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_385: see yeccpars2_4

yeccpars2_386(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_signalListParm(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_387(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 389, Ss, Stack, T, Ts, Tzr);
yeccpars2_387(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_387_(Stack),
 yeccpars2(388, Cat, [387 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_388(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 392, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_389: see yeccpars2_4

yeccpars2_390(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 389, Ss, Stack, T, Ts, Tzr);
yeccpars2_390(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_390_(Stack),
 yeccpars2(391, Cat, [390 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_391(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_391_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_signalListParms(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_392(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_392_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_signalList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_393(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 396, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 397, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 398, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 399, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 400, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_393(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_394(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 425, Ss, Stack, T, Ts, Tzr);
yeccpars2_394(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_394_(Stack),
 yeccpars2(424, Cat, [394 | Ss], NewStack, T, Ts, Tzr).

%% yeccpars2_395: see yeccpars2_236

yeccpars2_396(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 421, Ss, Stack, T, Ts, Tzr);
yeccpars2_396(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_396_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_397(_S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_397_COMMA(Stack),
 yeccpars2(yeccgoto_sigParameter(hd(Ss)), 'COMMA', Ss, NewStack, T, Ts, Tzr);
yeccpars2_397(_S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_397_RBRKT(Stack),
 yeccpars2(yeccgoto_sigParameter(hd(Ss)), 'RBRKT', Ss, NewStack, T, Ts, Tzr);
yeccpars2_397(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_397_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_398(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 409, Ss, Stack, T, Ts, Tzr);
yeccpars2_398(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_398_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_399(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 404, Ss, Stack, T, Ts, Tzr);
yeccpars2_399(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_399_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_400(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 401, Ss, Stack, T, Ts, Tzr);
yeccpars2_400(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_400_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_401: see yeccpars2_4

yeccpars2_402(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_402_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_sigParameter(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_403(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_403_(Stack),
 yeccpars2(yeccgoto_streamID(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_404(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 406, Ss, Stack, T, Ts, Tzr);
yeccpars2_404(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 407, Ss, Stack, T, Ts, Tzr);
yeccpars2_404(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 408, Ss, Stack, T, Ts, Tzr).

yeccpars2_405(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_405_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_sigParameter(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_406(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_406_(Stack),
 yeccpars2(yeccgoto_signalType(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_407(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_407_(Stack),
 yeccpars2(yeccgoto_signalType(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_408(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_408_(Stack),
 yeccpars2(yeccgoto_signalType(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_409(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 410, Ss, Stack, T, Ts, Tzr).

yeccpars2_410(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 412, Ss, Stack, T, Ts, Tzr);
yeccpars2_410(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 413, Ss, Stack, T, Ts, Tzr);
yeccpars2_410(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 414, Ss, Stack, T, Ts, Tzr);
yeccpars2_410(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 415, Ss, Stack, T, Ts, Tzr).

yeccpars2_411(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 417, Ss, Stack, T, Ts, Tzr);
yeccpars2_411(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_411_(Stack),
 yeccpars2(416, Cat, [411 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_412(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_412_(Stack),
 yeccpars2(yeccgoto_notificationReason(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_413(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_413_(Stack),
 yeccpars2(yeccgoto_notificationReason(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_414(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_414_(Stack),
 yeccpars2(yeccgoto_notificationReason(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_415(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_415_(Stack),
 yeccpars2(yeccgoto_notificationReason(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_416(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 420, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_417: see yeccpars2_410

yeccpars2_418(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 417, Ss, Stack, T, Ts, Tzr);
yeccpars2_418(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_418_(Stack),
 yeccpars2(419, Cat, [418 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_419(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_419_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_notificationReasons(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_420(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_420_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_sigParameter(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_421: see yeccpars2_4

yeccpars2_422(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_422_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_sigParameter(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_423(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_423_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_sigParameter(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_424(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 428, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_425: see yeccpars2_393

yeccpars2_426(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 425, Ss, Stack, T, Ts, Tzr);
yeccpars2_426(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_426_(Stack),
 yeccpars2(427, Cat, [426 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_427(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_427_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_sigParameters(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_428(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_428_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_signalRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_429(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 433, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_430: see yeccpars2_375

yeccpars2_431(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 430, Ss, Stack, T, Ts, Tzr);
yeccpars2_431(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_431_(Stack),
 yeccpars2(432, Cat, [431 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_432(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_432_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_signalParms(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_433(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_433_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_signalsDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_434: see yeccpars2_4

yeccpars2_435(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_435_(Stack),
 yeccpars2(yeccgoto_muxType(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_436(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 438, Ss, Stack, T, Ts, Tzr).

yeccpars2_437(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_437_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_muxDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_438: see yeccpars2_4

yeccpars2_439(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 441, Ss, Stack, T, Ts, Tzr);
yeccpars2_439(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_439_(Stack),
 yeccpars2(440, Cat, [439 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_440(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 444, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_441: see yeccpars2_4

yeccpars2_442(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 441, Ss, Stack, T, Ts, Tzr);
yeccpars2_442(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_442_(Stack),
 yeccpars2(443, Cat, [442 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_443(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_443_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_terminationIDListRepeat(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_444(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_444_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_terminationIDList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_445: see yeccpars2_4

%% yeccpars2_446: see yeccpars2_4

yeccpars2_447(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_447_(Stack),
 yeccpars2(yeccgoto_modemType(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_448(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 450, Ss, Stack, T, Ts, Tzr);
yeccpars2_448(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_448_(Stack),
 yeccpars2(449, Cat, [448 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_449(S, 'RSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 453, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_450: see yeccpars2_4

yeccpars2_451(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 450, Ss, Stack, T, Ts, Tzr);
yeccpars2_451(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_451_(Stack),
 yeccpars2(452, Cat, [451 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_452(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_452_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_modemTypeList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_453(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 455, Ss, Stack, T, Ts, Tzr);
yeccpars2_453(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_453_(Stack),
 yeccpars2(454, Cat, [453 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_454(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_454_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_modemDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_455: see yeccpars2_4

yeccpars2_456(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 460, Ss, Stack, T, Ts, Tzr);
yeccpars2_456(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_456_(Stack),
 yeccpars2(459, Cat, [456 | Ss], NewStack, T, Ts, Tzr).

%% yeccpars2_457: see yeccpars2_236

yeccpars2_458(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_458_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_propertyParm(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_459(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 463, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_460: see yeccpars2_4

yeccpars2_461(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 460, Ss, Stack, T, Ts, Tzr);
yeccpars2_461(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_461_(Stack),
 yeccpars2(462, Cat, [461 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_462(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_462_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_propertyParms(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_463(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_463_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_optPropertyParms(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_464(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 455, Ss, Stack, T, Ts, Tzr);
yeccpars2_464(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_464_(Stack),
 yeccpars2(465, Cat, [464 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_465(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_465_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_modemDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_466(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 472, Ss, Stack, T, Ts, Tzr);
yeccpars2_466(S, 'LocalDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 473, Ss, Stack, T, Ts, Tzr);
yeccpars2_466(S, 'RemoteDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 474, Ss, Stack, T, Ts, Tzr);
yeccpars2_466(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 475, Ss, Stack, T, Ts, Tzr);
yeccpars2_466(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 476, Ss, Stack, T, Ts, Tzr).

yeccpars2_467(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_467_(Stack),
 yeccpars2(yeccgoto_mediaParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_468(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_468_(Stack),
 yeccpars2(yeccgoto_mediaParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_469(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_469_(Stack),
 yeccpars2(yeccgoto_mediaParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_470(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 532, Ss, Stack, T, Ts, Tzr);
yeccpars2_470(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_470_(Stack),
 yeccpars2(531, Cat, [470 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_471(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_471_(Stack),
 yeccpars2(yeccgoto_streamParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_472(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 507, Ss, Stack, T, Ts, Tzr).

yeccpars2_473(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_473_(Stack),
 yeccpars2(yeccgoto_streamParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_474(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_474_(Stack),
 yeccpars2(yeccgoto_streamParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_475(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 498, Ss, Stack, T, Ts, Tzr).

yeccpars2_476(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 477, Ss, Stack, T, Ts, Tzr).

yeccpars2_477(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 482, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 483, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_477(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_478(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 494, Ss, Stack, T, Ts, Tzr);
yeccpars2_478(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_478_(Stack),
 yeccpars2(493, Cat, [478 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_479(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_479_(Stack),
 yeccpars2(yeccgoto_terminationStateParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_480(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_480_(Stack),
 yeccpars2(yeccgoto_terminationStateParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_481(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_481_(Stack),
 yeccpars2(yeccgoto_terminationStateParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_482(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 489, Ss, Stack, T, Ts, Tzr);
yeccpars2_482(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_482_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_483(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 484, Ss, Stack, T, Ts, Tzr);
yeccpars2_483(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_483_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_484(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 486, Ss, Stack, T, Ts, Tzr);
yeccpars2_484(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 487, Ss, Stack, T, Ts, Tzr);
yeccpars2_484(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 488, Ss, Stack, T, Ts, Tzr).

yeccpars2_485(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_485_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceStates(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_486(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_486_(Stack),
 yeccpars2(yeccgoto_serviceState(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_487(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_487_(Stack),
 yeccpars2(yeccgoto_serviceState(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_488(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_488_(Stack),
 yeccpars2(yeccgoto_serviceState(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_489(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 491, Ss, Stack, T, Ts, Tzr);
yeccpars2_489(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 492, Ss, Stack, T, Ts, Tzr).

yeccpars2_490(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_490_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_eventBufferControl(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_491(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_491_(Stack),
 yeccpars2(yeccgoto_eventBufferControlState(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_492(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_492_(Stack),
 yeccpars2(yeccgoto_eventBufferControlState(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_493(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 497, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_494: see yeccpars2_477

yeccpars2_495(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 494, Ss, Stack, T, Ts, Tzr);
yeccpars2_495(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_495_(Stack),
 yeccpars2(496, Cat, [495 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_496(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_496_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_terminationStateParms(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_497(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_497_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_terminationStateDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_498: see yeccpars2_4

yeccpars2_499(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 500, Ss, Stack, T, Ts, Tzr).

yeccpars2_500(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 472, Ss, Stack, T, Ts, Tzr);
yeccpars2_500(S, 'LocalDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 473, Ss, Stack, T, Ts, Tzr);
yeccpars2_500(S, 'RemoteDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 474, Ss, Stack, T, Ts, Tzr).

yeccpars2_501(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 503, Ss, Stack, T, Ts, Tzr);
yeccpars2_501(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_501_(Stack),
 yeccpars2(502, Cat, [501 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_502(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 506, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_503: see yeccpars2_500

yeccpars2_504(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 503, Ss, Stack, T, Ts, Tzr);
yeccpars2_504(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_504_(Stack),
 yeccpars2(505, Cat, [504 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_505(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_505_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_streamParmList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_506(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_506_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_streamDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_507(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 510, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 511, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 512, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_507(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_508(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_508_(Stack),
 yeccpars2(yeccgoto_localParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_509(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 527, Ss, Stack, T, Ts, Tzr);
yeccpars2_509(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_509_(Stack),
 yeccpars2(526, Cat, [509 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_510(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 519, Ss, Stack, T, Ts, Tzr);
yeccpars2_510(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_510_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_511(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 517, Ss, Stack, T, Ts, Tzr);
yeccpars2_511(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_511_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_512(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 513, Ss, Stack, T, Ts, Tzr);
yeccpars2_512(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_512_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_513(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 515, Ss, Stack, T, Ts, Tzr);
yeccpars2_513(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 516, Ss, Stack, T, Ts, Tzr).

yeccpars2_514(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_514_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_localParm(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_515(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_515_(Stack),
 yeccpars2(yeccgoto_onOrOff(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_516(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_516_(Stack),
 yeccpars2(yeccgoto_onOrOff(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_517: see yeccpars2_513

yeccpars2_518(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_518_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_localParm(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_519(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 521, Ss, Stack, T, Ts, Tzr);
yeccpars2_519(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 522, Ss, Stack, T, Ts, Tzr);
yeccpars2_519(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 523, Ss, Stack, T, Ts, Tzr);
yeccpars2_519(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 524, Ss, Stack, T, Ts, Tzr);
yeccpars2_519(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 525, Ss, Stack, T, Ts, Tzr).

yeccpars2_520(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_520_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_localParm(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_521(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_521_(Stack),
 yeccpars2(yeccgoto_streamModes(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_522(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_522_(Stack),
 yeccpars2(yeccgoto_streamModes(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_523(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_523_(Stack),
 yeccpars2(yeccgoto_streamModes(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_524(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_524_(Stack),
 yeccpars2(yeccgoto_streamModes(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_525(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_525_(Stack),
 yeccpars2(yeccgoto_streamModes(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_526(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 530, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_527: see yeccpars2_507

yeccpars2_528(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 527, Ss, Stack, T, Ts, Tzr);
yeccpars2_528(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_528_(Stack),
 yeccpars2(529, Cat, [528 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_529(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_529_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_localParmList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_530(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_530_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_localControlDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_531(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 535, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_532: see yeccpars2_466

yeccpars2_533(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 532, Ss, Stack, T, Ts, Tzr);
yeccpars2_533(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_533_(Stack),
 yeccpars2(534, Cat, [533 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_534(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_534_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_mediaParmList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_535(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_535_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_mediaDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_536: see yeccpars2_4

yeccpars2_537(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 538, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_538: see yeccpars2_4

yeccpars2_539(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 592, Ss, Stack, T, Ts, Tzr);
yeccpars2_539(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_539_(Stack),
 yeccpars2(591, Cat, [539 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_540(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 542, Ss, Stack, T, Ts, Tzr);
yeccpars2_540(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_540_(Stack),
 yeccpars2(541, Cat, [540 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_541(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_541_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_requestedEvent(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_542(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'DigitMapDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 548, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 549, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 550, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_542(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_543(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_eventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_544(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 587, Ss, Stack, T, Ts, Tzr);
yeccpars2_544(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_544_(Stack),
 yeccpars2(586, Cat, [544 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_545(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_eventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_546(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_eventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_547(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_eventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_548(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_548_(Stack),
 yeccpars2(yeccgoto_eventDM(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_549(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 551, Ss, Stack, T, Ts, Tzr);
yeccpars2_549(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_549_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_550(_S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_550_COMMA(Stack),
 yeccpars2(yeccgoto_eventParameter(hd(Ss)), 'COMMA', Ss, NewStack, T, Ts, Tzr);
yeccpars2_550(_S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_550_RBRKT(Stack),
 yeccpars2(yeccgoto_eventParameter(hd(Ss)), 'RBRKT', Ss, NewStack, T, Ts, Tzr);
yeccpars2_550(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_550_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_551(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 554, Ss, Stack, T, Ts, Tzr);
yeccpars2_551(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 374, Ss, Stack, T, Ts, Tzr).

yeccpars2_552(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 582, Ss, Stack, T, Ts, Tzr);
yeccpars2_552(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 583, Ss, Stack, T, Ts, Tzr).

yeccpars2_553(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 581, Ss, Stack, T, Ts, Tzr).

yeccpars2_554(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 555, Ss, Stack, T, Ts, Tzr);
yeccpars2_554(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_554_(Stack),
 yeccpars2(yeccgoto_embedFirst(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_555: see yeccpars2_4

yeccpars2_556(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 557, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_557: see yeccpars2_4

yeccpars2_558(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 577, Ss, Stack, T, Ts, Tzr);
yeccpars2_558(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_558_(Stack),
 yeccpars2(576, Cat, [558 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_559(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 561, Ss, Stack, T, Ts, Tzr);
yeccpars2_559(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_559_(Stack),
 yeccpars2(560, Cat, [559 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_560(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_560_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_secondRequestedEvent(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_561(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'DigitMapDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 548, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 566, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 567, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_561(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_562(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 572, Ss, Stack, T, Ts, Tzr);
yeccpars2_562(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_562_(Stack),
 yeccpars2(571, Cat, [562 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_563(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_secondEventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_564(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_secondEventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_565(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_secondEventParameter(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_566(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 568, Ss, Stack, T, Ts, Tzr);
yeccpars2_566(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_566_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_567(_S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_567_COMMA(Stack),
 yeccpars2(yeccgoto_secondEventParameter(hd(Ss)), 'COMMA', Ss, NewStack, T, Ts, Tzr);
yeccpars2_567(_S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_567_RBRKT(Stack),
 yeccpars2(yeccgoto_secondEventParameter(hd(Ss)), 'RBRKT', Ss, NewStack, T, Ts, Tzr);
yeccpars2_567(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_567_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_568(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 374, Ss, Stack, T, Ts, Tzr).

yeccpars2_569(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 570, Ss, Stack, T, Ts, Tzr).

yeccpars2_570(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_570_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_embedSig(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_571(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 575, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_572: see yeccpars2_561

yeccpars2_573(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 572, Ss, Stack, T, Ts, Tzr);
yeccpars2_573(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_573_(Stack),
 yeccpars2(574, Cat, [573 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_574(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_574_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_secondEventParameters(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_575(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_575_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_secondRequestedEventBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_576(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 580, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_577: see yeccpars2_4

yeccpars2_578(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 577, Ss, Stack, T, Ts, Tzr);
yeccpars2_578(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_578_(Stack),
 yeccpars2(579, Cat, [578 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_579(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_579_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_secondRequestedEvents(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_580(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_580_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_embedFirst(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_581(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_581_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_embedNoSig(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_582(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 554, Ss, Stack, T, Ts, Tzr).

yeccpars2_583(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_583_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_embedWithSig(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_584(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 585, Ss, Stack, T, Ts, Tzr).

yeccpars2_585(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_585_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_embedWithSig(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_586(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 590, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_587: see yeccpars2_542

yeccpars2_588(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 587, Ss, Stack, T, Ts, Tzr);
yeccpars2_588(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_588_(Stack),
 yeccpars2(589, Cat, [588 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_589(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_589_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_eventParameters(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_590(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_590_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_requestedEventBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_591(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 595, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_592: see yeccpars2_4

yeccpars2_593(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 592, Ss, Stack, T, Ts, Tzr);
yeccpars2_593(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_593_(Stack),
 yeccpars2(594, Cat, [593 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_594(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_594_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_requestedEvents(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_595(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_595_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_eventsDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_596(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'TimeStampToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 244, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_596(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_596_(Stack),
 yeccpars2(309, Cat, [596 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_597(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_597_(Stack),
 yeccpars2(yeccgoto_eventSpec(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_598(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 600, Ss, Stack, T, Ts, Tzr);
yeccpars2_598(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_598_(Stack),
 yeccpars2(599, Cat, [598 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_599(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 603, Ss, Stack, T, Ts, Tzr).

yeccpars2_600(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'TimeStampToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 244, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr);
yeccpars2_600(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_600_(Stack),
 yeccpars2(309, Cat, [600 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_601(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 600, Ss, Stack, T, Ts, Tzr);
yeccpars2_601(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_601_(Stack),
 yeccpars2(602, Cat, [601 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_602(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_602_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_eventSpecList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_603(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_603_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_eventBufferDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_604(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 608, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_605: see yeccpars2_358

yeccpars2_606(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 605, Ss, Stack, T, Ts, Tzr);
yeccpars2_606(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_606_(Stack),
 yeccpars2(607, Cat, [606 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_607(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_607_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_ammParameters(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_608(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_608_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_ammRequestBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_609(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 613, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_610: see yeccpars2_145

yeccpars2_611(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 610, Ss, Stack, T, Ts, Tzr);
yeccpars2_611(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_611_(Stack),
 yeccpars2(612, Cat, [611 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_612(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_612_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_actionRequestList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_613(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_613_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_transactionRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_614(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 620, Ss, Stack, T, Ts, Tzr).

yeccpars2_615(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_615_(Stack),
 yeccpars2(yeccgoto_transactionID(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_616: see yeccpars2_145

yeccpars2_617(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 610, Ss, Stack, T, Ts, Tzr);
yeccpars2_617(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_617_(Stack),
 yeccpars2(618, Cat, [617 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_618(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 619, Ss, Stack, T, Ts, Tzr).

yeccpars2_619(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_619_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_transactionRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_620: see yeccpars2_145

yeccpars2_621(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 610, Ss, Stack, T, Ts, Tzr);
yeccpars2_621(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_621_(Stack),
 yeccpars2(622, Cat, [621 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_622(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 623, Ss, Stack, T, Ts, Tzr).

yeccpars2_623(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_623_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_transactionRequest(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_624: see yeccpars2_4

yeccpars2_625(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 628, Ss, Stack, T, Ts, Tzr);
yeccpars2_625(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_625_(Stack),
 yeccpars2(627, Cat, [625 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_626(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_626_(Stack),
 yeccpars2(yeccgoto_transactionAck(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_627(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 631, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_628: see yeccpars2_4

yeccpars2_629(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 628, Ss, Stack, T, Ts, Tzr);
yeccpars2_629(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_629_(Stack),
 yeccpars2(630, Cat, [629 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_630(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_630_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_transactionAckList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_631(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_631_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_transactionResponseAck(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_632: see yeccpars2_4

yeccpars2_633(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 634, Ss, Stack, T, Ts, Tzr).

yeccpars2_634(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 636, Ss, Stack, T, Ts, Tzr);
yeccpars2_634(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_634_(Stack),
 yeccpars2(635, Cat, [634 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_635(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 641, Ss, Stack, T, Ts, Tzr);
yeccpars2_635(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 139, Ss, Stack, T, Ts, Tzr).

yeccpars2_636(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 637, Ss, Stack, T, Ts, Tzr).

yeccpars2_637(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_637_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_optImmAckRequired(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_638(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 774, Ss, Stack, T, Ts, Tzr).

yeccpars2_639(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_639_(Stack),
 yeccpars2(yeccgoto_transactionReplyBody(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_640(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 771, Ss, Stack, T, Ts, Tzr);
yeccpars2_640(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_640_(Stack),
 yeccpars2(770, Cat, [640 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_641(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 642, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_642: see yeccpars2_4

yeccpars2_643(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 644, Ss, Stack, T, Ts, Tzr).

yeccpars2_644(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 654, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 655, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 656, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 168, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 139, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 657, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 658, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 659, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 172, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 660, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 661, Ss, Stack, T, Ts, Tzr);
yeccpars2_644(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 175, Ss, Stack, T, Ts, Tzr).

yeccpars2_645(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_645_(Stack),
 yeccpars2(yeccgoto_commandReply(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_646(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_646_(Stack),
 yeccpars2(yeccgoto_commandReply(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_647(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_647_(Stack),
 yeccpars2(yeccgoto_actionReplyBody(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_648(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_648_(Stack),
 yeccpars2(yeccgoto_commandReply(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_649(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 766, Ss, Stack, T, Ts, Tzr);
yeccpars2_649(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_649_(Stack),
 yeccpars2(765, Cat, [649 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_650(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_650_(Stack),
 yeccpars2(yeccgoto_commandReply(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_651(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 759, Ss, Stack, T, Ts, Tzr).

yeccpars2_652(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_652_(Stack),
 yeccpars2(yeccgoto_commandReply(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_653(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 758, Ss, Stack, T, Ts, Tzr).

yeccpars2_654(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_654_(Stack),
 yeccpars2(yeccgoto_ammsToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_655(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 754, Ss, Stack, T, Ts, Tzr).

yeccpars2_656(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 693, Ss, Stack, T, Ts, Tzr).

yeccpars2_657(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_657_(Stack),
 yeccpars2(yeccgoto_ammsToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_658(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_658_(Stack),
 yeccpars2(yeccgoto_ammsToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_659(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 687, Ss, Stack, T, Ts, Tzr).

yeccpars2_660(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 662, Ss, Stack, T, Ts, Tzr).

yeccpars2_661(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_661_(Stack),
 yeccpars2(yeccgoto_ammsToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_662: see yeccpars2_4

yeccpars2_663(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 665, Ss, Stack, T, Ts, Tzr);
yeccpars2_663(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_663_(Stack),
 yeccpars2(664, Cat, [663 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_664(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_664_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_serviceChangeReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_665(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 139, Ss, Stack, T, Ts, Tzr);
yeccpars2_665(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 668, Ss, Stack, T, Ts, Tzr).

yeccpars2_666(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 686, Ss, Stack, T, Ts, Tzr).

yeccpars2_667(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 685, Ss, Stack, T, Ts, Tzr).

yeccpars2_668(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 669, Ss, Stack, T, Ts, Tzr).

yeccpars2_669(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 676, Ss, Stack, T, Ts, Tzr);
yeccpars2_669(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 677, Ss, Stack, T, Ts, Tzr);
yeccpars2_669(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 678, Ss, Stack, T, Ts, Tzr);
yeccpars2_669(S, 'TimeStampToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 244, Ss, Stack, T, Ts, Tzr);
yeccpars2_669(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 679, Ss, Stack, T, Ts, Tzr).

yeccpars2_670(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_670_(Stack),
 yeccpars2(yeccgoto_servChgReplyParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_671(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_671_(Stack),
 yeccpars2(yeccgoto_servChgReplyParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_672(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_672_(Stack),
 yeccpars2(yeccgoto_servChgReplyParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_673(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_673_(Stack),
 yeccpars2(yeccgoto_servChgReplyParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_674(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_674_(Stack),
 yeccpars2(yeccgoto_servChgReplyParm(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_675(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 681, Ss, Stack, T, Ts, Tzr);
yeccpars2_675(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_675_(Stack),
 yeccpars2(680, Cat, [675 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_676(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 257, Ss, Stack, T, Ts, Tzr).

yeccpars2_677(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 255, Ss, Stack, T, Ts, Tzr).

yeccpars2_678(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 248, Ss, Stack, T, Ts, Tzr).

yeccpars2_679(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 246, Ss, Stack, T, Ts, Tzr).

yeccpars2_680(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 684, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_681: see yeccpars2_669

yeccpars2_682(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 681, Ss, Stack, T, Ts, Tzr);
yeccpars2_682(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_682_(Stack),
 yeccpars2(683, Cat, [682 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_683(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_683_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_servChgReplyParms(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_684(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_684_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_serviceChangeReplyDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_685(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_685_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeReplyBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_686(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_686_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_serviceChangeReplyBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_687: see yeccpars2_4

yeccpars2_688(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 690, Ss, Stack, T, Ts, Tzr);
yeccpars2_688(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_688_(Stack),
 yeccpars2(689, Cat, [688 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_689(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_689_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_notifyReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_690(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 139, Ss, Stack, T, Ts, Tzr).

yeccpars2_691(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 692, Ss, Stack, T, Ts, Tzr).

yeccpars2_692(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_692_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_notifyReplyBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_693(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 696, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_693(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_694(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 710, Ss, Stack, T, Ts, Tzr);
yeccpars2_694(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_694_(Stack),
 yeccpars2(yeccgoto_auditOther(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_695(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_695_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_auditReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_696(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 699, Ss, Stack, T, Ts, Tzr);
yeccpars2_696(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_696_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_697(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_697_(Stack),
 yeccpars2(yeccgoto_contextTerminationAudit(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_698(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_698_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_auditReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_699(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 17, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 701, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_699(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_700(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 709, Ss, Stack, T, Ts, Tzr).

yeccpars2_701(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 702, Ss, Stack, T, Ts, Tzr);
yeccpars2_701(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_701_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_702: see yeccpars2_4

yeccpars2_703(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_703_(Stack),
 yeccpars2(yeccgoto_errorCode(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_704(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 705, Ss, Stack, T, Ts, Tzr).

yeccpars2_705(S, 'QuotedChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 707, Ss, Stack, T, Ts, Tzr);
yeccpars2_705(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_705_(Stack),
 yeccpars2(706, Cat, [705 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_706(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 708, Ss, Stack, T, Ts, Tzr).

yeccpars2_707(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_707_(Stack),
 yeccpars2(yeccgoto_errorText(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_708(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_708_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_errorDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_709(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_709_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_contextTerminationAudit(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_710(S, 'DigitMapDescriptorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 368, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 204, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 139, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 369, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 370, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 725, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 726, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 727, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 728, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 729, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 374, Ss, Stack, T, Ts, Tzr);
yeccpars2_710(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 730, Ss, Stack, T, Ts, Tzr).

yeccpars2_711(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 753, Ss, Stack, T, Ts, Tzr).

yeccpars2_712(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_712_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_713(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_713_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_714(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_714_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_715(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_715_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_716(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_716_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_717(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_717_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_718(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_718_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_719(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_719_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_720(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_720_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_721(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_721_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_722(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_722_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_723(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 750, Ss, Stack, T, Ts, Tzr);
yeccpars2_723(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_723_(Stack),
 yeccpars2(749, Cat, [723 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_724(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_724_(Stack),
 yeccpars2(yeccgoto_auditReturnParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_725(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 466, Ss, Stack, T, Ts, Tzr);
yeccpars2_725(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_725_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_726(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 445, Ss, Stack, T, Ts, Tzr);
yeccpars2_726(S, 'LSBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 446, Ss, Stack, T, Ts, Tzr);
yeccpars2_726(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_726_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_727(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 434, Ss, Stack, T, Ts, Tzr);
yeccpars2_727(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_727_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_728(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 302, Ss, Stack, T, Ts, Tzr);
yeccpars2_728(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_728_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_729(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 741, Ss, Stack, T, Ts, Tzr);
yeccpars2_729(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_729_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_730(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 731, Ss, Stack, T, Ts, Tzr);
yeccpars2_730(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_730_(Stack),
 yeccpars2(yeccgoto_auditReturnItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_731: see yeccpars2_4

yeccpars2_732(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 737, Ss, Stack, T, Ts, Tzr);
yeccpars2_732(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_732_(Stack),
 yeccpars2(736, Cat, [732 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_733(S, 'EQUAL', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 734, Ss, Stack, T, Ts, Tzr);
yeccpars2_733(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_733_(Stack),
 yeccpars2(yeccgoto_statisticsParameter(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_734: see yeccpars2_251

yeccpars2_735(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_735_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_statisticsParameter(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_736(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 740, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_737: see yeccpars2_4

yeccpars2_738(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 737, Ss, Stack, T, Ts, Tzr);
yeccpars2_738(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_738_(Stack),
 yeccpars2(739, Cat, [738 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_739(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_739_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_statisticsParameters(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_740(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_740_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_statisticsDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_741: see yeccpars2_4

yeccpars2_742(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_742_(Stack),
 yeccpars2(yeccgoto_packagesItem(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_743(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 745, Ss, Stack, T, Ts, Tzr);
yeccpars2_743(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_743_(Stack),
 yeccpars2(744, Cat, [743 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_744(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 748, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_745: see yeccpars2_4

yeccpars2_746(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 745, Ss, Stack, T, Ts, Tzr);
yeccpars2_746(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_746_(Stack),
 yeccpars2(747, Cat, [746 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_747(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_747_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_packagesItems(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_748(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_748_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_packagesDescriptor(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_749(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_749_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_terminationAudit(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_750: see yeccpars2_710

yeccpars2_751(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 750, Ss, Stack, T, Ts, Tzr);
yeccpars2_751(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_751_(Stack),
 yeccpars2(752, Cat, [751 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_752(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_752_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_auditReturnParameterList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_753(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_753_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_auditOther(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_754(S, 'AddToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 8, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'AuditCapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'AuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 10, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'AuditValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'AuthToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'BothwayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'BriefToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'BufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ContextAuditToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 16, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 756, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'DelayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'DigitMapToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'DiscardToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 20, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'DisconnectedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 21, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'DurationToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'EmbedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'EmergencyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ErrorToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'EventBufferToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 26, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'EventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 27, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'FailoverToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 28, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ForcedToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 29, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'GracefulToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 30, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'H221Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 31, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'H223Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 32, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'H226Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'HandOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ImmAckRequiredToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'InSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'InactiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'InterruptByEventToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'InterruptByNewSignalsDescrToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'IsolateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'KeepActiveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'LocalControlToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 42, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'LockStepToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 43, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'LoopbackToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'MediaToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'MethodToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'MgcIdToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 47, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ModeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ModemToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 49, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ModifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'MoveToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'MuxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'NotifyCompletionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 53, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'NotifyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 54, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ObservedEventsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 55, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'OffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 56, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'OnOffToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'OnToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'OnewayToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'OtherReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'OutOfSvcToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 61, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'PackagesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'PendingToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'PriorityToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ProfileToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ReasonToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 66, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'RecvonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ReplyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 68, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ReservedGroupToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ReservedValueToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ResponseAckToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'RestartToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SafeChars', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 73, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SendonlyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 74, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SendrecvToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ServiceChangeAddressToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ServiceChangeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ServiceStatesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 78, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'ServicesToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SignalListToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SignalTypeToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 81, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SignalsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'StatsToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'StreamToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SubtractToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 85, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'SynchISDNToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'TerminationStateToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 87, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'TestToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 88, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'TimeOutToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'TopologyToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 90, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'TransToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 91, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V18Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 92, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V22Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 93, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V22bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 94, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V32Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 95, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V32bisToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 96, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V34Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 97, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V76Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 98, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V90Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 99, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'V91Token', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 100, Ss, Stack, T, Ts, Tzr);
yeccpars2_754(S, 'VersionToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 101, Ss, Stack, T, Ts, Tzr).

yeccpars2_755(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_755_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_auditReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_756(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 699, Ss, Stack, T, Ts, Tzr);
yeccpars2_756(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_756_(Stack),
 yeccpars2(yeccgoto_safeToken(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_757(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_757_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_auditReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_758(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_758_(Stack),
 Nss = lists:nthtail(5, Ss),
 yeccpars2(yeccgoto_actionReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_759: see yeccpars2_4

yeccpars2_760(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 762, Ss, Stack, T, Ts, Tzr);
yeccpars2_760(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_760_(Stack),
 yeccpars2(761, Cat, [760 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_761(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_761_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_ammsReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_762: see yeccpars2_710

yeccpars2_763(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 764, Ss, Stack, T, Ts, Tzr).

yeccpars2_764(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_764_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_ammsReplyBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_765(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_765_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_actionReplyBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_766: see yeccpars2_644

yeccpars2_767(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_767_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_commandReplyList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_768(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 766, Ss, Stack, T, Ts, Tzr);
yeccpars2_768(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_768_(Stack),
 yeccpars2(769, Cat, [768 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_769(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_769_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_commandReplyList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_770(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_770_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_transactionReplyBody(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_771(S, 'CtxToken', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 641, Ss, Stack, T, Ts, Tzr).

yeccpars2_772(S, 'COMMA', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 771, Ss, Stack, T, Ts, Tzr);
yeccpars2_772(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_772_(Stack),
 yeccpars2(773, Cat, [772 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_773(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_773_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_actionReplyList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_774(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_774_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_transactionReply(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_775: see yeccpars2_4

yeccpars2_776(S, 'LBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 777, Ss, Stack, T, Ts, Tzr).

yeccpars2_777(S, 'RBRKT', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 778, Ss, Stack, T, Ts, Tzr).

yeccpars2_778(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_778_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_transactionPending(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_779(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_779_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_transactionList(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_780(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_780_(Stack),
 yeccpars2(yeccgoto_pathName(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_781(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_781_(Stack),
 yeccpars2(yeccgoto_deviceName(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_782(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_782(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_782_(Stack),
 yeccpars2(786, Cat, [782 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_783(S, 'SEP', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_783(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_783_(Stack),
 yeccpars2(785, Cat, [783 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_784(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_784_(Stack),
 yeccpars2(yeccgoto_mtpAddress(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_785(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_785_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_mId(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_786(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_786_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_mId(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccgoto_actionReply(635) -> 640;
yeccgoto_actionReply(771) -> 772.

yeccgoto_actionReplyBody(644) -> 653.

yeccgoto_actionReplyList(640) -> 770;
yeccgoto_actionReplyList(772) -> 773.

yeccgoto_actionRequest(145) -> 146;
yeccgoto_actionRequest(610) -> 611;
yeccgoto_actionRequest(616) -> 617;
yeccgoto_actionRequest(620) -> 621.

yeccgoto_actionRequestItem(151) -> 163;
yeccgoto_actionRequestItem(351) -> 352.

yeccgoto_actionRequestItems(163) -> 350;
yeccgoto_actionRequestItems(352) -> 353.

yeccgoto_actionRequestList(146) -> 609;
yeccgoto_actionRequestList(611) -> 612;
yeccgoto_actionRequestList(617) -> 618;
yeccgoto_actionRequestList(621) -> 622.

yeccgoto_alternativeValue(264) -> 272.

yeccgoto_ammParameter(358) -> 367;
yeccgoto_ammParameter(605) -> 606.

yeccgoto_ammParameters(367) -> 604;
yeccgoto_ammParameters(606) -> 607.

yeccgoto_ammRequest(151) -> 162;
yeccgoto_ammRequest(351) -> 162.

yeccgoto_ammRequestBody(356) -> 357.

yeccgoto_ammToken(151) -> 161;
yeccgoto_ammToken(351) -> 161.

yeccgoto_ammsReply(644) -> 652;
yeccgoto_ammsReply(766) -> 652.

yeccgoto_ammsReplyBody(760) -> 761.

yeccgoto_ammsToken(644) -> 651;
yeccgoto_ammsToken(766) -> 651.

yeccgoto_auditDescriptor(197) -> 198;
yeccgoto_auditDescriptor(358) -> 366;
yeccgoto_auditDescriptor(605) -> 366.

yeccgoto_auditDescriptorBody(200) -> 203.

yeccgoto_auditItem(200) -> 202;
yeccgoto_auditItem(216) -> 217.

yeccgoto_auditItemList(202) -> 215;
yeccgoto_auditItemList(217) -> 218.

yeccgoto_auditOther(693) -> 695;
yeccgoto_auditOther(754) -> 755.

yeccgoto_auditReply(644) -> 650;
yeccgoto_auditReply(766) -> 650.

yeccgoto_auditRequest(151) -> 160;
yeccgoto_auditRequest(351) -> 160.

yeccgoto_auditReturnItem(200) -> 201;
yeccgoto_auditReturnItem(216) -> 201;
yeccgoto_auditReturnItem(710) -> 724;
yeccgoto_auditReturnItem(750) -> 724;
yeccgoto_auditReturnItem(762) -> 724.

yeccgoto_auditReturnParameter(710) -> 723;
yeccgoto_auditReturnParameter(750) -> 751;
yeccgoto_auditReturnParameter(762) -> 723.

yeccgoto_auditReturnParameterList(723) -> 749;
yeccgoto_auditReturnParameterList(751) -> 752.

yeccgoto_authenticationHeader(1) -> 4.

yeccgoto_commandReply(644) -> 649;
yeccgoto_commandReply(766) -> 768.

yeccgoto_commandReplyList(649) -> 765;
yeccgoto_commandReplyList(768) -> 769.

yeccgoto_commandRequest(151) -> 159;
yeccgoto_commandRequest(351) -> 159.

yeccgoto_contextAudit(151) -> 158;
yeccgoto_contextAudit(351) -> 158.

yeccgoto_contextAuditProperties(335) -> 339;
yeccgoto_contextAuditProperties(341) -> 342.

yeccgoto_contextAuditProperty(334) -> 335;
yeccgoto_contextAuditProperty(340) -> 341.

yeccgoto_contextID(148) -> 150;
yeccgoto_contextID(642) -> 643.

yeccgoto_contextProperty(151) -> 157;
yeccgoto_contextProperty(351) -> 157;
yeccgoto_contextProperty(644) -> 648;
yeccgoto_contextProperty(766) -> 648.

yeccgoto_contextTerminationAudit(696) -> 698;
yeccgoto_contextTerminationAudit(756) -> 757.

yeccgoto_daddr(115) -> 117;
yeccgoto_daddr(116) -> 125;
yeccgoto_daddr(118) -> 119.

yeccgoto_deviceName(110) -> 783.

yeccgoto_digitMapDescriptor(358) -> 365;
yeccgoto_digitMapDescriptor(605) -> 365;
yeccgoto_digitMapDescriptor(710) -> 722;
yeccgoto_digitMapDescriptor(750) -> 722;
yeccgoto_digitMapDescriptor(762) -> 722.

yeccgoto_domainAddress(107) -> 113;
yeccgoto_domainAddress(248) -> 113;
yeccgoto_domainAddress(257) -> 113.

yeccgoto_domainName(107) -> 112;
yeccgoto_domainName(248) -> 112;
yeccgoto_domainName(257) -> 112.

yeccgoto_embedFirst(551) -> 553;
yeccgoto_embedFirst(582) -> 584.

yeccgoto_embedNoSig(542) -> 547;
yeccgoto_embedNoSig(587) -> 547.

yeccgoto_embedSig(561) -> 565;
yeccgoto_embedSig(572) -> 565.

yeccgoto_embedWithSig(542) -> 546;
yeccgoto_embedWithSig(587) -> 546.

yeccgoto_errorCode(702) -> 704.

yeccgoto_errorDescriptor(111) -> 138;
yeccgoto_errorDescriptor(297) -> 300;
yeccgoto_errorDescriptor(635) -> 639;
yeccgoto_errorDescriptor(644) -> 647;
yeccgoto_errorDescriptor(665) -> 667;
yeccgoto_errorDescriptor(690) -> 691;
yeccgoto_errorDescriptor(699) -> 700;
yeccgoto_errorDescriptor(710) -> 721;
yeccgoto_errorDescriptor(750) -> 721;
yeccgoto_errorDescriptor(762) -> 721;
yeccgoto_errorDescriptor(766) -> 767.

yeccgoto_errorText(705) -> 706.

yeccgoto_eventBufferControl(477) -> 481;
yeccgoto_eventBufferControl(494) -> 481.

yeccgoto_eventBufferControlState(489) -> 490.

yeccgoto_eventBufferDescriptor(358) -> 364;
yeccgoto_eventBufferDescriptor(605) -> 364;
yeccgoto_eventBufferDescriptor(710) -> 720;
yeccgoto_eventBufferDescriptor(750) -> 720;
yeccgoto_eventBufferDescriptor(762) -> 720.

yeccgoto_eventDM(542) -> 545;
yeccgoto_eventDM(561) -> 564;
yeccgoto_eventDM(572) -> 564;
yeccgoto_eventDM(587) -> 545.

yeccgoto_eventParameter(542) -> 544;
yeccgoto_eventParameter(587) -> 588.

yeccgoto_eventParameterName(319) -> 323;
yeccgoto_eventParameterName(326) -> 323;
yeccgoto_eventParameterName(542) -> 323;
yeccgoto_eventParameterName(561) -> 323;
yeccgoto_eventParameterName(572) -> 323;
yeccgoto_eventParameterName(587) -> 323.

yeccgoto_eventParameters(544) -> 586;
yeccgoto_eventParameters(588) -> 589.

yeccgoto_eventSpec(596) -> 598;
yeccgoto_eventSpec(600) -> 601.

yeccgoto_eventSpecList(598) -> 599;
yeccgoto_eventSpecList(601) -> 602.

yeccgoto_eventStreamOrOther(319) -> 322;
yeccgoto_eventStreamOrOther(326) -> 322;
yeccgoto_eventStreamOrOther(542) -> 543;
yeccgoto_eventStreamOrOther(561) -> 563;
yeccgoto_eventStreamOrOther(572) -> 563;
yeccgoto_eventStreamOrOther(587) -> 543.

yeccgoto_eventsDescriptor(358) -> 363;
yeccgoto_eventsDescriptor(605) -> 363;
yeccgoto_eventsDescriptor(710) -> 719;
yeccgoto_eventsDescriptor(750) -> 719;
yeccgoto_eventsDescriptor(762) -> 719.

yeccgoto_extension(225) -> 237;
yeccgoto_extension(288) -> 237.

yeccgoto_extensionParameter(225) -> 236;
yeccgoto_extensionParameter(288) -> 236.

yeccgoto_localControlDescriptor(466) -> 471;
yeccgoto_localControlDescriptor(500) -> 471;
yeccgoto_localControlDescriptor(503) -> 471;
yeccgoto_localControlDescriptor(532) -> 471.

yeccgoto_localParm(507) -> 509;
yeccgoto_localParm(527) -> 528.

yeccgoto_localParmList(509) -> 526;
yeccgoto_localParmList(528) -> 529.

yeccgoto_mId(107) -> 111;
yeccgoto_mId(248) -> 250;
yeccgoto_mId(257) -> 258.

yeccgoto_mediaDescriptor(358) -> 362;
yeccgoto_mediaDescriptor(605) -> 362;
yeccgoto_mediaDescriptor(710) -> 718;
yeccgoto_mediaDescriptor(750) -> 718;
yeccgoto_mediaDescriptor(762) -> 718.

yeccgoto_mediaParm(466) -> 470;
yeccgoto_mediaParm(532) -> 533.

yeccgoto_mediaParmList(470) -> 531;
yeccgoto_mediaParmList(533) -> 534.

yeccgoto_megacoMessage(0) -> 2.

yeccgoto_message(4) -> 108.

yeccgoto_messageBody(111) -> 137.

yeccgoto_modemDescriptor(358) -> 361;
yeccgoto_modemDescriptor(605) -> 361;
yeccgoto_modemDescriptor(710) -> 717;
yeccgoto_modemDescriptor(750) -> 717;
yeccgoto_modemDescriptor(762) -> 717.

yeccgoto_modemType(445) -> 464;
yeccgoto_modemType(446) -> 448;
yeccgoto_modemType(450) -> 451.

yeccgoto_modemTypeList(448) -> 449;
yeccgoto_modemTypeList(451) -> 452.

yeccgoto_mtpAddress(110) -> 782.

yeccgoto_muxDescriptor(358) -> 360;
yeccgoto_muxDescriptor(605) -> 360;
yeccgoto_muxDescriptor(710) -> 716;
yeccgoto_muxDescriptor(750) -> 716;
yeccgoto_muxDescriptor(762) -> 716.

yeccgoto_muxType(434) -> 436.

yeccgoto_notificationReason(410) -> 411;
yeccgoto_notificationReason(417) -> 418.

yeccgoto_notificationReasons(411) -> 416;
yeccgoto_notificationReasons(418) -> 419.

yeccgoto_notifyReply(644) -> 646;
yeccgoto_notifyReply(766) -> 646.

yeccgoto_notifyReplyBody(688) -> 689.

yeccgoto_notifyRequest(151) -> 156;
yeccgoto_notifyRequest(351) -> 156.

yeccgoto_notifyRequestBody(297) -> 299.

yeccgoto_observedEvent(305) -> 310;
yeccgoto_observedEvent(312) -> 313;
yeccgoto_observedEvent(596) -> 597;
yeccgoto_observedEvent(600) -> 597.

yeccgoto_observedEventBody(308) -> 330;
yeccgoto_observedEventBody(317) -> 318.

yeccgoto_observedEventParameter(319) -> 321;
yeccgoto_observedEventParameter(326) -> 327.

yeccgoto_observedEventParameters(321) -> 325;
yeccgoto_observedEventParameters(327) -> 328.

yeccgoto_observedEventTimeStamp(305) -> 309;
yeccgoto_observedEventTimeStamp(312) -> 309;
yeccgoto_observedEventTimeStamp(596) -> 309;
yeccgoto_observedEventTimeStamp(600) -> 309.

yeccgoto_observedEvents(310) -> 311;
yeccgoto_observedEvents(313) -> 314.

yeccgoto_observedEventsDescriptor(297) -> 298;
yeccgoto_observedEventsDescriptor(710) -> 715;
yeccgoto_observedEventsDescriptor(750) -> 715;
yeccgoto_observedEventsDescriptor(762) -> 715.

yeccgoto_onOrOff(513) -> 514;
yeccgoto_onOrOff(517) -> 518.

yeccgoto_optAuditDescriptor(195) -> 196;
yeccgoto_optAuditDescriptor(345) -> 346;
yeccgoto_optAuditDescriptor(348) -> 349.

yeccgoto_optImmAckRequired(634) -> 635.

yeccgoto_optPropertyParms(453) -> 454;
yeccgoto_optPropertyParms(464) -> 465.

yeccgoto_optSep(0) -> 1;
yeccgoto_optSep(105) -> 106;
yeccgoto_optSep(107) -> 110;
yeccgoto_optSep(123) -> 124;
yeccgoto_optSep(129) -> 130;
yeccgoto_optSep(248) -> 110;
yeccgoto_optSep(257) -> 110;
yeccgoto_optSep(306) -> 331;
yeccgoto_optSep(309) -> 316;
yeccgoto_optSep(782) -> 786;
yeccgoto_optSep(783) -> 785.

yeccgoto_packagesDescriptor(710) -> 714;
yeccgoto_packagesDescriptor(750) -> 714;
yeccgoto_packagesDescriptor(762) -> 714.

yeccgoto_packagesItem(741) -> 743;
yeccgoto_packagesItem(745) -> 746.

yeccgoto_packagesItems(743) -> 744;
yeccgoto_packagesItems(746) -> 747.

yeccgoto_parmValue(236) -> 263;
yeccgoto_parmValue(323) -> 324;
yeccgoto_parmValue(395) -> 423;
yeccgoto_parmValue(457) -> 458.

yeccgoto_pathName(110) -> 781.

yeccgoto_pkgdName(305) -> 308;
yeccgoto_pkgdName(312) -> 308;
yeccgoto_pkgdName(316) -> 317;
yeccgoto_pkgdName(375) -> 380;
yeccgoto_pkgdName(385) -> 380;
yeccgoto_pkgdName(389) -> 380;
yeccgoto_pkgdName(430) -> 380;
yeccgoto_pkgdName(455) -> 457;
yeccgoto_pkgdName(460) -> 457;
yeccgoto_pkgdName(477) -> 457;
yeccgoto_pkgdName(494) -> 457;
yeccgoto_pkgdName(507) -> 457;
yeccgoto_pkgdName(527) -> 457;
yeccgoto_pkgdName(538) -> 540;
yeccgoto_pkgdName(557) -> 559;
yeccgoto_pkgdName(577) -> 559;
yeccgoto_pkgdName(592) -> 540;
yeccgoto_pkgdName(596) -> 308;
yeccgoto_pkgdName(600) -> 308;
yeccgoto_pkgdName(731) -> 733;
yeccgoto_pkgdName(737) -> 733.

yeccgoto_portNumber(121) -> 123;
yeccgoto_portNumber(128) -> 129;
yeccgoto_portNumber(248) -> 249.

yeccgoto_priority(151) -> 155;
yeccgoto_priority(351) -> 155;
yeccgoto_priority(644) -> 155;
yeccgoto_priority(766) -> 155.

yeccgoto_propertyParm(455) -> 456;
yeccgoto_propertyParm(460) -> 461;
yeccgoto_propertyParm(477) -> 480;
yeccgoto_propertyParm(494) -> 480;
yeccgoto_propertyParm(507) -> 508;
yeccgoto_propertyParm(527) -> 508.

yeccgoto_propertyParms(456) -> 459;
yeccgoto_propertyParms(461) -> 462.

yeccgoto_requestID(302) -> 304;
yeccgoto_requestID(536) -> 537;
yeccgoto_requestID(555) -> 556.

yeccgoto_requestedEvent(538) -> 539;
yeccgoto_requestedEvent(592) -> 593.

yeccgoto_requestedEventBody(540) -> 541.

yeccgoto_requestedEvents(539) -> 591;
yeccgoto_requestedEvents(593) -> 594.

yeccgoto_safeToken(4) -> 107;
yeccgoto_safeToken(6) -> 7;
yeccgoto_safeToken(102) -> 103;
yeccgoto_safeToken(104) -> 105;
yeccgoto_safeToken(110) -> 780;
yeccgoto_safeToken(114) -> 126;
yeccgoto_safeToken(115) -> 116;
yeccgoto_safeToken(116) -> 116;
yeccgoto_safeToken(118) -> 116;
yeccgoto_safeToken(121) -> 122;
yeccgoto_safeToken(128) -> 122;
yeccgoto_safeToken(144) -> 615;
yeccgoto_safeToken(148) -> 149;
yeccgoto_safeToken(176) -> 180;
yeccgoto_safeToken(181) -> 180;
yeccgoto_safeToken(190) -> 180;
yeccgoto_safeToken(194) -> 180;
yeccgoto_safeToken(220) -> 180;
yeccgoto_safeToken(225) -> 235;
yeccgoto_safeToken(246) -> 247;
yeccgoto_safeToken(248) -> 122;
yeccgoto_safeToken(251) -> 253;
yeccgoto_safeToken(255) -> 256;
yeccgoto_safeToken(259) -> 260;
yeccgoto_safeToken(261) -> 262;
yeccgoto_safeToken(264) -> 253;
yeccgoto_safeToken(265) -> 253;
yeccgoto_safeToken(266) -> 253;
yeccgoto_safeToken(267) -> 253;
yeccgoto_safeToken(273) -> 253;
yeccgoto_safeToken(274) -> 253;
yeccgoto_safeToken(277) -> 253;
yeccgoto_safeToken(278) -> 253;
yeccgoto_safeToken(288) -> 235;
yeccgoto_safeToken(293) -> 294;
yeccgoto_safeToken(295) -> 180;
yeccgoto_safeToken(302) -> 303;
yeccgoto_safeToken(305) -> 307;
yeccgoto_safeToken(312) -> 307;
yeccgoto_safeToken(316) -> 307;
yeccgoto_safeToken(319) -> 320;
yeccgoto_safeToken(326) -> 320;
yeccgoto_safeToken(344) -> 180;
yeccgoto_safeToken(347) -> 180;
yeccgoto_safeToken(355) -> 180;
yeccgoto_safeToken(375) -> 307;
yeccgoto_safeToken(382) -> 384;
yeccgoto_safeToken(385) -> 307;
yeccgoto_safeToken(389) -> 307;
yeccgoto_safeToken(393) -> 395;
yeccgoto_safeToken(401) -> 403;
yeccgoto_safeToken(421) -> 422;
yeccgoto_safeToken(425) -> 395;
yeccgoto_safeToken(430) -> 307;
yeccgoto_safeToken(434) -> 435;
yeccgoto_safeToken(438) -> 180;
yeccgoto_safeToken(441) -> 180;
yeccgoto_safeToken(445) -> 447;
yeccgoto_safeToken(446) -> 447;
yeccgoto_safeToken(450) -> 447;
yeccgoto_safeToken(455) -> 307;
yeccgoto_safeToken(460) -> 307;
yeccgoto_safeToken(477) -> 307;
yeccgoto_safeToken(494) -> 307;
yeccgoto_safeToken(498) -> 403;
yeccgoto_safeToken(507) -> 307;
yeccgoto_safeToken(527) -> 307;
yeccgoto_safeToken(536) -> 303;
yeccgoto_safeToken(538) -> 307;
yeccgoto_safeToken(542) -> 320;
yeccgoto_safeToken(555) -> 303;
yeccgoto_safeToken(557) -> 307;
yeccgoto_safeToken(561) -> 320;
yeccgoto_safeToken(572) -> 320;
yeccgoto_safeToken(577) -> 307;
yeccgoto_safeToken(587) -> 320;
yeccgoto_safeToken(592) -> 307;
yeccgoto_safeToken(596) -> 307;
yeccgoto_safeToken(600) -> 307;
yeccgoto_safeToken(624) -> 626;
yeccgoto_safeToken(628) -> 626;
yeccgoto_safeToken(632) -> 615;
yeccgoto_safeToken(642) -> 149;
yeccgoto_safeToken(662) -> 180;
yeccgoto_safeToken(687) -> 180;
yeccgoto_safeToken(693) -> 180;
yeccgoto_safeToken(699) -> 180;
yeccgoto_safeToken(702) -> 703;
yeccgoto_safeToken(731) -> 307;
yeccgoto_safeToken(734) -> 253;
yeccgoto_safeToken(737) -> 307;
yeccgoto_safeToken(741) -> 742;
yeccgoto_safeToken(745) -> 742;
yeccgoto_safeToken(754) -> 180;
yeccgoto_safeToken(759) -> 180;
yeccgoto_safeToken(775) -> 615.

yeccgoto_secondEventParameter(561) -> 562;
yeccgoto_secondEventParameter(572) -> 573.

yeccgoto_secondEventParameters(562) -> 571;
yeccgoto_secondEventParameters(573) -> 574.

yeccgoto_secondRequestedEvent(557) -> 558;
yeccgoto_secondRequestedEvent(577) -> 578.

yeccgoto_secondRequestedEventBody(559) -> 560.

yeccgoto_secondRequestedEvents(558) -> 576;
yeccgoto_secondRequestedEvents(578) -> 579.

yeccgoto_servChgReplyParm(669) -> 675;
yeccgoto_servChgReplyParm(681) -> 682.

yeccgoto_servChgReplyParms(675) -> 680;
yeccgoto_servChgReplyParms(682) -> 683.

yeccgoto_serviceChangeAddress(225) -> 234;
yeccgoto_serviceChangeAddress(288) -> 234;
yeccgoto_serviceChangeAddress(669) -> 674;
yeccgoto_serviceChangeAddress(681) -> 674.

yeccgoto_serviceChangeDelay(225) -> 233;
yeccgoto_serviceChangeDelay(288) -> 233.

yeccgoto_serviceChangeDescriptor(222) -> 223.

yeccgoto_serviceChangeMethod(225) -> 232;
yeccgoto_serviceChangeMethod(288) -> 232.

yeccgoto_serviceChangeMgcId(225) -> 231;
yeccgoto_serviceChangeMgcId(288) -> 231;
yeccgoto_serviceChangeMgcId(669) -> 673;
yeccgoto_serviceChangeMgcId(681) -> 673.

yeccgoto_serviceChangeParm(225) -> 230;
yeccgoto_serviceChangeParm(288) -> 289.

yeccgoto_serviceChangeParms(230) -> 287;
yeccgoto_serviceChangeParms(289) -> 290.

yeccgoto_serviceChangeProfile(225) -> 229;
yeccgoto_serviceChangeProfile(288) -> 229;
yeccgoto_serviceChangeProfile(669) -> 672;
yeccgoto_serviceChangeProfile(681) -> 672.

yeccgoto_serviceChangeReason(225) -> 228;
yeccgoto_serviceChangeReason(288) -> 228.

yeccgoto_serviceChangeReply(644) -> 645;
yeccgoto_serviceChangeReply(766) -> 645.

yeccgoto_serviceChangeReplyBody(663) -> 664.

yeccgoto_serviceChangeReplyDescriptor(665) -> 666.

yeccgoto_serviceChangeRequest(151) -> 154;
yeccgoto_serviceChangeRequest(351) -> 154.

yeccgoto_serviceChangeVersion(225) -> 227;
yeccgoto_serviceChangeVersion(288) -> 227;
yeccgoto_serviceChangeVersion(669) -> 671;
yeccgoto_serviceChangeVersion(681) -> 671.

yeccgoto_serviceState(484) -> 485.

yeccgoto_serviceStates(477) -> 479;
yeccgoto_serviceStates(494) -> 479.

yeccgoto_sigParameter(393) -> 394;
yeccgoto_sigParameter(425) -> 426.

yeccgoto_sigParameters(394) -> 424;
yeccgoto_sigParameters(426) -> 427.

yeccgoto_signalList(375) -> 379;
yeccgoto_signalList(430) -> 379.

yeccgoto_signalListId(382) -> 383.

yeccgoto_signalListParm(385) -> 387;
yeccgoto_signalListParm(389) -> 390.

yeccgoto_signalListParms(387) -> 388;
yeccgoto_signalListParms(390) -> 391.

yeccgoto_signalName(375) -> 378;
yeccgoto_signalName(385) -> 378;
yeccgoto_signalName(389) -> 378;
yeccgoto_signalName(430) -> 378.

yeccgoto_signalParm(375) -> 377;
yeccgoto_signalParm(430) -> 431.

yeccgoto_signalParms(377) -> 429;
yeccgoto_signalParms(431) -> 432.

yeccgoto_signalRequest(375) -> 376;
yeccgoto_signalRequest(385) -> 386;
yeccgoto_signalRequest(389) -> 386;
yeccgoto_signalRequest(430) -> 376.

yeccgoto_signalType(404) -> 405.

yeccgoto_signalsDescriptor(358) -> 359;
yeccgoto_signalsDescriptor(551) -> 552;
yeccgoto_signalsDescriptor(568) -> 569;
yeccgoto_signalsDescriptor(605) -> 359;
yeccgoto_signalsDescriptor(710) -> 713;
yeccgoto_signalsDescriptor(750) -> 713;
yeccgoto_signalsDescriptor(762) -> 713.

yeccgoto_statisticsDescriptor(710) -> 712;
yeccgoto_statisticsDescriptor(750) -> 712;
yeccgoto_statisticsDescriptor(762) -> 712.

yeccgoto_statisticsParameter(731) -> 732;
yeccgoto_statisticsParameter(737) -> 738.

yeccgoto_statisticsParameters(732) -> 736;
yeccgoto_statisticsParameters(738) -> 739.

yeccgoto_streamDescriptor(466) -> 469;
yeccgoto_streamDescriptor(532) -> 469.

yeccgoto_streamID(401) -> 402;
yeccgoto_streamID(498) -> 499.

yeccgoto_streamModes(519) -> 520.

yeccgoto_streamParm(466) -> 468;
yeccgoto_streamParm(500) -> 501;
yeccgoto_streamParm(503) -> 504;
yeccgoto_streamParm(532) -> 468.

yeccgoto_streamParmList(501) -> 502;
yeccgoto_streamParmList(504) -> 505.

yeccgoto_subtractRequest(151) -> 153;
yeccgoto_subtractRequest(351) -> 153.

yeccgoto_terminationA(176) -> 179;
yeccgoto_terminationA(190) -> 179.

yeccgoto_terminationAudit(710) -> 711;
yeccgoto_terminationAudit(762) -> 763.

yeccgoto_terminationB(181) -> 183.

yeccgoto_terminationID(176) -> 178;
yeccgoto_terminationID(181) -> 182;
yeccgoto_terminationID(190) -> 178;
yeccgoto_terminationID(194) -> 195;
yeccgoto_terminationID(220) -> 221;
yeccgoto_terminationID(295) -> 296;
yeccgoto_terminationID(344) -> 345;
yeccgoto_terminationID(347) -> 348;
yeccgoto_terminationID(355) -> 356;
yeccgoto_terminationID(438) -> 439;
yeccgoto_terminationID(441) -> 442;
yeccgoto_terminationID(662) -> 663;
yeccgoto_terminationID(687) -> 688;
yeccgoto_terminationID(693) -> 694;
yeccgoto_terminationID(699) -> 439;
yeccgoto_terminationID(754) -> 694;
yeccgoto_terminationID(759) -> 760.

yeccgoto_terminationIDList(436) -> 437;
yeccgoto_terminationIDList(696) -> 697;
yeccgoto_terminationIDList(756) -> 697.

yeccgoto_terminationIDListRepeat(439) -> 440;
yeccgoto_terminationIDListRepeat(442) -> 443.

yeccgoto_terminationStateDescriptor(466) -> 467;
yeccgoto_terminationStateDescriptor(532) -> 467.

yeccgoto_terminationStateParm(477) -> 478;
yeccgoto_terminationStateParm(494) -> 495.

yeccgoto_terminationStateParms(478) -> 493;
yeccgoto_terminationStateParms(495) -> 496.

yeccgoto_timeStamp(225) -> 226;
yeccgoto_timeStamp(288) -> 226;
yeccgoto_timeStamp(305) -> 306;
yeccgoto_timeStamp(312) -> 306;
yeccgoto_timeStamp(596) -> 306;
yeccgoto_timeStamp(600) -> 306;
yeccgoto_timeStamp(669) -> 670;
yeccgoto_timeStamp(681) -> 670.

yeccgoto_topologyDescriptor(151) -> 152;
yeccgoto_topologyDescriptor(351) -> 152;
yeccgoto_topologyDescriptor(644) -> 152;
yeccgoto_topologyDescriptor(766) -> 152.

yeccgoto_topologyDirection(184) -> 185.

yeccgoto_topologyTriple(176) -> 177;
yeccgoto_topologyTriple(190) -> 191.

yeccgoto_topologyTripleList(177) -> 189;
yeccgoto_topologyTripleList(191) -> 192.

yeccgoto_transactionAck(624) -> 625;
yeccgoto_transactionAck(628) -> 629.

yeccgoto_transactionAckList(625) -> 627;
yeccgoto_transactionAckList(629) -> 630.

yeccgoto_transactionID(144) -> 614;
yeccgoto_transactionID(632) -> 633;
yeccgoto_transactionID(775) -> 776.

yeccgoto_transactionItem(111) -> 136;
yeccgoto_transactionItem(136) -> 136.

yeccgoto_transactionList(111) -> 135;
yeccgoto_transactionList(136) -> 779.

yeccgoto_transactionPending(111) -> 134;
yeccgoto_transactionPending(136) -> 134.

yeccgoto_transactionReply(111) -> 133;
yeccgoto_transactionReply(136) -> 133.

yeccgoto_transactionReplyBody(635) -> 638.

yeccgoto_transactionRequest(111) -> 132;
yeccgoto_transactionRequest(136) -> 132.

yeccgoto_transactionResponseAck(111) -> 131;
yeccgoto_transactionResponseAck(136) -> 131.

yeccgoto_value(251) -> 252;
yeccgoto_value(264) -> 271;
yeccgoto_value(265) -> 270;
yeccgoto_value(266) -> 269;
yeccgoto_value(267) -> 268;
yeccgoto_value(273) -> 284;
yeccgoto_value(274) -> 275;
yeccgoto_value(277) -> 281;
yeccgoto_value(278) -> 279;
yeccgoto_value(734) -> 735.

yeccgoto_valueList(275) -> 276;
yeccgoto_valueList(279) -> 280;
yeccgoto_valueList(284) -> 285.

-compile({inline,{yeccpars2_0_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_0_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_1_,1}}).
-file("megaco_text_parser_v1.yrl", 393).
yeccpars2_1_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_3_,1}}).
-file("megaco_text_parser_v1.yrl", 387).
yeccpars2_3_([__1 | Stack]) ->
 [begin
   sep
  end | Stack].

-compile({inline,{yeccpars2_8_,1}}).
-file("megaco_text_parser_v1.yrl", 1185).
yeccpars2_8_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_9_,1}}).
-file("megaco_text_parser_v1.yrl", 1187).
yeccpars2_9_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_10_,1}}).
-file("megaco_text_parser_v1.yrl", 1186).
yeccpars2_10_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_11_,1}}).
-file("megaco_text_parser_v1.yrl", 1188).
yeccpars2_11_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_12_,1}}).
-file("megaco_text_parser_v1.yrl", 1189).
yeccpars2_12_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_13_,1}}).
-file("megaco_text_parser_v1.yrl", 1190).
yeccpars2_13_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_14_,1}}).
-file("megaco_text_parser_v1.yrl", 1191).
yeccpars2_14_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_15_,1}}).
-file("megaco_text_parser_v1.yrl", 1192).
yeccpars2_15_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_16_,1}}).
-file("megaco_text_parser_v1.yrl", 1194).
yeccpars2_16_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_17_,1}}).
-file("megaco_text_parser_v1.yrl", 1193).
yeccpars2_17_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_18_,1}}).
-file("megaco_text_parser_v1.yrl", 1199).
yeccpars2_18_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_19_,1}}).
-file("megaco_text_parser_v1.yrl", 1195).
yeccpars2_19_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_20_,1}}).
-file("megaco_text_parser_v1.yrl", 1197).
yeccpars2_20_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_21_,1}}).
-file("megaco_text_parser_v1.yrl", 1198).
yeccpars2_21_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_22_,1}}).
-file("megaco_text_parser_v1.yrl", 1200).
yeccpars2_22_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_23_,1}}).
-file("megaco_text_parser_v1.yrl", 1201).
yeccpars2_23_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_24_,1}}).
-file("megaco_text_parser_v1.yrl", 1202).
yeccpars2_24_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_25_,1}}).
-file("megaco_text_parser_v1.yrl", 1203).
yeccpars2_25_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_26_,1}}).
-file("megaco_text_parser_v1.yrl", 1204).
yeccpars2_26_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_27_,1}}).
-file("megaco_text_parser_v1.yrl", 1205).
yeccpars2_27_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_28_,1}}).
-file("megaco_text_parser_v1.yrl", 1206).
yeccpars2_28_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_29_,1}}).
-file("megaco_text_parser_v1.yrl", 1207).
yeccpars2_29_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_30_,1}}).
-file("megaco_text_parser_v1.yrl", 1208).
yeccpars2_30_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_31_,1}}).
-file("megaco_text_parser_v1.yrl", 1209).
yeccpars2_31_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_32_,1}}).
-file("megaco_text_parser_v1.yrl", 1210).
yeccpars2_32_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_33_,1}}).
-file("megaco_text_parser_v1.yrl", 1211).
yeccpars2_33_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_34_,1}}).
-file("megaco_text_parser_v1.yrl", 1212).
yeccpars2_34_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_35_,1}}).
-file("megaco_text_parser_v1.yrl", 1213).
yeccpars2_35_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_36_,1}}).
-file("megaco_text_parser_v1.yrl", 1218).
yeccpars2_36_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_37_,1}}).
-file("megaco_text_parser_v1.yrl", 1214).
yeccpars2_37_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_38_,1}}).
-file("megaco_text_parser_v1.yrl", 1215).
yeccpars2_38_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_39_,1}}).
-file("megaco_text_parser_v1.yrl", 1216).
yeccpars2_39_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_40_,1}}).
-file("megaco_text_parser_v1.yrl", 1217).
yeccpars2_40_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_41_,1}}).
-file("megaco_text_parser_v1.yrl", 1219).
yeccpars2_41_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_42_,1}}).
-file("megaco_text_parser_v1.yrl", 1222).
yeccpars2_42_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_43_,1}}).
-file("megaco_text_parser_v1.yrl", 1224).
yeccpars2_43_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_44_,1}}).
-file("megaco_text_parser_v1.yrl", 1223).
yeccpars2_44_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_45_,1}}).
-file("megaco_text_parser_v1.yrl", 1225).
yeccpars2_45_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_46_,1}}).
-file("megaco_text_parser_v1.yrl", 1227).
yeccpars2_46_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_47_,1}}).
-file("megaco_text_parser_v1.yrl", 1228).
yeccpars2_47_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_48_,1}}).
-file("megaco_text_parser_v1.yrl", 1229).
yeccpars2_48_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_49_,1}}).
-file("megaco_text_parser_v1.yrl", 1231).
yeccpars2_49_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_50_,1}}).
-file("megaco_text_parser_v1.yrl", 1230).
yeccpars2_50_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_51_,1}}).
-file("megaco_text_parser_v1.yrl", 1232).
yeccpars2_51_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_52_,1}}).
-file("megaco_text_parser_v1.yrl", 1235).
yeccpars2_52_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_53_,1}}).
-file("megaco_text_parser_v1.yrl", 1237).
yeccpars2_53_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_54_,1}}).
-file("megaco_text_parser_v1.yrl", 1236).
yeccpars2_54_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_55_,1}}).
-file("megaco_text_parser_v1.yrl", 1238).
yeccpars2_55_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_56_,1}}).
-file("megaco_text_parser_v1.yrl", 1240).
yeccpars2_56_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_57_,1}}).
-file("megaco_text_parser_v1.yrl", 1242).
yeccpars2_57_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_58_,1}}).
-file("megaco_text_parser_v1.yrl", 1241).
yeccpars2_58_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_59_,1}}).
-file("megaco_text_parser_v1.yrl", 1239).
yeccpars2_59_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_60_,1}}).
-file("megaco_text_parser_v1.yrl", 1244).
yeccpars2_60_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_61_,1}}).
-file("megaco_text_parser_v1.yrl", 1243).
yeccpars2_61_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_62_,1}}).
-file("megaco_text_parser_v1.yrl", 1245).
yeccpars2_62_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_63_,1}}).
-file("megaco_text_parser_v1.yrl", 1246).
yeccpars2_63_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_64_,1}}).
-file("megaco_text_parser_v1.yrl", 1247).
yeccpars2_64_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_65_,1}}).
-file("megaco_text_parser_v1.yrl", 1248).
yeccpars2_65_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_66_,1}}).
-file("megaco_text_parser_v1.yrl", 1249).
yeccpars2_66_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_67_,1}}).
-file("megaco_text_parser_v1.yrl", 1250).
yeccpars2_67_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_68_,1}}).
-file("megaco_text_parser_v1.yrl", 1251).
yeccpars2_68_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_69_,1}}).
-file("megaco_text_parser_v1.yrl", 1256).
yeccpars2_69_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_70_,1}}).
-file("megaco_text_parser_v1.yrl", 1257).
yeccpars2_70_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_71_,1}}).
-file("megaco_text_parser_v1.yrl", 1252).
yeccpars2_71_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_72_,1}}).
-file("megaco_text_parser_v1.yrl", 1253).
yeccpars2_72_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_73_,1}}).
-file("megaco_text_parser_v1.yrl", 1184).
yeccpars2_73_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_74_,1}}).
-file("megaco_text_parser_v1.yrl", 1258).
yeccpars2_74_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_75_,1}}).
-file("megaco_text_parser_v1.yrl", 1259).
yeccpars2_75_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_76_,1}}).
-file("megaco_text_parser_v1.yrl", 1263).
yeccpars2_76_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_77_,1}}).
-file("megaco_text_parser_v1.yrl", 1262).
yeccpars2_77_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_78_,1}}).
-file("megaco_text_parser_v1.yrl", 1261).
yeccpars2_78_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_79_,1}}).
-file("megaco_text_parser_v1.yrl", 1260).
yeccpars2_79_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_80_,1}}).
-file("megaco_text_parser_v1.yrl", 1264).
yeccpars2_80_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_81_,1}}).
-file("megaco_text_parser_v1.yrl", 1266).
yeccpars2_81_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_82_,1}}).
-file("megaco_text_parser_v1.yrl", 1265).
yeccpars2_82_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_83_,1}}).
-file("megaco_text_parser_v1.yrl", 1267).
yeccpars2_83_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_84_,1}}).
-file("megaco_text_parser_v1.yrl", 1268).
yeccpars2_84_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_85_,1}}).
-file("megaco_text_parser_v1.yrl", 1269).
yeccpars2_85_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_86_,1}}).
-file("megaco_text_parser_v1.yrl", 1270).
yeccpars2_86_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_87_,1}}).
-file("megaco_text_parser_v1.yrl", 1271).
yeccpars2_87_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_88_,1}}).
-file("megaco_text_parser_v1.yrl", 1272).
yeccpars2_88_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_89_,1}}).
-file("megaco_text_parser_v1.yrl", 1273).
yeccpars2_89_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_90_,1}}).
-file("megaco_text_parser_v1.yrl", 1274).
yeccpars2_90_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_91_,1}}).
-file("megaco_text_parser_v1.yrl", 1275).
yeccpars2_91_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_92_,1}}).
-file("megaco_text_parser_v1.yrl", 1276).
yeccpars2_92_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_93_,1}}).
-file("megaco_text_parser_v1.yrl", 1277).
yeccpars2_93_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_94_,1}}).
-file("megaco_text_parser_v1.yrl", 1278).
yeccpars2_94_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_95_,1}}).
-file("megaco_text_parser_v1.yrl", 1279).
yeccpars2_95_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_96_,1}}).
-file("megaco_text_parser_v1.yrl", 1280).
yeccpars2_96_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_97_,1}}).
-file("megaco_text_parser_v1.yrl", 1281).
yeccpars2_97_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_98_,1}}).
-file("megaco_text_parser_v1.yrl", 1282).
yeccpars2_98_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_99_,1}}).
-file("megaco_text_parser_v1.yrl", 1283).
yeccpars2_99_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_100_,1}}).
-file("megaco_text_parser_v1.yrl", 1284).
yeccpars2_100_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_101_,1}}).
-file("megaco_text_parser_v1.yrl", 1285).
yeccpars2_101_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_105_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_105_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_106_,1}}).
-file("megaco_text_parser_v1.yrl", 392).
yeccpars2_106_([__8,__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   ensure_auth_header ( __3 , __5 , __7 )
  end | Stack].

-compile({inline,{yeccpars2_107_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_107_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_109_,1}}).
-file("megaco_text_parser_v1.yrl", 385).
yeccpars2_109_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'MegacoMessage' { authHeader = __2 , mess = __3 }
  end | Stack].

-compile({inline,{yeccpars2_115_,1}}).
-file("megaco_text_parser_v1.yrl", 711).
yeccpars2_115_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_116_,1}}).
-file("megaco_text_parser_v1.yrl", 711).
yeccpars2_116_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_118_,1}}).
-file("megaco_text_parser_v1.yrl", 711).
yeccpars2_118_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_119_,1}}).
-file("megaco_text_parser_v1.yrl", 712).
yeccpars2_119_([__2,__1 | Stack]) ->
 [begin
   [ colon | __2 ]
  end | Stack].

-compile({inline,{yeccpars2_120_,1}}).
-file("megaco_text_parser_v1.yrl", 709).
yeccpars2_120_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_domainAddress ( __2 , asn1_NOVALUE )
  end | Stack].

-compile({inline,{yeccpars2_122_,1}}).
-file("megaco_text_parser_v1.yrl", 716).
yeccpars2_122_([__1 | Stack]) ->
 [begin
   ensure_uint16 ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_123_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_123_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_124_,1}}).
-file("megaco_text_parser_v1.yrl", 707).
yeccpars2_124_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   ensure_domainAddress ( __2 , __5 )
  end | Stack].

-compile({inline,{yeccpars2_125_,1}}).
-file("megaco_text_parser_v1.yrl", 713).
yeccpars2_125_([__2,__1 | Stack]) ->
 [begin
   [ __1 | __2 ]
  end | Stack].

-compile({inline,{yeccpars2_127_,1}}).
-file("megaco_text_parser_v1.yrl", 700).
yeccpars2_127_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_domainName ( __2 , asn1_NOVALUE )
  end | Stack].

-compile({inline,{yeccpars2_129_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_129_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_130_,1}}).
-file("megaco_text_parser_v1.yrl", 698).
yeccpars2_130_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   ensure_domainName ( __2 , __5 )
  end | Stack].

-compile({inline,{yeccpars2_131_,1}}).
-file("megaco_text_parser_v1.yrl", 407).
yeccpars2_131_([__1 | Stack]) ->
 [begin
   { transactionResponseAck , __1 }
  end | Stack].

-compile({inline,{yeccpars2_132_,1}}).
-file("megaco_text_parser_v1.yrl", 404).
yeccpars2_132_([__1 | Stack]) ->
 [begin
   { transactionRequest , __1 }
  end | Stack].

-compile({inline,{yeccpars2_133_,1}}).
-file("megaco_text_parser_v1.yrl", 405).
yeccpars2_133_([__1 | Stack]) ->
 [begin
   { transactionReply , __1 }
  end | Stack].

-compile({inline,{yeccpars2_134_,1}}).
-file("megaco_text_parser_v1.yrl", 406).
yeccpars2_134_([__1 | Stack]) ->
 [begin
   { transactionPending , __1 }
  end | Stack].

-compile({inline,{yeccpars2_135_,1}}).
-file("megaco_text_parser_v1.yrl", 399).
yeccpars2_135_([__1 | Stack]) ->
 [begin
   { transactions , __1 }
  end | Stack].

-compile({inline,{yeccpars2_136_,1}}).
-file("megaco_text_parser_v1.yrl", 401).
yeccpars2_136_([__1 | Stack]) ->
 [begin
   [ __1 ]
  end | Stack].

-compile({inline,{yeccpars2_137_,1}}).
-file("megaco_text_parser_v1.yrl", 396).
yeccpars2_137_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_message ( __1 , __2 , __3 )
  end | Stack].

-compile({inline,{yeccpars2_138_,1}}).
-file("megaco_text_parser_v1.yrl", 398).
yeccpars2_138_([__1 | Stack]) ->
 [begin
   { messageError , __1 }
  end | Stack].

-compile({inline,{yeccpars2_146_,1}}).
-file("megaco_text_parser_v1.yrl", 436).
yeccpars2_146_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_149_,1}}).
-file("megaco_text_parser_v1.yrl", 704).
yeccpars2_149_([__1 | Stack]) ->
 [begin
   ensure_contextID ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_152_,1}}).
-file("megaco_text_parser_v1.yrl", 450).
yeccpars2_152_([__1 | Stack]) ->
 [begin
   { topology , __1 }
  end | Stack].

-compile({inline,{yeccpars2_155_,1}}).
-file("megaco_text_parser_v1.yrl", 451).
yeccpars2_155_([__1 | Stack]) ->
 [begin
   { priority , __1 }
  end | Stack].

-compile({inline,{yeccpars2_163_,1}}).
-file("megaco_text_parser_v1.yrl", 443).
yeccpars2_163_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_164_,1}}).
-file("megaco_text_parser_v1.yrl", 524).
yeccpars2_164_([__1 | Stack]) ->
 [begin
   { addReq , __1 }
  end | Stack].

-compile({inline,{yeccpars2_168_,1}}).
-file("megaco_text_parser_v1.yrl", 452).
yeccpars2_168_([__1 | Stack]) ->
 [begin
   { emergency , true }
  end | Stack].

-compile({inline,{yeccpars2_169_,1}}).
-file("megaco_text_parser_v1.yrl", 526).
yeccpars2_169_([__1 | Stack]) ->
 [begin
   { modReq , __1 }
  end | Stack].

-compile({inline,{yeccpars2_170_,1}}).
-file("megaco_text_parser_v1.yrl", 525).
yeccpars2_170_([__1 | Stack]) ->
 [begin
   { moveReq , __1 }
  end | Stack].

-compile({inline,{yeccpars2_177_,1}}).
-file("megaco_text_parser_v1.yrl", 1169).
yeccpars2_177_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_180_,1}}).
-file("megaco_text_parser_v1.yrl", 732).
yeccpars2_180_([__1 | Stack]) ->
 [begin
   ensure_terminationID ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_185_,1}}).
-file("megaco_text_parser_v1.yrl", 1165).
yeccpars2_185_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'TopologyRequest' { terminationFrom = __1 ,
    terminationTo = __3 ,
    topologyDirection = __5 }
  end | Stack].

-compile({inline,{yeccpars2_186_,1}}).
-file("megaco_text_parser_v1.yrl", 1173).
yeccpars2_186_([__1 | Stack]) ->
 [begin
   bothway
  end | Stack].

-compile({inline,{yeccpars2_187_,1}}).
-file("megaco_text_parser_v1.yrl", 1174).
yeccpars2_187_([__1 | Stack]) ->
 [begin
   isolate
  end | Stack].

-compile({inline,{yeccpars2_188_,1}}).
-file("megaco_text_parser_v1.yrl", 1175).
yeccpars2_188_([__1 | Stack]) ->
 [begin
   oneway
  end | Stack].

-compile({inline,{yeccpars2_191_,1}}).
-file("megaco_text_parser_v1.yrl", 1169).
yeccpars2_191_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_192_,1}}).
-file("megaco_text_parser_v1.yrl", 1171).
yeccpars2_192_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_193_,1}}).
-file("megaco_text_parser_v1.yrl", 1157).
yeccpars2_193_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_195_,1}}).
-file("megaco_text_parser_v1.yrl", 564).
yeccpars2_195_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_196_,1}}).
-file("megaco_text_parser_v1.yrl", 558).
yeccpars2_196_([__4,__3,__2,__1 | Stack]) ->
 [begin
   make_commandRequest ( { subtractReq , __1 } ,
    # 'SubtractRequest' { terminationID = [ __3 ] ,
    auditDescriptor = __4 } )
  end | Stack].

-compile({inline,{yeccpars2_200_,1}}).
-file("megaco_text_parser_v1.yrl", 621).
yeccpars2_200_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_202_,1}}).
-file("megaco_text_parser_v1.yrl", 624).
yeccpars2_202_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_204_,1}}).
-file("megaco_text_parser_v1.yrl", 631).
yeccpars2_204_([__1 | Stack]) ->
 [begin
   digitMapToken
  end | Stack].

-compile({inline,{yeccpars2_205_,1}}).
-file("megaco_text_parser_v1.yrl", 641).
yeccpars2_205_([__1 | Stack]) ->
 [begin
   eventBufferToken
  end | Stack].

-compile({inline,{yeccpars2_206_,1}}).
-file("megaco_text_parser_v1.yrl", 642).
yeccpars2_206_([__1 | Stack]) ->
 [begin
   eventsToken
  end | Stack].

-compile({inline,{yeccpars2_207_,1}}).
-file("megaco_text_parser_v1.yrl", 630).
yeccpars2_207_([__1 | Stack]) ->
 [begin
   mediaToken
  end | Stack].

-compile({inline,{yeccpars2_208_,1}}).
-file("megaco_text_parser_v1.yrl", 629).
yeccpars2_208_([__1 | Stack]) ->
 [begin
   modemToken
  end | Stack].

-compile({inline,{yeccpars2_209_,1}}).
-file("megaco_text_parser_v1.yrl", 628).
yeccpars2_209_([__1 | Stack]) ->
 [begin
   muxToken
  end | Stack].

-compile({inline,{yeccpars2_210_,1}}).
-file("megaco_text_parser_v1.yrl", 633).
yeccpars2_210_([__1 | Stack]) ->
 [begin
   observedEventsToken
  end | Stack].

-compile({inline,{yeccpars2_211_,1}}).
-file("megaco_text_parser_v1.yrl", 634).
yeccpars2_211_([__1 | Stack]) ->
 [begin
   packagesToken
  end | Stack].

-compile({inline,{yeccpars2_212_,1}}).
-file("megaco_text_parser_v1.yrl", 640).
yeccpars2_212_([__1 | Stack]) ->
 [begin
   signalsToken
  end | Stack].

-compile({inline,{yeccpars2_213_,1}}).
-file("megaco_text_parser_v1.yrl", 632).
yeccpars2_213_([__1 | Stack]) ->
 [begin
   statsToken
  end | Stack].

-compile({inline,{yeccpars2_214_,1}}).
-file("megaco_text_parser_v1.yrl", 618).
yeccpars2_214_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'AuditDescriptor' { auditToken = __3 }
  end | Stack].

-compile({inline,{yeccpars2_215_,1}}).
-file("megaco_text_parser_v1.yrl", 620).
yeccpars2_215_([__2,__1 | Stack]) ->
 [begin
   [ __1 | __2 ]
  end | Stack].

-compile({inline,{yeccpars2_217_,1}}).
-file("megaco_text_parser_v1.yrl", 624).
yeccpars2_217_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_218_,1}}).
-file("megaco_text_parser_v1.yrl", 623).
yeccpars2_218_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_219_,1}}).
-file("megaco_text_parser_v1.yrl", 563).
yeccpars2_219_([__3,__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_226_,1}}).
-file("megaco_text_parser_v1.yrl", 1092).
yeccpars2_226_([__1 | Stack]) ->
 [begin
   { time_stamp , __1 }
  end | Stack].

-compile({inline,{yeccpars2_227_,1}}).
-file("megaco_text_parser_v1.yrl", 1094).
yeccpars2_227_([__1 | Stack]) ->
 [begin
   { version , __1 }
  end | Stack].

-compile({inline,{yeccpars2_228_,1}}).
-file("megaco_text_parser_v1.yrl", 1087).
yeccpars2_228_([__1 | Stack]) ->
 [begin
   { reason , __1 }
  end | Stack].

-compile({inline,{yeccpars2_229_,1}}).
-file("megaco_text_parser_v1.yrl", 1090).
yeccpars2_229_([__1 | Stack]) ->
 [begin
   { profile , __1 }
  end | Stack].

-compile({inline,{yeccpars2_230_,1}}).
-file("megaco_text_parser_v1.yrl", 1084).
yeccpars2_230_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_231_,1}}).
-file("megaco_text_parser_v1.yrl", 1093).
yeccpars2_231_([__1 | Stack]) ->
 [begin
   { mgc_id , __1 }
  end | Stack].

-compile({inline,{yeccpars2_232_,1}}).
-file("megaco_text_parser_v1.yrl", 1086).
yeccpars2_232_([__1 | Stack]) ->
 [begin
   { method , __1 }
  end | Stack].

-compile({inline,{yeccpars2_233_,1}}).
-file("megaco_text_parser_v1.yrl", 1088).
yeccpars2_233_([__1 | Stack]) ->
 [begin
   { delay , __1 }
  end | Stack].

-compile({inline,{yeccpars2_234_,1}}).
-file("megaco_text_parser_v1.yrl", 1089).
yeccpars2_234_([__1 | Stack]) ->
 [begin
   { address , __1 }
  end | Stack].

-compile({inline,{yeccpars2_235_,1}}).
-file("megaco_text_parser_v1.yrl", 1179).
yeccpars2_235_([__1 | Stack]) ->
 [begin
   ensure_extensionParameter ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_237_,1}}).
-file("megaco_text_parser_v1.yrl", 1091).
yeccpars2_237_([__1 | Stack]) ->
 [begin
   { extension , __1 }
  end | Stack].

-compile({inline,{yeccpars2_238_,1}}).
-file("megaco_text_parser_v1.yrl", 1199).
yeccpars2_238_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_239_,1}}).
-file("megaco_text_parser_v1.yrl", 1227).
yeccpars2_239_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_240_,1}}).
-file("megaco_text_parser_v1.yrl", 1228).
yeccpars2_240_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_241_,1}}).
-file("megaco_text_parser_v1.yrl", 1248).
yeccpars2_241_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_242_,1}}).
-file("megaco_text_parser_v1.yrl", 1249).
yeccpars2_242_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_243_,1}}).
-file("megaco_text_parser_v1.yrl", 1263).
yeccpars2_243_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_244_,1}}).
-file("megaco_text_parser_v1.yrl", 1139).
yeccpars2_244_([__1 | Stack]) ->
 [begin
   ensure_timeStamp ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_245_,1}}).
-file("megaco_text_parser_v1.yrl", 1285).
yeccpars2_245_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_247_,1}}).
-file("megaco_text_parser_v1.yrl", 1109).
yeccpars2_247_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_version ( __3 )
  end | Stack].

-compile({inline,{yeccpars2_248_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_248_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_249_,1}}).
-file("megaco_text_parser_v1.yrl", 1103).
yeccpars2_249_([__3,__2,__1 | Stack]) ->
 [begin
   { portNumber , __3 }
  end | Stack].

-compile({inline,{yeccpars2_250_,1}}).
-file("megaco_text_parser_v1.yrl", 1102).
yeccpars2_250_([__3,__2,__1 | Stack]) ->
 [begin
   __3
  end | Stack].

-compile({inline,{yeccpars2_252_,1}}).
-file("megaco_text_parser_v1.yrl", 1098).
yeccpars2_252_([__3,__2,__1 | Stack]) ->
 [begin
   [ __3 ]
  end | Stack].

-compile({inline,{yeccpars2_253_,1}}).
-file("megaco_text_parser_v1.yrl", 1182).
yeccpars2_253_([__1 | Stack]) ->
 [begin
   ensure_value ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_254_,1}}).
-file("megaco_text_parser_v1.yrl", 1181).
yeccpars2_254_([__1 | Stack]) ->
 [begin
   ensure_value ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_256_,1}}).
-file("megaco_text_parser_v1.yrl", 1107).
yeccpars2_256_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_profile ( __3 )
  end | Stack].

-compile({inline,{yeccpars2_257_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_257_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_258_,1}}).
-file("megaco_text_parser_v1.yrl", 1105).
yeccpars2_258_([__3,__2,__1 | Stack]) ->
 [begin
   __3
  end | Stack].

-compile({inline,{yeccpars2_260_,1}}).
-file("megaco_text_parser_v1.yrl", 1096).
yeccpars2_260_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_serviceChangeMethod ( __3 )
  end | Stack].

-compile({inline,{yeccpars2_262_,1}}).
-file("megaco_text_parser_v1.yrl", 1100).
yeccpars2_262_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_uint32 ( __3 )
  end | Stack].

-compile({inline,{yeccpars2_263_,1}}).
-file("megaco_text_parser_v1.yrl", 1112).
yeccpars2_263_([__2,__1 | Stack]) ->
 [begin
   setelement ( # 'PropertyParm' .name , __2 , __1 )
  end | Stack].

-compile({inline,{yeccpars2_268_,1}}).
-file("megaco_text_parser_v1.yrl", 800).
yeccpars2_268_([__2,__1 | Stack]) ->
 [begin
   # 'PropertyParm' { value = [ __2 ] , extraInfo = { relation , unequalTo } }
  end | Stack].

-compile({inline,{yeccpars2_269_,1}}).
-file("megaco_text_parser_v1.yrl", 802).
yeccpars2_269_([__2,__1 | Stack]) ->
 [begin
   # 'PropertyParm' { value = [ __2 ] , extraInfo = { relation , smallerThan } }
  end | Stack].

-compile({inline,{yeccpars2_270_,1}}).
-file("megaco_text_parser_v1.yrl", 804).
yeccpars2_270_([__2,__1 | Stack]) ->
 [begin
   # 'PropertyParm' { value = [ __2 ] , extraInfo = { relation , greaterThan } }
  end | Stack].

-compile({inline,{yeccpars2_271_,1}}).
-file("megaco_text_parser_v1.yrl", 823).
yeccpars2_271_([__1 | Stack]) ->
 [begin
   # 'PropertyParm' { value = [ __1 ] }
  end | Stack].

-compile({inline,{yeccpars2_272_,1}}).
-file("megaco_text_parser_v1.yrl", 797).
yeccpars2_272_([__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_275_,1}}).
-file("megaco_text_parser_v1.yrl", 826).
yeccpars2_275_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_279_,1}}).
-file("megaco_text_parser_v1.yrl", 826).
yeccpars2_279_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_280_,1}}).
-file("megaco_text_parser_v1.yrl", 825).
yeccpars2_280_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_282_,1}}).
-file("megaco_text_parser_v1.yrl", 816).
yeccpars2_282_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'PropertyParm' { value = [ __2 , __4 ] ,
    extraInfo = { range , true } }
  end | Stack].

-compile({inline,{yeccpars2_283_,1}}).
-file("megaco_text_parser_v1.yrl", 820).
yeccpars2_283_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'PropertyParm' { value = [ __2 | __3 ] ,
    extraInfo = { sublist , true } }
  end | Stack].

-compile({inline,{yeccpars2_284_,1}}).
-file("megaco_text_parser_v1.yrl", 826).
yeccpars2_284_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_286_,1}}).
-file("megaco_text_parser_v1.yrl", 812).
yeccpars2_286_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'PropertyParm' { value = [ __2 | __3 ] ,
    extraInfo = { sublist , false } }
  end | Stack].

-compile({inline,{yeccpars2_289_,1}}).
-file("megaco_text_parser_v1.yrl", 1084).
yeccpars2_289_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_290_,1}}).
-file("megaco_text_parser_v1.yrl", 1083).
yeccpars2_290_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_291_,1}}).
-file("megaco_text_parser_v1.yrl", 1080).
yeccpars2_291_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_ServiceChangeParm ( [ __3 | __4 ] )
  end | Stack].

-compile({inline,{yeccpars2_292_,1}}).
-file("megaco_text_parser_v1.yrl", 666).
yeccpars2_292_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   make_commandRequest ( { serviceChangeReq , __1 } ,
    # 'ServiceChangeRequest' { terminationID = [ __3 ] ,
    serviceChangeParms = __5 } )
  end | Stack].

-compile({inline,{yeccpars2_294_,1}}).
-file("megaco_text_parser_v1.yrl", 1177).
yeccpars2_294_([__3,__2,__1 | Stack]) ->
 [begin
   ensure_uint16 ( __3 )
  end | Stack].

-compile({inline,{yeccpars2_298_,1}}).
-file("megaco_text_parser_v1.yrl", 652).
yeccpars2_298_([__1 | Stack]) ->
 [begin
   # 'NotifyRequest' { observedEventsDescriptor = __1 }
  end | Stack].

-compile({inline,{yeccpars2_300_,1}}).
-file("megaco_text_parser_v1.yrl", 654).
yeccpars2_300_([__1 | Stack]) ->
 [begin
   # 'NotifyRequest' { errorDescriptor = __1 }
  end | Stack].

-compile({inline,{yeccpars2_303_,1}}).
-file("megaco_text_parser_v1.yrl", 1048).
yeccpars2_303_([__1 | Stack]) ->
 [begin
   ensure_requestID ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_305_,1}}).
-file("megaco_text_parser_v1.yrl", 1036).
yeccpars2_305_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_306_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_306_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_307_,1}}).
-file("megaco_text_parser_v1.yrl", 862).
yeccpars2_307_([__1 | Stack]) ->
 [begin
   ensure_pkgdName ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_308_,1}}).
-file("megaco_text_parser_v1.yrl", 1040).
yeccpars2_308_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_309_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_309_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_310_,1}}).
-file("megaco_text_parser_v1.yrl", 1027).
yeccpars2_310_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_312_,1}}).
-file("megaco_text_parser_v1.yrl", 1036).
yeccpars2_312_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_313_,1}}).
-file("megaco_text_parser_v1.yrl", 1027).
yeccpars2_313_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_314_,1}}).
-file("megaco_text_parser_v1.yrl", 1026).
yeccpars2_314_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_315_,1}}).
-file("megaco_text_parser_v1.yrl", 1023).
yeccpars2_315_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'ObservedEventsDescriptor' { requestId = __3 ,
    observedEventLst = [ __5 | __6 ] }
  end | Stack].

-compile({inline,{yeccpars2_317_,1}}).
-file("megaco_text_parser_v1.yrl", 1040).
yeccpars2_317_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_318_,1}}).
-file("megaco_text_parser_v1.yrl", 1031).
yeccpars2_318_([__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_observed_event ( __4 , __3 , __1 )
  end | Stack].

-compile({inline,{yeccpars2_320_,1}}).
-file("megaco_text_parser_v1.yrl", 945).
yeccpars2_320_([__1 | Stack]) ->
 [begin
   ensure_NAME ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_321_,1}}).
-file("megaco_text_parser_v1.yrl", 1043).
yeccpars2_321_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_324_,1}}).
-file("megaco_text_parser_v1.yrl", 942).
yeccpars2_324_([__2,__1 | Stack]) ->
 [begin
   select_stream_or_other ( __1 , __2 )
  end | Stack].

-compile({inline,{yeccpars2_327_,1}}).
-file("megaco_text_parser_v1.yrl", 1043).
yeccpars2_327_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_328_,1}}).
-file("megaco_text_parser_v1.yrl", 1042).
yeccpars2_328_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_329_,1}}).
-file("megaco_text_parser_v1.yrl", 1039).
yeccpars2_329_([__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_330_,1}}).
-file("megaco_text_parser_v1.yrl", 1033).
yeccpars2_330_([__2,__1 | Stack]) ->
 [begin
   merge_observed_event ( __2 , __1 , asn1_NOVALUE )
  end | Stack].

-compile({inline,{yeccpars2_332_,1}}).
-file("megaco_text_parser_v1.yrl", 1035).
yeccpars2_332_([__3,__2,__1 | Stack]) ->
 [begin
   __1
  end | Stack].

-compile({inline,{yeccpars2_333_,1}}).
-file("megaco_text_parser_v1.yrl", 648).
yeccpars2_333_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   make_commandRequest ( { notifyReq , __1 } ,
    setelement ( # 'NotifyRequest' .terminationID , __5 , [ __3 ] ) )
  end | Stack].

-compile({inline,{yeccpars2_335_,1}}).
-file("megaco_text_parser_v1.yrl", 462).
yeccpars2_335_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_336_,1}}).
-file("megaco_text_parser_v1.yrl", 466).
yeccpars2_336_([__1 | Stack]) ->
 [begin
   emergencyAudit
  end | Stack].

-compile({inline,{yeccpars2_337_,1}}).
-file("megaco_text_parser_v1.yrl", 467).
yeccpars2_337_([__1 | Stack]) ->
 [begin
   priorityAudit
  end | Stack].

-compile({inline,{yeccpars2_338_,1}}).
-file("megaco_text_parser_v1.yrl", 465).
yeccpars2_338_([__1 | Stack]) ->
 [begin
   topologyAudit
  end | Stack].

-compile({inline,{yeccpars2_341_,1}}).
-file("megaco_text_parser_v1.yrl", 462).
yeccpars2_341_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_342_,1}}).
-file("megaco_text_parser_v1.yrl", 461).
yeccpars2_342_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_343_,1}}).
-file("megaco_text_parser_v1.yrl", 457).
yeccpars2_343_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_345_,1}}).
-file("megaco_text_parser_v1.yrl", 564).
yeccpars2_345_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_346_,1}}).
-file("megaco_text_parser_v1.yrl", 568).
yeccpars2_346_([__4,__3,__2,__1 | Stack]) ->
 [begin
   make_commandRequest ( { auditValueRequest , __1 } ,
    # 'AuditRequest' { terminationID = __3 ,
    auditDescriptor = __4 } )
  end | Stack].

-compile({inline,{yeccpars2_348_,1}}).
-file("megaco_text_parser_v1.yrl", 564).
yeccpars2_348_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_349_,1}}).
-file("megaco_text_parser_v1.yrl", 573).
yeccpars2_349_([__4,__3,__2,__1 | Stack]) ->
 [begin
   make_commandRequest ( { auditCapRequest , __1 } ,
    # 'AuditRequest' { terminationID = __3 ,
    auditDescriptor = __4 } )
  end | Stack].

-compile({inline,{yeccpars2_352_,1}}).
-file("megaco_text_parser_v1.yrl", 443).
yeccpars2_352_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_353_,1}}).
-file("megaco_text_parser_v1.yrl", 442).
yeccpars2_353_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_354_,1}}).
-file("megaco_text_parser_v1.yrl", 440).
yeccpars2_354_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_action_requests ( __3 , [ __5 | __6 ] )
  end | Stack].

-compile({inline,{yeccpars2_356_,1}}).
-file("megaco_text_parser_v1.yrl", 529).
yeccpars2_356_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_357_,1}}).
-file("megaco_text_parser_v1.yrl", 520).
yeccpars2_357_([__4,__3,__2,__1 | Stack]) ->
 [begin
   make_commandRequest ( __1 ,
    # 'AmmRequest' { terminationID = [ __3 ] ,
    descriptors = __4 } )
  end | Stack].

-compile({inline,{yeccpars2_359_,1}}).
-file("megaco_text_parser_v1.yrl", 540).
yeccpars2_359_([__1 | Stack]) ->
 [begin
   { signalsDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_360_,1}}).
-file("megaco_text_parser_v1.yrl", 537).
yeccpars2_360_([__1 | Stack]) ->
 [begin
   { muxDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_361_,1}}).
-file("megaco_text_parser_v1.yrl", 536).
yeccpars2_361_([__1 | Stack]) ->
 [begin
   { modemDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_362_,1}}).
-file("megaco_text_parser_v1.yrl", 535).
yeccpars2_362_([__1 | Stack]) ->
 [begin
   { mediaDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_363_,1}}).
-file("megaco_text_parser_v1.yrl", 538).
yeccpars2_363_([__1 | Stack]) ->
 [begin
   { eventsDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_364_,1}}).
-file("megaco_text_parser_v1.yrl", 539).
yeccpars2_364_([__1 | Stack]) ->
 [begin
   { eventBufferDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_365_,1}}).
-file("megaco_text_parser_v1.yrl", 541).
yeccpars2_365_([__1 | Stack]) ->
 [begin
   { digitMapDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_366_,1}}).
-file("megaco_text_parser_v1.yrl", 542).
yeccpars2_366_([__1 | Stack]) ->
 [begin
   { auditDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_367_,1}}).
-file("megaco_text_parser_v1.yrl", 532).
yeccpars2_367_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_368_,1}}).
-file("megaco_text_parser_v1.yrl", 1074).
yeccpars2_368_([__1 | Stack]) ->
 [begin
   ensure_DMD ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_369_,1}}).
-file("megaco_text_parser_v1.yrl", 829).
yeccpars2_369_([__1 | Stack]) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_370_,1}}).
-file("megaco_text_parser_v1.yrl", 865).
yeccpars2_370_([__1 | Stack]) ->
 [begin
   # 'EventsDescriptor' { requestID = asn1_NOVALUE ,
    eventList = [ ] }
  end | Stack].

-compile({inline,{yeccpars2_374_,1}}).
-file("megaco_text_parser_v1.yrl", 954).
yeccpars2_374_([__1 | Stack]) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_376_,1}}).
-file("megaco_text_parser_v1.yrl", 960).
yeccpars2_376_([__1 | Stack]) ->
 [begin
   { signal , __1 }
  end | Stack].

-compile({inline,{yeccpars2_377_,1}}).
-file("megaco_text_parser_v1.yrl", 957).
yeccpars2_377_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_378_,1}}).
-file("megaco_text_parser_v1.yrl", 964).
yeccpars2_378_([__1 | Stack]) ->
 [begin
   merge_signalRequest ( __1 , [ ] )
  end | Stack].

-compile({inline,{yeccpars2_379_,1}}).
-file("megaco_text_parser_v1.yrl", 959).
yeccpars2_379_([__1 | Stack]) ->
 [begin
   { seqSigList , __1 }
  end | Stack].

-compile({inline,{yeccpars2_381_,1}}).
-file("megaco_text_parser_v1.yrl", 1264).
yeccpars2_381_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_384_,1}}).
-file("megaco_text_parser_v1.yrl", 1013).
yeccpars2_384_([__1 | Stack]) ->
 [begin
   ensure_uint16 ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_387_,1}}).
-file("megaco_text_parser_v1.yrl", 1011).
yeccpars2_387_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_390_,1}}).
-file("megaco_text_parser_v1.yrl", 1011).
yeccpars2_390_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_391_,1}}).
-file("megaco_text_parser_v1.yrl", 1010).
yeccpars2_391_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_392_,1}}).
-file("megaco_text_parser_v1.yrl", 1007).
yeccpars2_392_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'SeqSigList' { id = ensure_uint16 ( __3 ) ,
    signalList = [ __5 | __6 ] }
  end | Stack].

-compile({inline,{yeccpars2_394_,1}}).
-file("megaco_text_parser_v1.yrl", 967).
yeccpars2_394_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_396_,1}}).
-file("megaco_text_parser_v1.yrl", 1200).
yeccpars2_396_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_397_COMMA,1}}).
-file("megaco_text_parser_v1.yrl", 991).
yeccpars2_397_COMMA([__1 | Stack]) ->
 [begin
   keepActive
  end | Stack].

-compile({inline,{yeccpars2_397_RBRKT,1}}).
-file("megaco_text_parser_v1.yrl", 991).
yeccpars2_397_RBRKT([__1 | Stack]) ->
 [begin
   keepActive
  end | Stack].

-compile({inline,{yeccpars2_397_,1}}).
-file("megaco_text_parser_v1.yrl", 1219).
yeccpars2_397_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_398_,1}}).
-file("megaco_text_parser_v1.yrl", 1237).
yeccpars2_398_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_399_,1}}).
-file("megaco_text_parser_v1.yrl", 1266).
yeccpars2_399_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_400_,1}}).
-file("megaco_text_parser_v1.yrl", 1268).
yeccpars2_400_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_402_,1}}).
-file("megaco_text_parser_v1.yrl", 984).
yeccpars2_402_([__3,__2,__1 | Stack]) ->
 [begin
   { stream , __3 }
  end | Stack].

-compile({inline,{yeccpars2_403_,1}}).
-file("megaco_text_parser_v1.yrl", 860).
yeccpars2_403_([__1 | Stack]) ->
 [begin
   ensure_streamID ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_405_,1}}).
-file("megaco_text_parser_v1.yrl", 985).
yeccpars2_405_([__3,__2,__1 | Stack]) ->
 [begin
   { signal_type , __3 }
  end | Stack].

-compile({inline,{yeccpars2_406_,1}}).
-file("megaco_text_parser_v1.yrl", 995).
yeccpars2_406_([__1 | Stack]) ->
 [begin
   brief
  end | Stack].

-compile({inline,{yeccpars2_407_,1}}).
-file("megaco_text_parser_v1.yrl", 993).
yeccpars2_407_([__1 | Stack]) ->
 [begin
   onOff
  end | Stack].

-compile({inline,{yeccpars2_408_,1}}).
-file("megaco_text_parser_v1.yrl", 994).
yeccpars2_408_([__1 | Stack]) ->
 [begin
   timeOut
  end | Stack].

-compile({inline,{yeccpars2_411_,1}}).
-file("megaco_text_parser_v1.yrl", 998).
yeccpars2_411_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_412_,1}}).
-file("megaco_text_parser_v1.yrl", 1001).
yeccpars2_412_([__1 | Stack]) ->
 [begin
   onInterruptByEvent
  end | Stack].

-compile({inline,{yeccpars2_413_,1}}).
-file("megaco_text_parser_v1.yrl", 1002).
yeccpars2_413_([__1 | Stack]) ->
 [begin
   onInterruptByNewSignalDescr
  end | Stack].

-compile({inline,{yeccpars2_414_,1}}).
-file("megaco_text_parser_v1.yrl", 1003).
yeccpars2_414_([__1 | Stack]) ->
 [begin
   otherReason
  end | Stack].

-compile({inline,{yeccpars2_415_,1}}).
-file("megaco_text_parser_v1.yrl", 1000).
yeccpars2_415_([__1 | Stack]) ->
 [begin
   onTimeOut
  end | Stack].

-compile({inline,{yeccpars2_418_,1}}).
-file("megaco_text_parser_v1.yrl", 998).
yeccpars2_418_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_419_,1}}).
-file("megaco_text_parser_v1.yrl", 997).
yeccpars2_419_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_420_,1}}).
-file("megaco_text_parser_v1.yrl", 990).
yeccpars2_420_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   { notify_completion , [ __4 | __5 ] }
  end | Stack].

-compile({inline,{yeccpars2_422_,1}}).
-file("megaco_text_parser_v1.yrl", 986).
yeccpars2_422_([__3,__2,__1 | Stack]) ->
 [begin
   { duration , ensure_uint16 ( __3 ) }
  end | Stack].

-compile({inline,{yeccpars2_423_,1}}).
-file("megaco_text_parser_v1.yrl", 987).
yeccpars2_423_([__2,__1 | Stack]) ->
 [begin
   { other , ensure_NAME ( __1 ) , __2 }
  end | Stack].

-compile({inline,{yeccpars2_426_,1}}).
-file("megaco_text_parser_v1.yrl", 967).
yeccpars2_426_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_427_,1}}).
-file("megaco_text_parser_v1.yrl", 966).
yeccpars2_427_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_428_,1}}).
-file("megaco_text_parser_v1.yrl", 963).
yeccpars2_428_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_signalRequest ( __1 , [ __3 | __4 ] )
  end | Stack].

-compile({inline,{yeccpars2_431_,1}}).
-file("megaco_text_parser_v1.yrl", 957).
yeccpars2_431_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_432_,1}}).
-file("megaco_text_parser_v1.yrl", 956).
yeccpars2_432_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_433_,1}}).
-file("megaco_text_parser_v1.yrl", 952).
yeccpars2_433_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_435_,1}}).
-file("megaco_text_parser_v1.yrl", 858).
yeccpars2_435_([__1 | Stack]) ->
 [begin
   ensure_muxType ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_437_,1}}).
-file("megaco_text_parser_v1.yrl", 855).
yeccpars2_437_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'MuxDescriptor' { muxType = __3 ,
    termList = __4 }
  end | Stack].

-compile({inline,{yeccpars2_439_,1}}).
-file("megaco_text_parser_v1.yrl", 727).
yeccpars2_439_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_442_,1}}).
-file("megaco_text_parser_v1.yrl", 727).
yeccpars2_442_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_443_,1}}).
-file("megaco_text_parser_v1.yrl", 726).
yeccpars2_443_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_444_,1}}).
-file("megaco_text_parser_v1.yrl", 723).
yeccpars2_444_([__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_447_,1}}).
-file("megaco_text_parser_v1.yrl", 1071).
yeccpars2_447_([__1 | Stack]) ->
 [begin
   ensure_modemType ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_448_,1}}).
-file("megaco_text_parser_v1.yrl", 1061).
yeccpars2_448_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_451_,1}}).
-file("megaco_text_parser_v1.yrl", 1061).
yeccpars2_451_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_452_,1}}).
-file("megaco_text_parser_v1.yrl", 1060).
yeccpars2_452_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_453_,1}}).
-file("megaco_text_parser_v1.yrl", 1064).
yeccpars2_453_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_454_,1}}).
-file("megaco_text_parser_v1.yrl", 1057).
yeccpars2_454_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'ModemDescriptor' { mtl = [ __3 | __4 ] ,
    mpl = __6 }
  end | Stack].

-compile({inline,{yeccpars2_456_,1}}).
-file("megaco_text_parser_v1.yrl", 1067).
yeccpars2_456_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_458_,1}}).
-file("megaco_text_parser_v1.yrl", 795).
yeccpars2_458_([__2,__1 | Stack]) ->
 [begin
   setelement ( # 'PropertyParm' .name , __2 , __1 )
  end | Stack].

-compile({inline,{yeccpars2_461_,1}}).
-file("megaco_text_parser_v1.yrl", 1067).
yeccpars2_461_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_462_,1}}).
-file("megaco_text_parser_v1.yrl", 1066).
yeccpars2_462_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_463_,1}}).
-file("megaco_text_parser_v1.yrl", 1063).
yeccpars2_463_([__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_464_,1}}).
-file("megaco_text_parser_v1.yrl", 1064).
yeccpars2_464_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_465_,1}}).
-file("megaco_text_parser_v1.yrl", 1051).
yeccpars2_465_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'ModemDescriptor' { mtl = [ __3 ] ,
    mpl = __4 }
  end | Stack].

-compile({inline,{yeccpars2_467_,1}}).
-file("megaco_text_parser_v1.yrl", 748).
yeccpars2_467_([__1 | Stack]) ->
 [begin
   { termState , __1 }
  end | Stack].

-compile({inline,{yeccpars2_468_,1}}).
-file("megaco_text_parser_v1.yrl", 744).
yeccpars2_468_([__1 | Stack]) ->
 [begin
   { streamParm , __1 }
  end | Stack].

-compile({inline,{yeccpars2_469_,1}}).
-file("megaco_text_parser_v1.yrl", 746).
yeccpars2_469_([__1 | Stack]) ->
 [begin
   { streamDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_470_,1}}).
-file("megaco_text_parser_v1.yrl", 738).
yeccpars2_470_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_471_,1}}).
-file("megaco_text_parser_v1.yrl", 756).
yeccpars2_471_([__1 | Stack]) ->
 [begin
   { control , __1 }
  end | Stack].

-compile({inline,{yeccpars2_473_,1}}).
-file("megaco_text_parser_v1.yrl", 753).
yeccpars2_473_([__1 | Stack]) ->
 [begin
   { local , # 'LocalRemoteDescriptor' { propGrps = ensure_prop_groups ( __1 ) } }
  end | Stack].

-compile({inline,{yeccpars2_474_,1}}).
-file("megaco_text_parser_v1.yrl", 755).
yeccpars2_474_([__1 | Stack]) ->
 [begin
   { remote , # 'LocalRemoteDescriptor' { propGrps = ensure_prop_groups ( __1 ) } }
  end | Stack].

-compile({inline,{yeccpars2_478_,1}}).
-file("megaco_text_parser_v1.yrl", 777).
yeccpars2_478_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_479_,1}}).
-file("megaco_text_parser_v1.yrl", 839).
yeccpars2_479_([__1 | Stack]) ->
 [begin
   { serviceState , __1 }
  end | Stack].

-compile({inline,{yeccpars2_480_,1}}).
-file("megaco_text_parser_v1.yrl", 841).
yeccpars2_480_([__1 | Stack]) ->
 [begin
   { propertyParm , __1 }
  end | Stack].

-compile({inline,{yeccpars2_481_,1}}).
-file("megaco_text_parser_v1.yrl", 840).
yeccpars2_481_([__1 | Stack]) ->
 [begin
   { eventBufferControl , __1 }
  end | Stack].

-compile({inline,{yeccpars2_482_,1}}).
-file("megaco_text_parser_v1.yrl", 1192).
yeccpars2_482_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_483_,1}}).
-file("megaco_text_parser_v1.yrl", 1261).
yeccpars2_483_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_485_,1}}).
-file("megaco_text_parser_v1.yrl", 843).
yeccpars2_485_([__3,__2,__1 | Stack]) ->
 [begin
   __3
  end | Stack].

-compile({inline,{yeccpars2_486_,1}}).
-file("megaco_text_parser_v1.yrl", 847).
yeccpars2_486_([__1 | Stack]) ->
 [begin
   inSvc
  end | Stack].

-compile({inline,{yeccpars2_487_,1}}).
-file("megaco_text_parser_v1.yrl", 846).
yeccpars2_487_([__1 | Stack]) ->
 [begin
   outOfSvc
  end | Stack].

-compile({inline,{yeccpars2_488_,1}}).
-file("megaco_text_parser_v1.yrl", 845).
yeccpars2_488_([__1 | Stack]) ->
 [begin
   test
  end | Stack].

-compile({inline,{yeccpars2_490_,1}}).
-file("megaco_text_parser_v1.yrl", 849).
yeccpars2_490_([__3,__2,__1 | Stack]) ->
 [begin
   __3
  end | Stack].

-compile({inline,{yeccpars2_491_,1}}).
-file("megaco_text_parser_v1.yrl", 852).
yeccpars2_491_([__1 | Stack]) ->
 [begin
   lockStep
  end | Stack].

-compile({inline,{yeccpars2_492_,1}}).
-file("megaco_text_parser_v1.yrl", 851).
yeccpars2_492_([__1 | Stack]) ->
 [begin
   off
  end | Stack].

-compile({inline,{yeccpars2_495_,1}}).
-file("megaco_text_parser_v1.yrl", 777).
yeccpars2_495_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_496_,1}}).
-file("megaco_text_parser_v1.yrl", 776).
yeccpars2_496_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_497_,1}}).
-file("megaco_text_parser_v1.yrl", 774).
yeccpars2_497_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_terminationStateDescriptor ( [ __3 | __4 ] )
  end | Stack].

-compile({inline,{yeccpars2_501_,1}}).
-file("megaco_text_parser_v1.yrl", 764).
yeccpars2_501_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_504_,1}}).
-file("megaco_text_parser_v1.yrl", 764).
yeccpars2_504_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_505_,1}}).
-file("megaco_text_parser_v1.yrl", 763).
yeccpars2_505_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_506_,1}}).
-file("megaco_text_parser_v1.yrl", 760).
yeccpars2_506_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'StreamDescriptor' { streamID = __3 ,
    streamParms = merge_streamParms ( [ __5 | __6 ] ) }
  end | Stack].

-compile({inline,{yeccpars2_508_,1}}).
-file("megaco_text_parser_v1.yrl", 783).
yeccpars2_508_([__1 | Stack]) ->
 [begin
   { prop , __1 }
  end | Stack].

-compile({inline,{yeccpars2_509_,1}}).
-file("megaco_text_parser_v1.yrl", 770).
yeccpars2_509_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_510_,1}}).
-file("megaco_text_parser_v1.yrl", 1229).
yeccpars2_510_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_511_,1}}).
-file("megaco_text_parser_v1.yrl", 1256).
yeccpars2_511_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_512_,1}}).
-file("megaco_text_parser_v1.yrl", 1257).
yeccpars2_512_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_514_,1}}).
-file("megaco_text_parser_v1.yrl", 781).
yeccpars2_514_([__3,__2,__1 | Stack]) ->
 [begin
   { value , __3 }
  end | Stack].

-compile({inline,{yeccpars2_515_,1}}).
-file("megaco_text_parser_v1.yrl", 786).
yeccpars2_515_([__1 | Stack]) ->
 [begin
   false
  end | Stack].

-compile({inline,{yeccpars2_516_,1}}).
-file("megaco_text_parser_v1.yrl", 785).
yeccpars2_516_([__1 | Stack]) ->
 [begin
   true
  end | Stack].

-compile({inline,{yeccpars2_518_,1}}).
-file("megaco_text_parser_v1.yrl", 780).
yeccpars2_518_([__3,__2,__1 | Stack]) ->
 [begin
   { group , __3 }
  end | Stack].

-compile({inline,{yeccpars2_520_,1}}).
-file("megaco_text_parser_v1.yrl", 782).
yeccpars2_520_([__3,__2,__1 | Stack]) ->
 [begin
   { mode , __3 }
  end | Stack].

-compile({inline,{yeccpars2_521_,1}}).
-file("megaco_text_parser_v1.yrl", 792).
yeccpars2_521_([__1 | Stack]) ->
 [begin
   inactive
  end | Stack].

-compile({inline,{yeccpars2_522_,1}}).
-file("megaco_text_parser_v1.yrl", 793).
yeccpars2_522_([__1 | Stack]) ->
 [begin
   loopBack
  end | Stack].

-compile({inline,{yeccpars2_523_,1}}).
-file("megaco_text_parser_v1.yrl", 790).
yeccpars2_523_([__1 | Stack]) ->
 [begin
   recvOnly
  end | Stack].

-compile({inline,{yeccpars2_524_,1}}).
-file("megaco_text_parser_v1.yrl", 789).
yeccpars2_524_([__1 | Stack]) ->
 [begin
   sendOnly
  end | Stack].

-compile({inline,{yeccpars2_525_,1}}).
-file("megaco_text_parser_v1.yrl", 791).
yeccpars2_525_([__1 | Stack]) ->
 [begin
   sendRecv
  end | Stack].

-compile({inline,{yeccpars2_528_,1}}).
-file("megaco_text_parser_v1.yrl", 770).
yeccpars2_528_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_529_,1}}).
-file("megaco_text_parser_v1.yrl", 769).
yeccpars2_529_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_530_,1}}).
-file("megaco_text_parser_v1.yrl", 767).
yeccpars2_530_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_533_,1}}).
-file("megaco_text_parser_v1.yrl", 738).
yeccpars2_533_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_534_,1}}).
-file("megaco_text_parser_v1.yrl", 737).
yeccpars2_534_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_535_,1}}).
-file("megaco_text_parser_v1.yrl", 735).
yeccpars2_535_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_mediaDescriptor ( [ __3 | __4 ] )
  end | Stack].

-compile({inline,{yeccpars2_539_,1}}).
-file("megaco_text_parser_v1.yrl", 873).
yeccpars2_539_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_540_,1}}).
-file("megaco_text_parser_v1.yrl", 881).
yeccpars2_540_(Stack) ->
 [begin
   # 'RequestedEvent' { evParList = [ ] }
  end | Stack].

-compile({inline,{yeccpars2_541_,1}}).
-file("megaco_text_parser_v1.yrl", 876).
yeccpars2_541_([__2,__1 | Stack]) ->
 [begin
   setelement ( # 'RequestedEvent' .pkgdName , __2 , __1 )
  end | Stack].

-compile({inline,{yeccpars2_544_,1}}).
-file("megaco_text_parser_v1.yrl", 886).
yeccpars2_544_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_548_,1}}).
-file("megaco_text_parser_v1.yrl", 948).
yeccpars2_548_([__1 | Stack]) ->
 [begin
   ensure_eventDM ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_549_,1}}).
-file("megaco_text_parser_v1.yrl", 1201).
yeccpars2_549_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_550_COMMA,1}}).
-file("megaco_text_parser_v1.yrl", 889).
yeccpars2_550_COMMA([__1 | Stack]) ->
 [begin
   keepActive
  end | Stack].

-compile({inline,{yeccpars2_550_RBRKT,1}}).
-file("megaco_text_parser_v1.yrl", 889).
yeccpars2_550_RBRKT([__1 | Stack]) ->
 [begin
   keepActive
  end | Stack].

-compile({inline,{yeccpars2_550_,1}}).
-file("megaco_text_parser_v1.yrl", 1219).
yeccpars2_550_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_554_,1}}).
-file("megaco_text_parser_v1.yrl", 905).
yeccpars2_554_([__1 | Stack]) ->
 [begin
   # 'SecondEventsDescriptor' { requestID = asn1_NOVALUE ,
    eventList = [ ] }
  end | Stack].

-compile({inline,{yeccpars2_558_,1}}).
-file("megaco_text_parser_v1.yrl", 915).
yeccpars2_558_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_559_,1}}).
-file("megaco_text_parser_v1.yrl", 926).
yeccpars2_559_(Stack) ->
 [begin
   # 'SecondRequestedEvent' { evParList = [ ] }
  end | Stack].

-compile({inline,{yeccpars2_560_,1}}).
-file("megaco_text_parser_v1.yrl", 919).
yeccpars2_560_([__2,__1 | Stack]) ->
 [begin
   setelement ( # 'SecondRequestedEvent' .pkgdName ,
    __2 , __1 )
  end | Stack].

-compile({inline,{yeccpars2_562_,1}}).
-file("megaco_text_parser_v1.yrl", 930).
yeccpars2_562_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_566_,1}}).
-file("megaco_text_parser_v1.yrl", 1201).
yeccpars2_566_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_567_COMMA,1}}).
-file("megaco_text_parser_v1.yrl", 933).
yeccpars2_567_COMMA([__1 | Stack]) ->
 [begin
   keepActive
  end | Stack].

-compile({inline,{yeccpars2_567_RBRKT,1}}).
-file("megaco_text_parser_v1.yrl", 933).
yeccpars2_567_RBRKT([__1 | Stack]) ->
 [begin
   keepActive
  end | Stack].

-compile({inline,{yeccpars2_567_,1}}).
-file("megaco_text_parser_v1.yrl", 1219).
yeccpars2_567_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_570_,1}}).
-file("megaco_text_parser_v1.yrl", 939).
yeccpars2_570_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { second_embed , __3 }
  end | Stack].

-compile({inline,{yeccpars2_573_,1}}).
-file("megaco_text_parser_v1.yrl", 930).
yeccpars2_573_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_574_,1}}).
-file("megaco_text_parser_v1.yrl", 929).
yeccpars2_574_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_575_,1}}).
-file("megaco_text_parser_v1.yrl", 924).
yeccpars2_575_([__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_secondEventParameters ( [ __2 | __3 ] )
  end | Stack].

-compile({inline,{yeccpars2_578_,1}}).
-file("megaco_text_parser_v1.yrl", 915).
yeccpars2_578_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_579_,1}}).
-file("megaco_text_parser_v1.yrl", 914).
yeccpars2_579_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_580_,1}}).
-file("megaco_text_parser_v1.yrl", 910).
yeccpars2_580_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'SecondEventsDescriptor' { requestID = __3 ,
    eventList = [ __5 | __6 ] }
  end | Stack].

-compile({inline,{yeccpars2_581_,1}}).
-file("megaco_text_parser_v1.yrl", 902).
yeccpars2_581_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { embed , asn1_NOVALUE , __3 }
  end | Stack].

-compile({inline,{yeccpars2_583_,1}}).
-file("megaco_text_parser_v1.yrl", 899).
yeccpars2_583_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { embed , __3 , asn1_NOVALUE }
  end | Stack].

-compile({inline,{yeccpars2_585_,1}}).
-file("megaco_text_parser_v1.yrl", 897).
yeccpars2_585_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   { embed , __3 , __5 }
  end | Stack].

-compile({inline,{yeccpars2_588_,1}}).
-file("megaco_text_parser_v1.yrl", 886).
yeccpars2_588_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_589_,1}}).
-file("megaco_text_parser_v1.yrl", 884).
yeccpars2_589_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_590_,1}}).
-file("megaco_text_parser_v1.yrl", 879).
yeccpars2_590_([__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_eventParameters ( [ __2 | __3 ] )
  end | Stack].

-compile({inline,{yeccpars2_593_,1}}).
-file("megaco_text_parser_v1.yrl", 873).
yeccpars2_593_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_594_,1}}).
-file("megaco_text_parser_v1.yrl", 872).
yeccpars2_594_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_595_,1}}).
-file("megaco_text_parser_v1.yrl", 869).
yeccpars2_595_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'EventsDescriptor' { requestID = __3 ,
    eventList = [ __5 | __6 ] }
  end | Stack].

-compile({inline,{yeccpars2_596_,1}}).
-file("megaco_text_parser_v1.yrl", 1036).
yeccpars2_596_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_597_,1}}).
-file("megaco_text_parser_v1.yrl", 836).
yeccpars2_597_([__1 | Stack]) ->
 [begin
   merge_eventSpec ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_598_,1}}).
-file("megaco_text_parser_v1.yrl", 834).
yeccpars2_598_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_600_,1}}).
-file("megaco_text_parser_v1.yrl", 1036).
yeccpars2_600_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_601_,1}}).
-file("megaco_text_parser_v1.yrl", 834).
yeccpars2_601_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_602_,1}}).
-file("megaco_text_parser_v1.yrl", 833).
yeccpars2_602_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_603_,1}}).
-file("megaco_text_parser_v1.yrl", 831).
yeccpars2_603_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_606_,1}}).
-file("megaco_text_parser_v1.yrl", 532).
yeccpars2_606_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_607_,1}}).
-file("megaco_text_parser_v1.yrl", 531).
yeccpars2_607_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_608_,1}}).
-file("megaco_text_parser_v1.yrl", 528).
yeccpars2_608_([__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_611_,1}}).
-file("megaco_text_parser_v1.yrl", 436).
yeccpars2_611_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_612_,1}}).
-file("megaco_text_parser_v1.yrl", 435).
yeccpars2_612_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_613_,1}}).
-file("megaco_text_parser_v1.yrl", 423).
yeccpars2_613_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'TransactionRequest' { transactionId = asn1_NOVALUE ,
    actions = [ __3 | __4 ] }
  end | Stack].

-compile({inline,{yeccpars2_615_,1}}).
-file("megaco_text_parser_v1.yrl", 690).
yeccpars2_615_([__1 | Stack]) ->
 [begin
   ensure_uint32 ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_617_,1}}).
-file("megaco_text_parser_v1.yrl", 436).
yeccpars2_617_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_619_,1}}).
-file("megaco_text_parser_v1.yrl", 427).
yeccpars2_619_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'TransactionRequest' { transactionId = asn1_NOVALUE ,
    actions = [ __4 | __5 ] }
  end | Stack].

-compile({inline,{yeccpars2_621_,1}}).
-file("megaco_text_parser_v1.yrl", 436).
yeccpars2_621_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_623_,1}}).
-file("megaco_text_parser_v1.yrl", 431).
yeccpars2_623_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'TransactionRequest' { transactionId = ensure_transactionID ( __3 ) ,
    actions = [ __5 | __6 ] }
  end | Stack].

-compile({inline,{yeccpars2_625_,1}}).
-file("megaco_text_parser_v1.yrl", 414).
yeccpars2_625_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_626_,1}}).
-file("megaco_text_parser_v1.yrl", 416).
yeccpars2_626_([__1 | Stack]) ->
 [begin
   ensure_transactionAck ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_629_,1}}).
-file("megaco_text_parser_v1.yrl", 414).
yeccpars2_629_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_630_,1}}).
-file("megaco_text_parser_v1.yrl", 413).
yeccpars2_630_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_631_,1}}).
-file("megaco_text_parser_v1.yrl", 411).
yeccpars2_631_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_634_,1}}).
-file("megaco_text_parser_v1.yrl", 483).
yeccpars2_634_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_637_,1}}).
-file("megaco_text_parser_v1.yrl", 482).
yeccpars2_637_([__2,__1 | Stack]) ->
 [begin
   'NULL'
  end | Stack].

-compile({inline,{yeccpars2_639_,1}}).
-file("megaco_text_parser_v1.yrl", 486).
yeccpars2_639_([__1 | Stack]) ->
 [begin
   { transactionError , __1 }
  end | Stack].

-compile({inline,{yeccpars2_640_,1}}).
-file("megaco_text_parser_v1.yrl", 491).
yeccpars2_640_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_645_,1}}).
-file("megaco_text_parser_v1.yrl", 502).
yeccpars2_645_([__1 | Stack]) ->
 [begin
   { command , __1 }
  end | Stack].

-compile({inline,{yeccpars2_646_,1}}).
-file("megaco_text_parser_v1.yrl", 505).
yeccpars2_646_([__1 | Stack]) ->
 [begin
   { command , __1 }
  end | Stack].

-compile({inline,{yeccpars2_647_,1}}).
-file("megaco_text_parser_v1.yrl", 498).
yeccpars2_647_([__1 | Stack]) ->
 [begin
   # 'ActionReply' { errorDescriptor = __1 }
  end | Stack].

-compile({inline,{yeccpars2_648_,1}}).
-file("megaco_text_parser_v1.yrl", 506).
yeccpars2_648_([__1 | Stack]) ->
 [begin
   { context , __1 }
  end | Stack].

-compile({inline,{yeccpars2_649_,1}}).
-file("megaco_text_parser_v1.yrl", 516).
yeccpars2_649_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_650_,1}}).
-file("megaco_text_parser_v1.yrl", 503).
yeccpars2_650_([__1 | Stack]) ->
 [begin
   { command , __1 }
  end | Stack].

-compile({inline,{yeccpars2_652_,1}}).
-file("megaco_text_parser_v1.yrl", 504).
yeccpars2_652_([__1 | Stack]) ->
 [begin
   { command , __1 }
  end | Stack].

-compile({inline,{yeccpars2_654_,1}}).
-file("megaco_text_parser_v1.yrl", 548).
yeccpars2_654_([__1 | Stack]) ->
 [begin
   addReply
  end | Stack].

-compile({inline,{yeccpars2_657_,1}}).
-file("megaco_text_parser_v1.yrl", 550).
yeccpars2_657_([__1 | Stack]) ->
 [begin
   modReply
  end | Stack].

-compile({inline,{yeccpars2_658_,1}}).
-file("megaco_text_parser_v1.yrl", 549).
yeccpars2_658_([__1 | Stack]) ->
 [begin
   moveReply
  end | Stack].

-compile({inline,{yeccpars2_661_,1}}).
-file("megaco_text_parser_v1.yrl", 551).
yeccpars2_661_([__1 | Stack]) ->
 [begin
   subtractReply
  end | Stack].

-compile({inline,{yeccpars2_663_,1}}).
-file("megaco_text_parser_v1.yrl", 679).
yeccpars2_663_(Stack) ->
 [begin
   { serviceChangeResParms , # 'ServiceChangeResParm' { } }
  end | Stack].

-compile({inline,{yeccpars2_664_,1}}).
-file("megaco_text_parser_v1.yrl", 671).
yeccpars2_664_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { serviceChangeReply ,
    # 'ServiceChangeReply' { terminationID = [ __3 ] ,
    serviceChangeResult = __4 } }
  end | Stack].

-compile({inline,{yeccpars2_670_,1}}).
-file("megaco_text_parser_v1.yrl", 1129).
yeccpars2_670_([__1 | Stack]) ->
 [begin
   { time_stamp , __1 }
  end | Stack].

-compile({inline,{yeccpars2_671_,1}}).
-file("megaco_text_parser_v1.yrl", 1128).
yeccpars2_671_([__1 | Stack]) ->
 [begin
   { version , __1 }
  end | Stack].

-compile({inline,{yeccpars2_672_,1}}).
-file("megaco_text_parser_v1.yrl", 1127).
yeccpars2_672_([__1 | Stack]) ->
 [begin
   { profile , __1 }
  end | Stack].

-compile({inline,{yeccpars2_673_,1}}).
-file("megaco_text_parser_v1.yrl", 1126).
yeccpars2_673_([__1 | Stack]) ->
 [begin
   { mgc_id , __1 }
  end | Stack].

-compile({inline,{yeccpars2_674_,1}}).
-file("megaco_text_parser_v1.yrl", 1125).
yeccpars2_674_([__1 | Stack]) ->
 [begin
   { address , __1 }
  end | Stack].

-compile({inline,{yeccpars2_675_,1}}).
-file("megaco_text_parser_v1.yrl", 1123).
yeccpars2_675_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_682_,1}}).
-file("megaco_text_parser_v1.yrl", 1123).
yeccpars2_682_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_683_,1}}).
-file("megaco_text_parser_v1.yrl", 1122).
yeccpars2_683_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_684_,1}}).
-file("megaco_text_parser_v1.yrl", 1119).
yeccpars2_684_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   merge_ServiceChangeResParm ( [ __3 | __4 ] )
  end | Stack].

-compile({inline,{yeccpars2_685_,1}}).
-file("megaco_text_parser_v1.yrl", 676).
yeccpars2_685_([__3,__2,__1 | Stack]) ->
 [begin
   { errorDescriptor , __2 }
  end | Stack].

-compile({inline,{yeccpars2_686_,1}}).
-file("megaco_text_parser_v1.yrl", 678).
yeccpars2_686_([__3,__2,__1 | Stack]) ->
 [begin
   { serviceChangeResParms , __2 }
  end | Stack].

-compile({inline,{yeccpars2_688_,1}}).
-file("megaco_text_parser_v1.yrl", 662).
yeccpars2_688_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_689_,1}}).
-file("megaco_text_parser_v1.yrl", 657).
yeccpars2_689_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { notifyReply ,
    # 'NotifyReply' { terminationID = [ __3 ] ,
    errorDescriptor = __4 } }
  end | Stack].

-compile({inline,{yeccpars2_692_,1}}).
-file("megaco_text_parser_v1.yrl", 661).
yeccpars2_692_([__3,__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_694_,1}}).
-file("megaco_text_parser_v1.yrl", 590).
yeccpars2_694_([__1 | Stack]) ->
 [begin
   { auditResult ,
    # 'AuditResult' { terminationID = __1 ,
    terminationAuditResult = [ ] } }
  end | Stack].

-compile({inline,{yeccpars2_695_,1}}).
-file("megaco_text_parser_v1.yrl", 582).
yeccpars2_695_([__3,__2,__1 | Stack]) ->
 [begin
   { auditValueReply , __3 }
  end | Stack].

-compile({inline,{yeccpars2_696_,1}}).
-file("megaco_text_parser_v1.yrl", 1193).
yeccpars2_696_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_697_,1}}).
-file("megaco_text_parser_v1.yrl", 586).
yeccpars2_697_([__1 | Stack]) ->
 [begin
   { contextAuditResult , __1 }
  end | Stack].

-compile({inline,{yeccpars2_698_,1}}).
-file("megaco_text_parser_v1.yrl", 578).
yeccpars2_698_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { auditValueReply , __4 }
  end | Stack].

-compile({inline,{yeccpars2_701_,1}}).
-file("megaco_text_parser_v1.yrl", 1203).
yeccpars2_701_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_703_,1}}).
-file("megaco_text_parser_v1.yrl", 685).
yeccpars2_703_([__1 | Stack]) ->
 [begin
   ensure_uint ( __1 , 0 , 999 )
  end | Stack].

-compile({inline,{yeccpars2_705_,1}}).
-file("megaco_text_parser_v1.yrl", 688).
yeccpars2_705_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_707_,1}}).
-file("megaco_text_parser_v1.yrl", 687).
yeccpars2_707_([__1 | Stack]) ->
 [begin
   value_of ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_708_,1}}).
-file("megaco_text_parser_v1.yrl", 682).
yeccpars2_708_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'ErrorDescriptor' { errorCode = __3 ,
    errorText = __5 }
  end | Stack].

-compile({inline,{yeccpars2_709_,1}}).
-file("megaco_text_parser_v1.yrl", 587).
yeccpars2_709_([__3,__2,__1 | Stack]) ->
 [begin
   { contextAuditResult , __2 }
  end | Stack].

-compile({inline,{yeccpars2_712_,1}}).
-file("megaco_text_parser_v1.yrl", 612).
yeccpars2_712_([__1 | Stack]) ->
 [begin
   { statisticsDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_713_,1}}).
-file("megaco_text_parser_v1.yrl", 608).
yeccpars2_713_([__1 | Stack]) ->
 [begin
   { signalsDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_714_,1}}).
-file("megaco_text_parser_v1.yrl", 613).
yeccpars2_714_([__1 | Stack]) ->
 [begin
   { packagesDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_715_,1}}).
-file("megaco_text_parser_v1.yrl", 610).
yeccpars2_715_([__1 | Stack]) ->
 [begin
   { observedEventsDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_716_,1}}).
-file("megaco_text_parser_v1.yrl", 606).
yeccpars2_716_([__1 | Stack]) ->
 [begin
   { muxDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_717_,1}}).
-file("megaco_text_parser_v1.yrl", 605).
yeccpars2_717_([__1 | Stack]) ->
 [begin
   { modemDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_718_,1}}).
-file("megaco_text_parser_v1.yrl", 604).
yeccpars2_718_([__1 | Stack]) ->
 [begin
   { mediaDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_719_,1}}).
-file("megaco_text_parser_v1.yrl", 607).
yeccpars2_719_([__1 | Stack]) ->
 [begin
   { eventsDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_720_,1}}).
-file("megaco_text_parser_v1.yrl", 611).
yeccpars2_720_([__1 | Stack]) ->
 [begin
   { eventBufferDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_721_,1}}).
-file("megaco_text_parser_v1.yrl", 614).
yeccpars2_721_([__1 | Stack]) ->
 [begin
   { errorDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_722_,1}}).
-file("megaco_text_parser_v1.yrl", 609).
yeccpars2_722_([__1 | Stack]) ->
 [begin
   { digitMapDescriptor , __1 }
  end | Stack].

-compile({inline,{yeccpars2_723_,1}}).
-file("megaco_text_parser_v1.yrl", 602).
yeccpars2_723_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_724_,1}}).
-file("megaco_text_parser_v1.yrl", 615).
yeccpars2_724_([__1 | Stack]) ->
 [begin
   { auditReturnItem , __1 }
  end | Stack].

-compile({inline,{yeccpars2_725_,1}}).
-file("megaco_text_parser_v1.yrl", 630).
yeccpars2_725_([__1 | Stack]) ->
 [begin
   mediaToken
  end | Stack].

-compile({inline,{yeccpars2_726_,1}}).
-file("megaco_text_parser_v1.yrl", 629).
yeccpars2_726_([__1 | Stack]) ->
 [begin
   modemToken
  end | Stack].

-compile({inline,{yeccpars2_727_,1}}).
-file("megaco_text_parser_v1.yrl", 628).
yeccpars2_727_([__1 | Stack]) ->
 [begin
   muxToken
  end | Stack].

-compile({inline,{yeccpars2_728_,1}}).
-file("megaco_text_parser_v1.yrl", 633).
yeccpars2_728_([__1 | Stack]) ->
 [begin
   observedEventsToken
  end | Stack].

-compile({inline,{yeccpars2_729_,1}}).
-file("megaco_text_parser_v1.yrl", 634).
yeccpars2_729_([__1 | Stack]) ->
 [begin
   packagesToken
  end | Stack].

-compile({inline,{yeccpars2_730_,1}}).
-file("megaco_text_parser_v1.yrl", 632).
yeccpars2_730_([__1 | Stack]) ->
 [begin
   statsToken
  end | Stack].

-compile({inline,{yeccpars2_732_,1}}).
-file("megaco_text_parser_v1.yrl", 1146).
yeccpars2_732_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_733_,1}}).
-file("megaco_text_parser_v1.yrl", 1150).
yeccpars2_733_([__1 | Stack]) ->
 [begin
   # 'StatisticsParameter' { statName = __1 ,
    statValue = asn1_NOVALUE }
  end | Stack].

-compile({inline,{yeccpars2_735_,1}}).
-file("megaco_text_parser_v1.yrl", 1153).
yeccpars2_735_([__3,__2,__1 | Stack]) ->
 [begin
   # 'StatisticsParameter' { statName = __1 ,
    statValue = [ __3 ] }
  end | Stack].

-compile({inline,{yeccpars2_738_,1}}).
-file("megaco_text_parser_v1.yrl", 1146).
yeccpars2_738_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_739_,1}}).
-file("megaco_text_parser_v1.yrl", 1145).
yeccpars2_739_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_740_,1}}).
-file("megaco_text_parser_v1.yrl", 1143).
yeccpars2_740_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_742_,1}}).
-file("megaco_text_parser_v1.yrl", 1137).
yeccpars2_742_([__1 | Stack]) ->
 [begin
   ensure_packagesItem ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_743_,1}}).
-file("megaco_text_parser_v1.yrl", 1135).
yeccpars2_743_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_746_,1}}).
-file("megaco_text_parser_v1.yrl", 1135).
yeccpars2_746_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_747_,1}}).
-file("megaco_text_parser_v1.yrl", 1134).
yeccpars2_747_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_748_,1}}).
-file("megaco_text_parser_v1.yrl", 1132).
yeccpars2_748_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __4 ]
  end | Stack].

-compile({inline,{yeccpars2_749_,1}}).
-file("megaco_text_parser_v1.yrl", 599).
yeccpars2_749_([__2,__1 | Stack]) ->
 [begin
   merge_terminationAudit ( [ __1 | __2 ] )
  end | Stack].

-compile({inline,{yeccpars2_751_,1}}).
-file("megaco_text_parser_v1.yrl", 602).
yeccpars2_751_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_752_,1}}).
-file("megaco_text_parser_v1.yrl", 601).
yeccpars2_752_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_753_,1}}).
-file("megaco_text_parser_v1.yrl", 594).
yeccpars2_753_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { auditResult ,
    # 'AuditResult' { terminationID = __1 ,
    terminationAuditResult = __3 } }
  end | Stack].

-compile({inline,{yeccpars2_755_,1}}).
-file("megaco_text_parser_v1.yrl", 584).
yeccpars2_755_([__3,__2,__1 | Stack]) ->
 [begin
   { auditCapReply , __3 }
  end | Stack].

-compile({inline,{yeccpars2_756_,1}}).
-file("megaco_text_parser_v1.yrl", 1193).
yeccpars2_756_([__1 | Stack]) ->
 [begin
   make_safe_token ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_757_,1}}).
-file("megaco_text_parser_v1.yrl", 580).
yeccpars2_757_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { auditCapReply , __4 }
  end | Stack].

-compile({inline,{yeccpars2_758_,1}}).
-file("megaco_text_parser_v1.yrl", 495).
yeccpars2_758_([__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   setelement ( # 'ActionReply' .contextId , __5 , __3 )
  end | Stack].

-compile({inline,{yeccpars2_760_,1}}).
-file("megaco_text_parser_v1.yrl", 554).
yeccpars2_760_(Stack) ->
 [begin
   asn1_NOVALUE
  end | Stack].

-compile({inline,{yeccpars2_761_,1}}).
-file("megaco_text_parser_v1.yrl", 545).
yeccpars2_761_([__4,__3,__2,__1 | Stack]) ->
 [begin
   { __1 , # 'AmmsReply' { terminationID = [ __3 ] ,
    terminationAudit = __4 } }
  end | Stack].

-compile({inline,{yeccpars2_764_,1}}).
-file("megaco_text_parser_v1.yrl", 553).
yeccpars2_764_([__3,__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_765_,1}}).
-file("megaco_text_parser_v1.yrl", 500).
yeccpars2_765_([__2,__1 | Stack]) ->
 [begin
   merge_action_reply ( [ __1 | __2 ] )
  end | Stack].

-compile({inline,{yeccpars2_767_,1}}).
-file("megaco_text_parser_v1.yrl", 513).
yeccpars2_767_([__2,__1 | Stack]) ->
 [begin
   [ __2 ]
  end | Stack].

-compile({inline,{yeccpars2_768_,1}}).
-file("megaco_text_parser_v1.yrl", 516).
yeccpars2_768_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_769_,1}}).
-file("megaco_text_parser_v1.yrl", 515).
yeccpars2_769_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_770_,1}}).
-file("megaco_text_parser_v1.yrl", 488).
yeccpars2_770_([__2,__1 | Stack]) ->
 [begin
   { actionReplies , [ __1 | __2 ] }
  end | Stack].

-compile({inline,{yeccpars2_772_,1}}).
-file("megaco_text_parser_v1.yrl", 491).
yeccpars2_772_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_773_,1}}).
-file("megaco_text_parser_v1.yrl", 490).
yeccpars2_773_([__3,__2,__1 | Stack]) ->
 [begin
   [ __2 | __3 ]
  end | Stack].

-compile({inline,{yeccpars2_774_,1}}).
-file("megaco_text_parser_v1.yrl", 478).
yeccpars2_774_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'TransactionReply' { transactionId = __3 ,
    immAckRequired = __5 ,
    transactionResult = __6 }
  end | Stack].

-compile({inline,{yeccpars2_778_,1}}).
-file("megaco_text_parser_v1.yrl", 419).
yeccpars2_778_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # 'TransactionPending' { transactionId = ensure_transactionID ( __3 ) }
  end | Stack].

-compile({inline,{yeccpars2_779_,1}}).
-file("megaco_text_parser_v1.yrl", 402).
yeccpars2_779_([__2,__1 | Stack]) ->
 [begin
   [ __1 | __2 ]
  end | Stack].

-compile({inline,{yeccpars2_780_,1}}).
-file("megaco_text_parser_v1.yrl", 730).
yeccpars2_780_([__1 | Stack]) ->
 [begin
   ensure_pathName ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_781_,1}}).
-file("megaco_text_parser_v1.yrl", 702).
yeccpars2_781_([__1 | Stack]) ->
 [begin
   { deviceName , __1 }
  end | Stack].

-compile({inline,{yeccpars2_782_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_782_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_783_,1}}).
-file("megaco_text_parser_v1.yrl", 388).
yeccpars2_783_(Stack) ->
 [begin
   no_sep
  end | Stack].

-compile({inline,{yeccpars2_784_,1}}).
-file("megaco_text_parser_v1.yrl", 718).
yeccpars2_784_([__1 | Stack]) ->
 [begin
   ensure_mtpAddress ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_785_,1}}).
-file("megaco_text_parser_v1.yrl", 695).
yeccpars2_785_([__3,__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_786_,1}}).
-file("megaco_text_parser_v1.yrl", 694).
yeccpars2_786_([__3,__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].


-file("megaco_text_parser_v1.yrl", 1309).
