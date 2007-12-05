-module(edoc_parser).
-export([parse/1, parse_and_scan/1, format_error/1]).
-file("edoc_parser.yrl", 200).

%% ========================== -*-Erlang-*- =============================
%% EDoc function specification parser, generated from the file
%% "edoc_parser.yrl" by the Yecc parser generator.
%%
%% Copyright (C) 2002-2005 Richard Carlsson
%%
%% This library is free software; you can redistribute it and/or modify
%% it under the terms of the GNU Lesser General Public License as
%% published by the Free Software Foundation; either version 2 of the
%% License, or (at your option) any later version.
%%
%% This library is distributed in the hope that it will be useful, but
%% WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
%% Lesser General Public License for more details.
%%
%% You should have received a copy of the GNU Lesser General Public
%% License along with this library; if not, write to the Free Software
%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
%% USA
%% ====================================================================

-export([parse_spec/2, parse_typedef/2, parse_throws/2, parse_ref/2,
	 parse_see/2, parse_param/2]).

-include("edoc_types.hrl").

%% Multiple entry point hack:

start_spec(Ts, L) -> run_parser(Ts, L, start_spec).

start_typedef(Ts, L) -> run_parser(Ts, L, start_typedef).

start_throws(Ts, L) -> run_parser(Ts, L, start_throws).

start_ref(Ts, L) -> run_parser(Ts, L, start_ref).

%% Error reporting fix

run_parser(Ts, L, Start) ->
    case parse([{Start,L} | Ts]) of
	{error, {999999,?MODULE,_}} ->
	    What = case Start of
		       start_spec -> "specification";
		       start_typedef -> "type definition";
		       start_throws -> "exception declaration";
		       start_ref -> "reference"
		   end,
	    {error, {L,?MODULE,["unexpected end of ", What]}};
	Other -> Other
    end.

%% Utility functions:

tok_val(T) -> element(3, T).

tok_line(T) -> element(2, T).

qname([A]) ->
    A;    % avoid unnecessary call to packages:concat/1.
qname(List) ->
    list_to_atom(packages:concat(lists:reverse(List))).

union(Ts) ->
    case Ts of
	[T] -> T;
	_ -> #t_union{types = lists:reverse(Ts)}
    end.

annotate(T, A) -> ?add_t_ann(T, A).
    
%% ---------------------------------------------------------------------

%% @doc EDoc type specification parsing. Parses the content of
%% <a href="overview-summary.html#ftag-spec">`@spec'</a> declarations.

parse_spec(S, L) ->
    case edoc_scanner:string(S, L) of
	{ok, Ts, _} ->
	    case start_spec(Ts, L) of
		{ok, Spec} ->
		    Spec;
		{error, E} ->
		    throw_error(E, L)
	    end;
	{error, E, _} ->
	    throw_error(E, L)
    end.

%% ---------------------------------------------------------------------

%% @doc EDoc type definition parsing. Parses the content of
%% <a href="overview-summary.html#gtag-type">`@type'</a> declarations.

parse_typedef(S, L) ->
    {S1, S2} = edoc_lib:split_at_stop(S),
    N = edoc_lib:count($\n, S1),
    L1 = L + N,
    Text = edoc_lib:strip_space(S2),
    {parse_typedef_1(S1, L), edoc_wiki:parse_xml(Text, L1)}.

parse_typedef_1(S, L) ->
    case edoc_scanner:string(S, L) of
	{ok, Ts, _} ->
	    case start_typedef(Ts, L) of
		{ok, T} ->
		    T;
		{error, E} ->
		    throw_error({parse_typedef, E}, L)
	    end;
	{error, E, _} ->
	    throw_error({parse_typedef, E}, L)
    end.

%% ---------------------------------------------------------------------

%% @doc Parses a <a
%% href="overview-summary.html#References">reference</a> to a module,
%% package, function, type, or application

parse_ref(S, L) ->
    case edoc_scanner:string(S, L) of
	{ok, Ts, _} ->
	    case start_ref(Ts, L) of
		{ok, T} ->
		    T;
		{error, E} ->
		    throw_error({parse_ref, E}, L)
	    end;
	{error, E, _} ->
	    throw_error({parse_ref, E}, L)
    end.

%% ---------------------------------------------------------------------

%% @doc Parses the content of
%% <a href="overview-summary.html#ftag-see">`@see'</a> references.
parse_see(S, L) ->
    {S1, S2} = edoc_lib:split_at_stop(S),
    N = edoc_lib:count($\n, S1),
    L1 = L + N,
    Text = edoc_lib:strip_space(S2),
    {parse_ref(S1, L), edoc_wiki:parse_xml(Text, L1)}.

%% ---------------------------------------------------------------------

%% @doc Parses the content of
%% <a href="overview-summary.html#ftag-param">`@param'</a> tags.
parse_param(S, L) ->
    {S1, S2} = edoc_lib:split_at_space(edoc_lib:strip_space(S)),
    case edoc_lib:strip_space(S1) of
	"" -> throw_error(parse_param, L);
	Name -> 
	    Text = edoc_lib:strip_space(S2),
	    {list_to_atom(Name), edoc_wiki:parse_xml(Text, L)}
    end.

%% ---------------------------------------------------------------------

%% @doc EDoc exception specification parsing. Parses the content of
%% <a href="overview-summary.html#ftag-throws">`@throws'</a> declarations.

parse_throws(S, L) ->
    case edoc_scanner:string(S, L) of
	{ok, Ts, _} ->
	    case start_throws(Ts, L) of
		{ok, Spec} ->
		    Spec;
		{error, E} ->
		    throw_error({parse_throws, E}, L)
	    end;
	{error, E, _} ->
	    throw_error({parse_throws, E}, L)
    end.

%% ---------------------------------------------------------------------

throw_error({L, M, D}, _L0) ->
    throw({error,L,{format_error,M,D}});
throw_error({parse_spec, E}, L) ->
    throw_error({"specification", E}, L);
throw_error({parse_typedef, E}, L) ->
    throw_error({"type definition", E}, L);
throw_error({parse_ref, E}, L) ->
    throw_error({"reference", E}, L);
throw_error({parse_throws, E}, L) ->
    throw_error({"throws-declaration", E}, L);
throw_error(parse_param, L) ->
    throw({error, L, "missing parameter name"});
throw_error({Where, E}, L) when is_list(Where) ->
    throw({error,L,{"unknown error parsing ~s: ~P.",[Where,E,15]}});
throw_error(E, L) ->
    %% Just in case.
    throw({error,L,{"unknown parse error: ~P.",[E,15]}}).

-file("/ldisk/daily_build/otp_prebuild_r12b.2007-12-04_15/otp_src_R12B-0/bootstrap/lib/parsetools/include/yeccpre.hrl", 0).
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



-file("./edoc_parser.erl", 344).

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
 yeccpars2_6(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(19=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_19(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(20=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_20(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(21=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_21(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(22=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_22(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(23=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_7(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(24=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_24(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(25=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_48(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(52=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_48(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_65(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(85=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_85(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(86=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_48(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(87=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_87(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(88=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_88(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(89=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_65(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(101=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_101(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(102=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_102(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(103=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_103(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(104=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_104(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(105=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_105(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(106=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_4(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_114(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_60(S, Cat, Ss, Stack, T, Ts, Tzr);
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
 yeccpars2_128(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(129=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_129(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(130=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_130(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(131=S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2_131(S, Cat, Ss, Stack, T, Ts, Tzr);
yeccpars2(Other, _, _, _, _, _, _) ->
 erlang:error({yecc_bug,"1.2",{missing_state_in_action_table, Other}}).

yeccpars2_0(S, start_ref, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 2, Ss, Stack, T, Ts, Tzr);
yeccpars2_0(S, start_spec, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 3, Ss, Stack, T, Ts, Tzr);
yeccpars2_0(S, start_throws, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 4, Ss, Stack, T, Ts, Tzr);
yeccpars2_0(S, start_typedef, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 5, Ss, Stack, T, Ts, Tzr).

yeccpars2_1(_S, '$end', _Ss, Stack,  _T, _Ts, _Tzr) ->
 {ok, hd(Stack)}.

yeccpars2_2(S, '//', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 114, Ss, Stack, T, Ts, Tzr);
yeccpars2_2(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 115, Ss, Stack, T, Ts, Tzr).

yeccpars2_3(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_3(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 102, Ss, Stack, T, Ts, Tzr).

yeccpars2_4(S, '#', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, '//', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, '[', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, float, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, integer, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_4(S, '{', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr).

yeccpars2_5(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 7, Ss, Stack, T, Ts, Tzr).

yeccpars2_6(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_6_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_start(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_7(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 9, Ss, Stack, T, Ts, Tzr).

yeccpars2_8(S, '=', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 18, Ss, Stack, T, Ts, Tzr);
yeccpars2_8(S, where, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_8(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_8_(Stack),
 yeccpars2(17, Cat, [8 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_9(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 11, Ss, Stack, T, Ts, Tzr);
yeccpars2_9(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 12, Ss, Stack, T, Ts, Tzr).

yeccpars2_10(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 13, Ss, Stack, T, Ts, Tzr);
yeccpars2_10(S, ',', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 14, Ss, Stack, T, Ts, Tzr).

yeccpars2_11(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_11_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_var_list(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_12(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_12_(Stack),
 yeccpars2(yeccgoto_vars(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_13(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_13_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_var_list(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_14(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 15, Ss, Stack, T, Ts, Tzr).

yeccpars2_15(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_15_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_vars(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_16(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_16_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_typedef(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_17(S, ',', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_17(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_17(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_17(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_where_defs(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_18: see yeccpars2_4

yeccpars2_19(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_19_(Stack),
 yeccpars2(20, Cat, [19 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_20(S, ',', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 22, Ss, Stack, T, Ts, Tzr);
yeccpars2_20(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_20(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr);
yeccpars2_20(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_20_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_where_defs(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_21(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_21_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_defs(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_22(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 23, Ss, Stack, T, Ts, Tzr);
yeccpars2_22(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 24, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_23: see yeccpars2_7

yeccpars2_24(S, '=', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 25, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_25: see yeccpars2_4

yeccpars2_26(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_26_(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_27(S, '->', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 86, Ss, Stack, T, Ts, Tzr);
yeccpars2_27(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_27_(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_28(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_28_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_def(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_29(S, '.', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_29(S, ':', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 83, Ss, Stack, T, Ts, Tzr).

yeccpars2_30(S, '+', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_30(S, '|', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_30(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_30_(Stack),
 yeccpars2(yeccgoto_nutype(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_31(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_31_(Stack),
 yeccpars2(yeccgoto_ptypes(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_32(S, string, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 82, Ss, Stack, T, Ts, Tzr);
yeccpars2_32(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_utype(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_33(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 71, Ss, Stack, T, Ts, Tzr).

yeccpars2_34(S, '#', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 69, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, '//', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, '[', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, float, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, integer, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_34(S, '{', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr).

yeccpars2_35(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 59, Ss, Stack, T, Ts, Tzr).

yeccpars2_36(S, '#', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, '//', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, '[', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, ']', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 57, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, float, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, integer, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_36(S, '{', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr).

yeccpars2_37(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_37(_S, '$end', Ss, Stack, T, Ts, Tzr) ->
 NewStack = 'yeccpars2_37_$end'(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), '$end', Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, ')', Ss, Stack, T, Ts, Tzr) ->
 NewStack = 'yeccpars2_37_)'(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), ')', Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, '+', Ss, Stack, T, Ts, Tzr) ->
 NewStack = 'yeccpars2_37_+'(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), '+', Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, ',', Ss, Stack, T, Ts, Tzr) ->
 NewStack = 'yeccpars2_37_,'(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), ',', Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, ']', Ss, Stack, T, Ts, Tzr) ->
 NewStack = 'yeccpars2_37_]'(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), ']', Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, atom, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_37_atom(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), atom, Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, string, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_37_string(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), string, Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, var, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_37_var(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), var, Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, where, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_37_where(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), where, Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, '|', Ss, Stack, T, Ts, Tzr) ->
 NewStack = 'yeccpars2_37_|'(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), '|', Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, '}', Ss, Stack, T, Ts, Tzr) ->
 NewStack = 'yeccpars2_37_}'(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), '}', Ss, NewStack, T, Ts, Tzr);
yeccpars2_37(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_37_(Stack),
 yeccpars2(yeccgoto_qname(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_38(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_38_(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_39(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_39_(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_40(S, '::', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 48, Ss, Stack, T, Ts, Tzr);
yeccpars2_40(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_40_(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_41(S, '#', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, '//', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, '[', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, float, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, integer, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 40, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, '{', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr);
yeccpars2_41(S, '}', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 44, Ss, Stack, T, Ts, Tzr).

yeccpars2_42(S, ',', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr);
yeccpars2_42(S, '}', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 46, Ss, Stack, T, Ts, Tzr).

yeccpars2_43(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_43_(Stack),
 yeccpars2(yeccgoto_utypes(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_44(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_44_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_utype_tuple(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_45: see yeccpars2_4

yeccpars2_46(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_46_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_utype_tuple(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_47(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_47_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_utypes(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_48(S, '#', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 33, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, '//', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 35, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, '[', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 36, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 37, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, float, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 38, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, integer, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 39, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, var, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 50, Ss, Stack, T, Ts, Tzr);
yeccpars2_48(S, '{', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 41, Ss, Stack, T, Ts, Tzr).

yeccpars2_49(S, '+', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 51, Ss, Stack, T, Ts, Tzr);
yeccpars2_49(S, '|', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 52, Ss, Stack, T, Ts, Tzr);
yeccpars2_49(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_49_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_nutype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_50(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_50_(Stack),
 yeccpars2(yeccgoto_ptype(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

%% yeccpars2_51: see yeccpars2_48

%% yeccpars2_52: see yeccpars2_48

yeccpars2_53(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_53_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_ptypes(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_54(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_54_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_ptypes(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_55(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_55_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_56(S, ']', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 58, Ss, Stack, T, Ts, Tzr).

yeccpars2_57(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_57_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_58(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_58_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_59(S, '/', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 60, Ss, Stack, T, Ts, Tzr).

yeccpars2_60(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 62, Ss, Stack, T, Ts, Tzr).

yeccpars2_61(S, '.', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 63, Ss, Stack, T, Ts, Tzr);
yeccpars2_61(S, ':', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 64, Ss, Stack, T, Ts, Tzr).

yeccpars2_62(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_62_(Stack),
 yeccpars2(yeccgoto_qname(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_63(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr).

yeccpars2_64(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 65, Ss, Stack, T, Ts, Tzr).

yeccpars2_65(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 34, Ss, Stack, T, Ts, Tzr).

yeccpars2_66(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_66_(Stack),
 Nss = lists:nthtail(6, Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_67(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_67_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_qname(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_68(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 70, Ss, Stack, T, Ts, Tzr);
yeccpars2_68(S, ',', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 45, Ss, Stack, T, Ts, Tzr).

yeccpars2_69(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_69_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_utype_list(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_70(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_70_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_utype_list(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_71(S, '{', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 72, Ss, Stack, T, Ts, Tzr).

yeccpars2_72(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr);
yeccpars2_72(S, '}', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 76, Ss, Stack, T, Ts, Tzr).

yeccpars2_73(S, ',', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 79, Ss, Stack, T, Ts, Tzr);
yeccpars2_73(S, '}', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 80, Ss, Stack, T, Ts, Tzr).

yeccpars2_74(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_74_(Stack),
 yeccpars2(yeccgoto_fields(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_75(S, '=', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 77, Ss, Stack, T, Ts, Tzr).

yeccpars2_76(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_76_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_77: see yeccpars2_4

yeccpars2_78(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_78_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_field(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_79(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 75, Ss, Stack, T, Ts, Tzr).

yeccpars2_80(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_80_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_81(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_81_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_fields(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_82(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_82_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_utype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_83(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 84, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_84: see yeccpars2_65

yeccpars2_85(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_85_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_86: see yeccpars2_48

yeccpars2_87(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_87_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_ptype(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_88(S, '=', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 89, Ss, Stack, T, Ts, Tzr).

%% yeccpars2_89: see yeccpars2_4

yeccpars2_90(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_90_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_def(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_91(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_91_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_defs(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_92(S, where, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_92(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_92_(Stack),
 yeccpars2(17, Cat, [92 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_93(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_93_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_typedef(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_94(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_etype(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_95(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_95_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_start(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_96(S, where, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_96(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_96_(Stack),
 yeccpars2(17, Cat, [96 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_97(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_97_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_throws(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_98(S, '->', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 106, Ss, Stack, T, Ts, Tzr).

yeccpars2_99(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_99_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_start(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_100: see yeccpars2_65

yeccpars2_101(S, where, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_101(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_101_(Stack),
 yeccpars2(17, Cat, [101 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_102(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_102_(Stack),
 yeccpars2(yeccgoto_function_name(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_103(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_103_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_spec(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_104(S, where, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 19, Ss, Stack, T, Ts, Tzr);
yeccpars2_104(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_104_(Stack),
 yeccpars2(17, Cat, [104 | Ss], NewStack, T, Ts, Tzr).

yeccpars2_105(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_105_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_spec(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_106: see yeccpars2_4

yeccpars2_107(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_107_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_func_type(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_108(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_108_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_start(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_109(S, '.', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 124, Ss, Stack, T, Ts, Tzr);
yeccpars2_109(S, ':', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 125, Ss, Stack, T, Ts, Tzr);
yeccpars2_109(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_109_(Stack),
 yeccpars2(yeccgoto_mref(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_110(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_ref(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_111(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_ref(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_112(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_ref(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_113(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 yeccpars2(yeccgoto_ref(hd(Ss)), Cat, Ss, Stack, T, Ts, Tzr).

yeccpars2_114(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 120, Ss, Stack, T, Ts, Tzr).

yeccpars2_115(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 116, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(S, '/', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 117, Ss, Stack, T, Ts, Tzr);
yeccpars2_115(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_115_(Stack),
 yeccpars2(yeccgoto_qname(hd(Ss)), Cat, Ss, NewStack, T, Ts, Tzr).

yeccpars2_116(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 119, Ss, Stack, T, Ts, Tzr).

yeccpars2_117(S, integer, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 118, Ss, Stack, T, Ts, Tzr).

yeccpars2_118(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_118_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_lref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_119(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_119_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_lref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_120(S, '/', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 121, Ss, Stack, T, Ts, Tzr);
yeccpars2_120(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_120_(Stack),
 Nss = tl(Ss),
 yeccpars2(yeccgoto_aref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

%% yeccpars2_121: see yeccpars2_60

yeccpars2_122(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_122_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_aref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_123(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_123_(Stack),
 Nss = lists:nthtail(3, Ss),
 yeccpars2(yeccgoto_aref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_124(S, '*', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 131, Ss, Stack, T, Ts, Tzr);
yeccpars2_124(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 67, Ss, Stack, T, Ts, Tzr).

yeccpars2_125(S, atom, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 126, Ss, Stack, T, Ts, Tzr).

yeccpars2_126(S, '(', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 127, Ss, Stack, T, Ts, Tzr);
yeccpars2_126(S, '/', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 128, Ss, Stack, T, Ts, Tzr).

yeccpars2_127(S, ')', Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 130, Ss, Stack, T, Ts, Tzr).

yeccpars2_128(S, integer, Ss, Stack, T, Ts, Tzr) ->
 yeccpars1(S, 129, Ss, Stack, T, Ts, Tzr).

yeccpars2_129(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_129_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_mref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_130(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_130_(Stack),
 Nss = lists:nthtail(4, Ss),
 yeccpars2(yeccgoto_mref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccpars2_131(_S, Cat, Ss, Stack, T, Ts, Tzr) ->
 NewStack = yeccpars2_131_(Stack),
 Nss = lists:nthtail(2, Ss),
 yeccpars2(yeccgoto_pref(hd(Nss)), Cat, Nss, NewStack, T, Ts, Tzr).

yeccgoto_aref(2) -> 113.

yeccgoto_def(17) -> 21;
yeccgoto_def(20) -> 21;
yeccgoto_def(22) -> 91.

yeccgoto_defs(8) -> 17;
yeccgoto_defs(19) -> 20;
yeccgoto_defs(92) -> 17;
yeccgoto_defs(96) -> 17;
yeccgoto_defs(101) -> 17;
yeccgoto_defs(104) -> 17.

yeccgoto_etype(4) -> 96.

yeccgoto_field(72) -> 74;
yeccgoto_field(79) -> 81.

yeccgoto_fields(72) -> 73.

yeccgoto_func_type(3) -> 101;
yeccgoto_func_type(100) -> 104.

yeccgoto_function_name(3) -> 100.

yeccgoto_lref(2) -> 112.

yeccgoto_mref(2) -> 111;
yeccgoto_mref(121) -> 123.

yeccgoto_nutype(4) -> 32;
yeccgoto_nutype(18) -> 32;
yeccgoto_nutype(25) -> 32;
yeccgoto_nutype(34) -> 32;
yeccgoto_nutype(36) -> 32;
yeccgoto_nutype(41) -> 32;
yeccgoto_nutype(45) -> 32;
yeccgoto_nutype(77) -> 32;
yeccgoto_nutype(89) -> 32;
yeccgoto_nutype(106) -> 32.

yeccgoto_pref(2) -> 110;
yeccgoto_pref(121) -> 122.

yeccgoto_ptype(4) -> 31;
yeccgoto_ptype(18) -> 31;
yeccgoto_ptype(25) -> 31;
yeccgoto_ptype(34) -> 31;
yeccgoto_ptype(36) -> 31;
yeccgoto_ptype(41) -> 31;
yeccgoto_ptype(45) -> 31;
yeccgoto_ptype(48) -> 31;
yeccgoto_ptype(51) -> 54;
yeccgoto_ptype(52) -> 53;
yeccgoto_ptype(77) -> 31;
yeccgoto_ptype(86) -> 87;
yeccgoto_ptype(89) -> 31;
yeccgoto_ptype(106) -> 31.

yeccgoto_ptypes(4) -> 30;
yeccgoto_ptypes(18) -> 30;
yeccgoto_ptypes(25) -> 30;
yeccgoto_ptypes(34) -> 30;
yeccgoto_ptypes(36) -> 30;
yeccgoto_ptypes(41) -> 30;
yeccgoto_ptypes(45) -> 30;
yeccgoto_ptypes(48) -> 49;
yeccgoto_ptypes(77) -> 30;
yeccgoto_ptypes(89) -> 30;
yeccgoto_ptypes(106) -> 30.

yeccgoto_qname(2) -> 109;
yeccgoto_qname(4) -> 29;
yeccgoto_qname(18) -> 29;
yeccgoto_qname(25) -> 29;
yeccgoto_qname(34) -> 29;
yeccgoto_qname(36) -> 29;
yeccgoto_qname(41) -> 29;
yeccgoto_qname(45) -> 29;
yeccgoto_qname(48) -> 29;
yeccgoto_qname(51) -> 29;
yeccgoto_qname(52) -> 29;
yeccgoto_qname(60) -> 61;
yeccgoto_qname(77) -> 29;
yeccgoto_qname(86) -> 29;
yeccgoto_qname(89) -> 29;
yeccgoto_qname(106) -> 29;
yeccgoto_qname(121) -> 109.

yeccgoto_ref(2) -> 108.

yeccgoto_spec(3) -> 99.

yeccgoto_start(0) -> 1.

yeccgoto_throws(4) -> 95.

yeccgoto_typedef(5) -> 6.

yeccgoto_utype(4) -> 94;
yeccgoto_utype(18) -> 92;
yeccgoto_utype(25) -> 28;
yeccgoto_utype(34) -> 43;
yeccgoto_utype(36) -> 56;
yeccgoto_utype(41) -> 43;
yeccgoto_utype(45) -> 47;
yeccgoto_utype(77) -> 78;
yeccgoto_utype(89) -> 90;
yeccgoto_utype(106) -> 107.

yeccgoto_utype_list(3) -> 98;
yeccgoto_utype_list(4) -> 27;
yeccgoto_utype_list(18) -> 27;
yeccgoto_utype_list(25) -> 27;
yeccgoto_utype_list(34) -> 27;
yeccgoto_utype_list(36) -> 27;
yeccgoto_utype_list(37) -> 55;
yeccgoto_utype_list(41) -> 27;
yeccgoto_utype_list(45) -> 27;
yeccgoto_utype_list(48) -> 27;
yeccgoto_utype_list(51) -> 27;
yeccgoto_utype_list(52) -> 27;
yeccgoto_utype_list(65) -> 66;
yeccgoto_utype_list(77) -> 27;
yeccgoto_utype_list(84) -> 85;
yeccgoto_utype_list(86) -> 27;
yeccgoto_utype_list(89) -> 27;
yeccgoto_utype_list(100) -> 98;
yeccgoto_utype_list(106) -> 27.

yeccgoto_utype_tuple(4) -> 26;
yeccgoto_utype_tuple(18) -> 26;
yeccgoto_utype_tuple(25) -> 26;
yeccgoto_utype_tuple(34) -> 26;
yeccgoto_utype_tuple(36) -> 26;
yeccgoto_utype_tuple(41) -> 26;
yeccgoto_utype_tuple(45) -> 26;
yeccgoto_utype_tuple(48) -> 26;
yeccgoto_utype_tuple(51) -> 26;
yeccgoto_utype_tuple(52) -> 26;
yeccgoto_utype_tuple(77) -> 26;
yeccgoto_utype_tuple(86) -> 26;
yeccgoto_utype_tuple(89) -> 26;
yeccgoto_utype_tuple(106) -> 26.

yeccgoto_utypes(34) -> 68;
yeccgoto_utypes(41) -> 42.

yeccgoto_var_list(7) -> 8;
yeccgoto_var_list(23) -> 88.

yeccgoto_vars(9) -> 10.

yeccgoto_where_defs(8) -> 16;
yeccgoto_where_defs(92) -> 93;
yeccgoto_where_defs(96) -> 97;
yeccgoto_where_defs(101) -> 103;
yeccgoto_where_defs(104) -> 105.

-compile({inline,{yeccpars2_6_,1}}).
-file("edoc_parser.yrl", 44).
yeccpars2_6_([__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_8_,1}}).
-file("edoc_parser.yrl", 131).
yeccpars2_8_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_11_,1}}).
-file("edoc_parser.yrl", 143).
yeccpars2_11_([__2,__1 | Stack]) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_12_,1}}).
-file("edoc_parser.yrl", 147).
yeccpars2_12_([__1 | Stack]) ->
 [begin
   [ # t_var { name = tok_val ( __1 ) } ]
  end | Stack].

-compile({inline,{yeccpars2_13_,1}}).
-file("edoc_parser.yrl", 144).
yeccpars2_13_([__3,__2,__1 | Stack]) ->
 [begin
   lists : reverse ( __2 )
  end | Stack].

-compile({inline,{yeccpars2_15_,1}}).
-file("edoc_parser.yrl", 148).
yeccpars2_15_([__3,__2,__1 | Stack]) ->
 [begin
   [ # t_var { name = tok_val ( __3 ) } | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_16_,1}}).
-file("edoc_parser.yrl", 151).
yeccpars2_16_([__3,__2,__1 | Stack]) ->
 [begin
   # t_typedef { name = # t_name { name = tok_val ( __1 ) } ,
    args = __2 ,
    defs = lists : reverse ( __3 ) }
  end | Stack].

-compile({inline,{yeccpars2_19_,1}}).
-file("edoc_parser.yrl", 131).
yeccpars2_19_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_20_,1}}).
-file("edoc_parser.yrl", 56).
yeccpars2_20_([__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_21_,1}}).
-file("edoc_parser.yrl", 132).
yeccpars2_21_([__2,__1 | Stack]) ->
 [begin
   [ __2 | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_26_,1}}).
-file("edoc_parser.yrl", 91).
yeccpars2_26_([__1 | Stack]) ->
 [begin
   # t_tuple { types = __1 }
  end | Stack].

-compile({inline,{yeccpars2_27_,1}}).
-file("edoc_parser.yrl", 95).
yeccpars2_27_([__1 | Stack]) ->
 [begin
   if length ( element ( 1 , __1 ) ) == 1 ->
   
    hd ( element ( 1 , __1 ) ) ;
    length ( element ( 1 , __1 ) ) == 0 ->
    return_error ( element ( 2 , __1 ) , "syntax error before: ')'" ) ;
    true ->
    return_error ( element ( 2 , __1 ) , "syntax error before: ','" )
    end
  end | Stack].

-compile({inline,{yeccpars2_28_,1}}).
-file("edoc_parser.yrl", 136).
yeccpars2_28_([__3,__2,__1 | Stack]) ->
 [begin
   # t_def { name = # t_var { name = tok_val ( __1 ) } ,
    type = __3 }
  end | Stack].

-compile({inline,{yeccpars2_30_,1}}).
-file("edoc_parser.yrl", 80).
yeccpars2_30_([__1 | Stack]) ->
 [begin
   union ( __1 )
  end | Stack].

-compile({inline,{yeccpars2_31_,1}}).
-file("edoc_parser.yrl", 83).
yeccpars2_31_([__1 | Stack]) ->
 [begin
   [ __1 ]
  end | Stack].

-compile({inline,{'yeccpars2_37_$end',1}}).
-file("edoc_parser.yrl", 88).
'yeccpars2_37_$end'([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{'yeccpars2_37_)',1}}).
-file("edoc_parser.yrl", 88).
'yeccpars2_37_)'([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{'yeccpars2_37_+',1}}).
-file("edoc_parser.yrl", 88).
'yeccpars2_37_+'([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{'yeccpars2_37_,',1}}).
-file("edoc_parser.yrl", 88).
'yeccpars2_37_,'([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{'yeccpars2_37_]',1}}).
-file("edoc_parser.yrl", 88).
'yeccpars2_37_]'([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_37_atom,1}}).
-file("edoc_parser.yrl", 88).
yeccpars2_37_atom([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_37_string,1}}).
-file("edoc_parser.yrl", 88).
yeccpars2_37_string([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_37_var,1}}).
-file("edoc_parser.yrl", 88).
yeccpars2_37_var([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_37_where,1}}).
-file("edoc_parser.yrl", 88).
yeccpars2_37_where([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{'yeccpars2_37_|',1}}).
-file("edoc_parser.yrl", 88).
'yeccpars2_37_|'([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{'yeccpars2_37_}',1}}).
-file("edoc_parser.yrl", 88).
'yeccpars2_37_}'([__1 | Stack]) ->
 [begin
   # t_atom { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_37_,1}}).
-file("edoc_parser.yrl", 48).
yeccpars2_37_([__1 | Stack]) ->
 [begin
   [ tok_val ( __1 ) ]
  end | Stack].

-compile({inline,{yeccpars2_38_,1}}).
-file("edoc_parser.yrl", 90).
yeccpars2_38_([__1 | Stack]) ->
 [begin
   # t_float { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_39_,1}}).
-file("edoc_parser.yrl", 89).
yeccpars2_39_([__1 | Stack]) ->
 [begin
   # t_integer { val = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_40_,1}}).
-file("edoc_parser.yrl", 87).
yeccpars2_40_([__1 | Stack]) ->
 [begin
   # t_var { name = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_43_,1}}).
-file("edoc_parser.yrl", 73).
yeccpars2_43_([__1 | Stack]) ->
 [begin
   [ __1 ]
  end | Stack].

-compile({inline,{yeccpars2_44_,1}}).
-file("edoc_parser.yrl", 69).
yeccpars2_44_([__2,__1 | Stack]) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_46_,1}}).
-file("edoc_parser.yrl", 70).
yeccpars2_46_([__3,__2,__1 | Stack]) ->
 [begin
   lists : reverse ( __2 )
  end | Stack].

-compile({inline,{yeccpars2_47_,1}}).
-file("edoc_parser.yrl", 74).
yeccpars2_47_([__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_49_,1}}).
-file("edoc_parser.yrl", 79).
yeccpars2_49_([__3,__2,__1 | Stack]) ->
 [begin
   annotate ( union ( __3 ) , tok_val ( __1 ) )
  end | Stack].

-compile({inline,{yeccpars2_50_,1}}).
-file("edoc_parser.yrl", 87).
yeccpars2_50_([__1 | Stack]) ->
 [begin
   # t_var { name = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_53_,1}}).
-file("edoc_parser.yrl", 85).
yeccpars2_53_([__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_54_,1}}).
-file("edoc_parser.yrl", 84).
yeccpars2_54_([__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_55_,1}}).
-file("edoc_parser.yrl", 111).
yeccpars2_55_([__2,__1 | Stack]) ->
 [begin
   # t_type { name = # t_name { name = tok_val ( __1 ) } ,
    args = element ( 1 , __2 ) }
  end | Stack].

-compile({inline,{yeccpars2_57_,1}}).
-file("edoc_parser.yrl", 92).
yeccpars2_57_([__2,__1 | Stack]) ->
 [begin
   # t_nil { }
  end | Stack].

-compile({inline,{yeccpars2_58_,1}}).
-file("edoc_parser.yrl", 93).
yeccpars2_58_([__3,__2,__1 | Stack]) ->
 [begin
   # t_list { type = __2 }
  end | Stack].

-compile({inline,{yeccpars2_62_,1}}).
-file("edoc_parser.yrl", 48).
yeccpars2_62_([__1 | Stack]) ->
 [begin
   [ tok_val ( __1 ) ]
  end | Stack].

-compile({inline,{yeccpars2_66_,1}}).
-file("edoc_parser.yrl", 118).
yeccpars2_66_([__7,__6,__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # t_type { name = # t_name { app = tok_val ( __2 ) ,
    module = qname ( __4 ) ,
    name = tok_val ( __6 ) } ,
    args = element ( 1 , __7 ) }
  end | Stack].

-compile({inline,{yeccpars2_67_,1}}).
-file("edoc_parser.yrl", 49).
yeccpars2_67_([__3,__2,__1 | Stack]) ->
 [begin
   [ tok_val ( __3 ) | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_69_,1}}).
-file("edoc_parser.yrl", 66).
yeccpars2_69_([__2,__1 | Stack]) ->
 [begin
   { [ ] , tok_line ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_70_,1}}).
-file("edoc_parser.yrl", 67).
yeccpars2_70_([__3,__2,__1 | Stack]) ->
 [begin
   { lists : reverse ( __2 ) , tok_line ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_74_,1}}).
-file("edoc_parser.yrl", 124).
yeccpars2_74_([__1 | Stack]) ->
 [begin
   [ __1 ]
  end | Stack].

-compile({inline,{yeccpars2_76_,1}}).
-file("edoc_parser.yrl", 106).
yeccpars2_76_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # t_record { name = # t_atom { val = tok_val ( __2 ) } }
  end | Stack].

-compile({inline,{yeccpars2_78_,1}}).
-file("edoc_parser.yrl", 128).
yeccpars2_78_([__3,__2,__1 | Stack]) ->
 [begin
   # t_field { name = # t_atom { val = tok_val ( __1 ) } , type = __3 }
  end | Stack].

-compile({inline,{yeccpars2_80_,1}}).
-file("edoc_parser.yrl", 108).
yeccpars2_80_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # t_record { name = # t_atom { val = tok_val ( __2 ) } ,
    fields = lists : reverse ( __4 ) }
  end | Stack].

-compile({inline,{yeccpars2_81_,1}}).
-file("edoc_parser.yrl", 125).
yeccpars2_81_([__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_82_,1}}).
-file("edoc_parser.yrl", 76).
yeccpars2_82_([__2,__1 | Stack]) ->
 [begin
   annotate ( __1 , tok_val ( __2 ) )
  end | Stack].

-compile({inline,{yeccpars2_85_,1}}).
-file("edoc_parser.yrl", 114).
yeccpars2_85_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # t_type { name = # t_name { module = qname ( __1 ) ,
    name = tok_val ( __3 ) } ,
    args = element ( 1 , __4 ) }
  end | Stack].

-compile({inline,{yeccpars2_87_,1}}).
-file("edoc_parser.yrl", 104).
yeccpars2_87_([__3,__2,__1 | Stack]) ->
 [begin
   # t_fun { args = element ( 1 , __1 ) , range = __3 }
  end | Stack].

-compile({inline,{yeccpars2_90_,1}}).
-file("edoc_parser.yrl", 139).
yeccpars2_90_([__4,__3,__2,__1 | Stack]) ->
 [begin
   # t_def { name = # t_type { name = # t_name { name = tok_val ( __1 ) } ,
    args = __2 } ,
    type = __4 }
  end | Stack].

-compile({inline,{yeccpars2_91_,1}}).
-file("edoc_parser.yrl", 133).
yeccpars2_91_([__3,__2,__1 | Stack]) ->
 [begin
   [ __3 | __1 ]
  end | Stack].

-compile({inline,{yeccpars2_92_,1}}).
-file("edoc_parser.yrl", 131).
yeccpars2_92_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_93_,1}}).
-file("edoc_parser.yrl", 155).
yeccpars2_93_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   # t_typedef { name = # t_name { name = tok_val ( __1 ) } ,
    args = __2 ,
    type = __4 ,
    defs = lists : reverse ( __5 ) }
  end | Stack].

-compile({inline,{yeccpars2_95_,1}}).
-file("edoc_parser.yrl", 43).
yeccpars2_95_([__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_96_,1}}).
-file("edoc_parser.yrl", 131).
yeccpars2_96_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_97_,1}}).
-file("edoc_parser.yrl", 194).
yeccpars2_97_([__2,__1 | Stack]) ->
 [begin
   # t_throws { type = __1 ,
    defs = lists : reverse ( __2 ) }
  end | Stack].

-compile({inline,{yeccpars2_99_,1}}).
-file("edoc_parser.yrl", 42).
yeccpars2_99_([__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_101_,1}}).
-file("edoc_parser.yrl", 131).
yeccpars2_101_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_102_,1}}).
-file("edoc_parser.yrl", 59).
yeccpars2_102_([__1 | Stack]) ->
 [begin
   # t_name { name = tok_val ( __1 ) }
  end | Stack].

-compile({inline,{yeccpars2_103_,1}}).
-file("edoc_parser.yrl", 52).
yeccpars2_103_([__2,__1 | Stack]) ->
 [begin
   # t_spec { type = __1 , defs = lists : reverse ( __2 ) }
  end | Stack].

-compile({inline,{yeccpars2_104_,1}}).
-file("edoc_parser.yrl", 131).
yeccpars2_104_(Stack) ->
 [begin
   [ ]
  end | Stack].

-compile({inline,{yeccpars2_105_,1}}).
-file("edoc_parser.yrl", 54).
yeccpars2_105_([__3,__2,__1 | Stack]) ->
 [begin
   # t_spec { name = __1 , type = __2 , defs = lists : reverse ( __3 ) }
  end | Stack].

-compile({inline,{yeccpars2_107_,1}}).
-file("edoc_parser.yrl", 62).
yeccpars2_107_([__3,__2,__1 | Stack]) ->
 [begin
   # t_fun { args = element ( 1 , __1 ) , range = __3 }
  end | Stack].

-compile({inline,{yeccpars2_108_,1}}).
-file("edoc_parser.yrl", 45).
yeccpars2_108_([__2,__1 | Stack]) ->
 [begin
   __2
  end | Stack].

-compile({inline,{yeccpars2_109_,1}}).
-file("edoc_parser.yrl", 179).
yeccpars2_109_([__1 | Stack]) ->
 [begin
   edoc_refs : module ( qname ( __1 ) )
  end | Stack].

-compile({inline,{yeccpars2_115_,1}}).
-file("edoc_parser.yrl", 48).
yeccpars2_115_([__1 | Stack]) ->
 [begin
   [ tok_val ( __1 ) ]
  end | Stack].

-compile({inline,{yeccpars2_118_,1}}).
-file("edoc_parser.yrl", 185).
yeccpars2_118_([__3,__2,__1 | Stack]) ->
 [begin
   edoc_refs : function ( tok_val ( __1 ) , tok_val ( __3 ) )
  end | Stack].

-compile({inline,{yeccpars2_119_,1}}).
-file("edoc_parser.yrl", 187).
yeccpars2_119_([__3,__2,__1 | Stack]) ->
 [begin
   edoc_refs : type ( tok_val ( __1 ) )
  end | Stack].

-compile({inline,{yeccpars2_120_,1}}).
-file("edoc_parser.yrl", 168).
yeccpars2_120_([__2,__1 | Stack]) ->
 [begin
   edoc_refs : app ( tok_val ( __2 ) )
  end | Stack].

-compile({inline,{yeccpars2_122_,1}}).
-file("edoc_parser.yrl", 172).
yeccpars2_122_([__4,__3,__2,__1 | Stack]) ->
 [begin
   edoc_refs : app ( tok_val ( __2 ) , __4 )
  end | Stack].

-compile({inline,{yeccpars2_123_,1}}).
-file("edoc_parser.yrl", 170).
yeccpars2_123_([__4,__3,__2,__1 | Stack]) ->
 [begin
   edoc_refs : app ( tok_val ( __2 ) , __4 )
  end | Stack].

-compile({inline,{yeccpars2_129_,1}}).
-file("edoc_parser.yrl", 175).
yeccpars2_129_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   edoc_refs : function ( qname ( __1 ) , tok_val ( __3 ) , tok_val ( __5 ) )
  end | Stack].

-compile({inline,{yeccpars2_130_,1}}).
-file("edoc_parser.yrl", 177).
yeccpars2_130_([__5,__4,__3,__2,__1 | Stack]) ->
 [begin
   edoc_refs : type ( qname ( __1 ) , tok_val ( __3 ) )
  end | Stack].

-compile({inline,{yeccpars2_131_,1}}).
-file("edoc_parser.yrl", 182).
yeccpars2_131_([__3,__2,__1 | Stack]) ->
 [begin
   edoc_refs : package ( qname ( __1 ) )
  end | Stack].


-file("edoc_parser.yrl", 396).
