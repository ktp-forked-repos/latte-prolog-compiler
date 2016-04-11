:- module(frontend, [check/4]).
:- use_module(utils).
:- use_module(environment).
:- use_module(expression).
:- use_module(statement).
:- use_module(program).

stripf(F, A) :- F =.. [_|Arg], A =.. [','|Arg].

fundef( topdef(RetT, Id, Args, _), (RetT, Id, ArgTs) ) :- maplist(snd, Args, ArgTs).
envFunInfo(_) :- false.

check(program, Tree, Env, NTree) :- correct_program(Tree, Env, NTree).
check(stmt, Stmt, Env, NStmt) :-
    emptyenv(Env),
    stmt_monad(..., Env, void, M),
    M.epush() ? correct(Stmt, NStmt).
check(exp, Exp, Env, NExp) :- emptyenv(Env), types(Env, Exp, Type, NExp), writeln(type: Type).
