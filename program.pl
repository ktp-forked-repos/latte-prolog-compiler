:- module(program, [correct_program/2]).
:- use_module(utils).
:- use_module(environment).
:- use_module(statement).

arg_types([], []).
arg_types([(_, Tp) | T], [Tp | TT]) :- arg_types(T, TT).

correct_program(Program, Env) :- 
    emptyenv(EEnv),
    foldr(declare_fun, EEnv, Program, Env),
    maplist(correct_function(Env), Program).

declare_fun(Env, topdef(Return, Fun, Args, _), NEnv) :-
    arg_types(Args, ArgTypes),
    NEnv = Env.add_fun(Fun, Return, ArgTypes).

%%%%%

declare_args(Env, [], Env).
declare_args(Env, [(Id,Type)|T], NEnv) :-
    can_shadow(Env, Id) -> (NEnv0 = Env.add_var(Id,Type), declare_args(NEnv0, T, NEnv) )
    ; fail("argument ~w declared multiple times", [Id]).

correct_function(Env0, topdef(Return, Fun, Args, Body)) :- 
    % writeln(checking: Fun : Args),
    declare_args(Env0.push(), Args, Env1),
    stmt_monad(Fun, Env1, Return, Mon),
    EEnv = Mon.correct(block(Body)),
    ((EEnv.returned = false, Return \= void) ->
        fail("control flow reaches function ~w end without return", [Fun])
    ; true).