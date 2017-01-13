:- module('$utils', [
    op(700, xfy, :==),
    op(600, xfy, ?),
    op(500, yfx, ~),
    op(700, xfx, set_is), set_is/2,
    op(1100, xfy, or_else), or_else/2,
    fst/2, snd/2,
    fst/3, snd/3,
    foldr/4,
    zip/3,
    dcg_map//2, dcg_map//3,
    separated//3,
    dcg_foldl//3, dcg_foldl//4, dcg_foldl//5, '?'/2,
    get_state//1, put_state//1,
    do_state//1, op(600, fx, do_state),
    ask_state//2,
    local//2, local//1, op(600, fx, local),
    subtract_eq/3,
    select_dict/4,
    keys//0, del//1,
    if_possible/1, op(600, fx, if_possible),
    leave_gap//1, fill_gap//2
]).

% needed for memberchk_eq/2
:- use_module(library(dialect/hprolog)).

%%%%%%%%%%%%%%%%%%%%
% Minor predicates %
%%%%%%%%%%%%%%%%%%%%

fst((A,_), A).
fst(Op, X, A) :- X =.. [Op, A, _B].

snd((_, B), B).
snd(Op, X, B) :- X =.. [Op, _A, B].

if_possible Clause :- Clause, !.
if_possible _Clause.

A or_else B :- A -> true ; B.

%%%%%%%%%%%%%%%%%%%%%%
% DGC State Handling %
%%%%%%%%%%%%%%%%%%%%%%

get_state(S), [S] --> [S].
put_state(S), [S] --> [_] ; [].

do_state F, [NS] --> [S], { NS = S.F }.

ask_state(A, V) --> get_state(S), { V = S.A }.

:- module_transparent 'local'//1, 'local'//2.
local(Instr) --> get_state(S), Instr, put_state(S).
local(Instr, St) --> get_state(S), Instr, get_state(St), put_state(S).

%%%%%%%%%%%%%%%%%%%
% List predicates %
%%%%%%%%%%%%%%%%%%%

:- meta_predicate foldr(3, ?, ?, ?).
foldr(_, Zero, [], Zero ).
foldr(Fun, Zero, [H | Args], Ret) :-
    call(Fun, Zero, H, NZero),
    foldr(Fun, NZero, Args, Ret).

zip([], _, []).
zip(_, [], []).
zip([H1|T1], [H2|T2], [(H1,H2)|T]) :- zip(T1, T2, T).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DCG higher-level predicates %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% leaves a gap in the list generated by a dcg
leave_gap((In, Out), In, Out).

% fills a gap 
:- module_transparent fill_gap//2.
fill_gap((GapIn, GapOut), Fill, Flow, Flow) :-
    is_list(Fill) ->
        append(Fill, GapOut, GapIn)
    ; string(Fill) ->
        string_codes(Fill, FillChars),
        append(FillChars, GapOut, GapIn)
    ;
        phrase(Fill, FillResult),
        append(FillResult, GapOut, GapIn).

% separated(+Separator, +Closure, +List)
% calls Closure for each element in the List, calling Separator between them
:- module_transparent separated//3.
separated(Sep, Clause, [H | T]) -->
    call(Clause, H), separated_cont(Sep, Clause, T).
separated(_, _, []) --> [].

:- module_transparent separated_cont//3.
separated_cont(Sep, Clause, [H | T]) -->
    Sep, call(Clause, H), separated_cont(Sep, Clause, T).
separated_cont(_Sep, _Clause, []) --> [].

% dcg_map(+Closure, ?List)
% succeeds if Closure succeeds for each element in List
:- module_transparent dcg_map//2, dcg_map//3.
dcg_map(_, []) --> [].
dcg_map(Clause, [H|T]) -->
    call(Clause, H), dcg_map(Clause, T).

% dcg_map(+Closure, ?List1, ?List2)
% succeeds if Closure succeeds for each pair of coresponding elements in List1, List2
dcg_map(_, [], []) --> [].
dcg_map(Clause, [H|T], [HH|TT]) -->
    call(Clause, H, HH), dcg_map(Clause, T, TT).

% dcg_folfl(+Clause, +LeftValue, ?RightValue)
% DGC analogon of functional fold left
:- module_transparent dcg_foldl//3, dcg_foldl//4, dcg_foldl//5.
dcg_foldl(_, V, V) --> [].
dcg_foldl(Clause, V1, V2) -->
    call(Clause, V1, V3),
    dcg_foldl(Clause, V3, V2).

% dcg_folfl(+Clause, +LeftValue, +List, ?RightValue)
% DGC analogon of functional fold left, iterating over a list
dcg_foldl(_, V, [], V) --> [].
dcg_foldl(Clause, V1, [H|T], V2) -->
    call(Clause, V1, H, V3),
    dcg_foldl(Clause, V3, T, V2).

% dcg_folfl(+Clause, +LeftValue, +List, ?RightValue)
% DGC analogon of functional fold left, iterating over two lists
dcg_foldl(_, V, [], [], V) --> [].
dcg_foldl(Clause, V1, [H1|T1], [H2|T2], V2) -->
    call(Clause, V1, H1, H2, V3),
    dcg_foldl(Clause, V3, T1, T2, V2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Dict handling predicates %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% subtraction of sets over keys without unification of values
dict_minus(Dict, _{}, Dict) :- !.
dict_minus(Dict, MinDict, NewDict) :-
    select_dict(Key, MinDict, _, MinDict2), !,
    ( del_dict(Key, Dict, _, Dict2), ! ; Dict2 = Dict ),
    dict_minus(Dict2, MinDict2, NewDict).

% behaves like del_dict but allows for backtracking over keys
select_dict(Key, DictIn, Value, DictOut) :-
    Value = DictIn.get(Key), del_dict(Key, DictIn, Value, DictOut).

:- multifile user:term_expansion/2.
user:term_expansion(Head :== Exp, Head := V :- V is Exp).
user:term_expansion((Head :== Exp :- Body0), (Head := V :- Body0, V is Exp)).

?(M, F) :- _ = M.F.

:- module_transparent del//1.
D.del(Key) := D2 :-
    del_dict(Key, D, _Val, D2).

:- module_transparent keys//0.
D.keys() := Keys :-
    dict_pairs(D, _, Pairs),
    maplist(fst(-), Pairs, Keys).

% works like subtract/3 but uses memberchk_eq
subtract_eq([], _, []).
subtract_eq([Elem | Set], Sub, Result) :-
    memberchk_eq(Elem, Sub), !,
    subtract_eq(Set, Sub, Result).
subtract_eq([Elem | Set], Sub, [Elem | Result]) :-
    subtract_eq(Set, Sub, Result).

% set operation analogon for is/2. without one complex set operations get clunky
% union
(Val set_is (Exp1 + Exp2)) :-
    V1 set_is Exp1,
    V2 set_is Exp2,
    V1 >:< V2,
    Val = V1.put(V2).
% non-unifying subtraction
(Val set_is (Exp1 - Exp2)) :-
    V1 set_is Exp1,
    V2 set_is Exp2,
    dict_minus(V1, V2, Val).
% unifying subtraction
(Val set_is (Exp1 ~ Exp2)) :-
    V1 set_is Exp1,
    V2 set_is Exp2,
    V1 >:< V2,
    dict_minus(V1, V2, Val).
Val set_is Val :- is_dict(Val).
