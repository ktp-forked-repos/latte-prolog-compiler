:- module(llvm, [llvm_compile/2]).

:- use_module(library(dcg/basics)).
:- use_module(library(apply)).

% top level llvm translation
llvm_compile(In, Out) :-
    llvm_inst(In),
    phrase(llvm_compile(In), Out).

%%% instantiation %%%

llvm_inst(Prog) :- llvm_inst(0, Prog).

llvm_inst(_, []).
llvm_inst(C, [string(Lab, _, _) | T]) :-
    atomic_concat('@str', C, Lab), C1 is C+1,
    llvm_inst(C1, T).
llvm_inst(C, [H|T]) :- llvm_inst_fun(H), llvm_inst(C, T).

llvm_inst_fun(function(_, _, Args, Body)) :-
    foldl(llvm_inst_arg, Args, 1, _),
    foldl(llvm_inst_instr, Body, (1,1), _).
llvm_inst_fun(_).

llvm_inst_arg((V,_), C, C1) :- atomic_concat('%arg', C, V), C1 is C + 1.    

llvm_inst_instr(V = _, (C,LC), (C1,LC)) :-
    !, atomic_concat('%', C, V), C1 is C + 1.
llvm_inst_instr(block(Bl), (C,LC), (C,LC1)) :-
    !, atomic_concat('label', LC, Bl),
    LC1 is LC + 1.
llvm_inst_instr(ret(_,_), (X,C), (X1,C)) :- !, X1 is X+1.
llvm_inst_instr(ret, (X,C), (X1,C)) :- !, X1 is X+1.
llvm_inst_instr(_, C, C).

%%%%%%%%%%%%%%%%%%%
%%% translation %%%
%%%%%%%%%%%%%%%%%%%
llvm_compile([]) --> [].
llvm_compile([H|T]) --> llvm_fun(H), llvm_compile(T).


% types
llvm_type(int) --> "i32".
llvm_type(string) --> "i8*".
llvm_type(boolean) --> "i1".
llvm_type(void) --> "void".

llvm_types([]) --> [].
llvm_types([T]) --> llvm_type(T).
llvm_types([H|T]) --> llvm_type(H), ", ", llvm_types(T).

% arguments
llvm_args([]) --> [].
llvm_args([(Var,Type) | T]) -->
    llvm_type(Type), " ", atom(Var),
    ( { T = [] } -> [] ; ", ", llvm_args(T)).

% operator info
llvm_op(+, "add", "i32", "i32").
llvm_op(-, "sub", "i32", "i32").
llvm_op(*, "mul", "i32", "i32").
llvm_op(/, "sdiv", "i32", "i32").
llvm_op('%', "srem", "i32", "i32").

llvm_op(>, "icmp sgt", "i32", "i1").
llvm_op(<, "icmp slt", "i32", "i1").
llvm_op(>, "icmp sgt", "i32", "i1").
llvm_op('<=', "icmp sle", "i32", "i1").


% functions
llvm_fun(function(Type, Fun, Args, Body)) -->
    "define ", llvm_type(Type), " @", atom(Fun), "(", llvm_args(Args), "){",
    llvm_stmts(Body),
    "\n}\n". 
llvm_fun(decl(Fun, Type, Args)) -->
    "declare ", llvm_type(Type), " @", atom(Fun), "(", llvm_types(Args), ")\n".
llvm_fun(string(Lab, Str, Len)) -->
    atom(Lab), " = private constant [", atom(Len), " x i8] c\"", atom(Str), "\", align 1\n".
% @.str = private constant [5 x i8] c"Hello", align 1

indent(block(_)) --> "".
indent(_) --> "    ".
llvm_stmts([]) --> [].
llvm_stmts([H|T]) --> "\n", indent(H), /* atom(H), " ----> ", */ llvm_stmt(H), !, llvm_stmts(T).


% statements
llvm_phi_args([]) --> [].
llvm_phi_args([(V,Lab) | T]) -->
    "[", atom(V), ", %", atom(Lab), "]", ({ T = []} -> [] ; ", ", llvm_phi_args(T)).


%llvm_stmt(S) --> ". ", atom(S).

llvm_stmt(block(B)) --> atom(B), ":".

llvm_stmt(  V3 = phi(Type, Args) ) -->
    atom(V3), " = phi ", llvm_type(Type), " ", llvm_phi_args(Args).

llvm_stmt(V = call(Type, Fun, Args)) -->
    atom(V), " = call ", llvm_type(Type), " @", atom(Fun), "(", llvm_args(Args), ")".
llvm_stmt(call(Fun, Args)) -->
    "call ", llvm_type(void), " @", atom(Fun), "(", llvm_args(Args), ")".

llvm_stmt(V = strcast(Len, Lab)) -->
    atom(V), " = bitcast [", atom(Len), " x i8]* ", atom(Lab), " to i8*".


llvm_stmt(V = '=='(Type, V1, V2)) -->
    atom(V), " = icmp eq ", llvm_type(Type), " ", atom(V1), ", ", atom(V2).
llvm_stmt(V = '!='(Type, V1, V2)) -->
    atom(V), " = icmp ne ", llvm_type(Type), " ", atom(V1), ", ", atom(V2).

llvm_stmt(V = OpE) -->
    { OpE =.. [Op, V1, V2], llvm_op(Op, LLOp, InT, _) },
    atom(V), " = ", LLOp, " ", InT, " ", atom(V1), ", ", atom(V2).

llvm_stmt(if(Cond, Lab1, Lab2)) -->
    "br i1 ", atom(Cond), ", label %", atom(Lab1), ", label %", atom(Lab2).

llvm_stmt(jump(Lab)) --> "br label %", atom(Lab).

llvm_stmt(ret) --> "ret void".
llvm_stmt(ret(Type, V)) --> "ret ", llvm_type(Type), " ", atom(V).

llvm_stmt(unreachable) --> "unreachable".

llvm_stmt(S) --> ">>>>> ", atom(S).
% llvm_stmt(_) --> [].







