:- module(parser, [parse/2, tokenize//1]).
:- use_module(library(dcg/basics)).



parse('-', Tree) :-
    prompt(_, ''),
    stream_property(user_input, reposition(true)),
    
    ( phrase_from_stream(tokenize(Tokens), user_input)
    ; throw(stdin_read_fail) ),

    phrase(program(Tree), Tokens), !.

parse(File, Tree) :-
    File \= '-',
    % format(user_error, "tokenizing...~n", []),
	phrase_from_file(tokenize(Tokens), File),
    % format(user_error, "parsing...~n", []),
	phrase(program(Tree), Tokens), !.

parse(_File, _Tree) :- throw(parsing_fail).

%%%%%%%%%%%%%
%%% LEXER %%%
%%%%%%%%%%%%%	

keywords([ if, else, while, return, true, false, int, string, boolean, void, class, new, null, for, extends]).
operators(["++", "--", "+", "-", "*", "/", "%", "(", ")", "{", "}", ";", "==", "!=",
            "=", "<=", "<", ">=", ">", "||", "&&", "!", ",", ".", "[", "]", ":"]).

id(Id) --> [Start], { code_type(Start, alpha) }, id_cont(Cont), { atom_codes(Id, [Start | Cont]) }.
id_cont([H|T]) --> [H], { code_type(H, csym) }, id_cont(T).
id_cont([]) --> "".

keyword(K) :- keywords(Keys), member(K, Keys).
operator(O) :- operators(Ops), member(O, Ops).

token(str(T)) --> "\""	, string_with_escapes(S), "\"", !, {string_chars(T, S)}.
token(T) --> {operator(Tok)}, Tok, !, {atom_codes(T, Tok)}.
token(T) --> integer(T), !.
token(T) --> id(Id), { keywords(KS), (member(Id, KS) -> T = Id ; T = id(Id))}.

tokenize(Tok) --> tokenize(Tok, 1), !.


string_with_escapes([]) --> [].
string_with_escapes([C | T]) -->
    "\\", (
        "n" -> { atom_codes('\n', [C]) }
      ; "t" -> { atom_codes('\t', [C]) }
      ; "e" -> { atom_codes('\e', [C]) }
      ; "a" -> { atom_codes('\a', [C]) }
      ; "\"" -> { atom_codes('\"', [C]) }
      ; "\\" -> { atom_codes('\\', [C]) }
    ), string_with_escapes(T).

string_with_escapes([C | T]) --> [C], string_with_escapes(T).

% comments
tokenize(_Tok, Line) --> "*/", { throw(unopened_comment(Line)) }.
tokenize(Tok, Line) -->
    "/*", !, (string(Skip), "*/" ; { throw(unclosed_comment(Line)) } ), !,
    {
        % count new lines
        include('='(10), Skip, NLS),
        length(NLS, NP),
        NewLine is Line + NP
    },
    tokenize(Tok, NewLine).
tokenize(Tok, Line) -->
    "//", !, string(_), "\n", !,
    { NewLine is Line+1 },
    tokenize(Tok, NewLine).
tokenize(Tok, Line) -->
    "#", !, string(_), "\n", !,
    { NewLine is Line+1 },
    tokenize(Tok, NewLine).

tokenize(X, Line) --> "\n", !, { NewLine is Line+1 }, tokenize(X, NewLine).
tokenize(X, Line) --> white, !, tokenize(X, Line).
tokenize([Tok | Tail], Line) --> token(Tok), !, tokenize(Tail, Line).
tokenize([], _Line) --> eos.
tokenize(_, Line) --> { throw(tokenize_fail(Line)) }.
%%%%%%%%%%%%%%
%%% PARSER %%%
%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%
%%% PROGRAM %%%
%%%%%%%%%%%%%%%

program([Def|Defs]) --> topdef(Def), !, program(Defs).
program([]) --> [].

topdef(Def) --> fun_def(Def) ; class_def(Def).

% function definition
fun_def(fun_def(Type, Id, Args, Block)) -->
    type(Type), [id(Id), '('], separated([,], farg, Args), [')'], block(Block).

% function argument
farg((Id, Type)) --> type(Type), !, [id(Id)].

class_def(class_def(Class, Sup, Fields, Methods)) -->
    [ class, id(Class) ], ([extends, id(Sup)], ! ; {Sup = '$none'} ),  ['{'],
        dcg_foldl(class_subdef, ([],[]), (Fields, Methods)),
    ['}'].

class_subdef((Fields, Methods), ([(Id - Type)|Fields], Methods)) -->
    type(Type), [ id(Id), ;].
class_subdef((Fields, Methods), (Fields, [(Id - Type - Args - Block) | Methods])) -->
    fun_def(fun_def(Type, Id, Args, Block)).
%%%%%%%%%%%%%%%%%%
%%% STATEMENTS %%%
%%%%%%%%%%%%%%%%%%

block( Stmts ) --> ['{'], !, separated([], stmt, Stmts), ['}'], !.

init(init(Id, Exp)) --> [id(Id), =], !, exp(Exp).
init(noinit(Id)) --> [id(Id)].

stmt( skip ) --> [;], !.

stmt( decl(Type, Ins) ) --> type(Type), separated([,], init, Ins), { Ins \= [] }, [;].

stmt( =(Left, Exp) ) --> leftval(Left), [=], exp(Exp), [;].

stmt(if(If, Then, Else)) --> [if, '('], exp(If), [')'], stmt(Then), [else], stmt(Else).
stmt(if(If, Then)) --> [if, '('], exp(If), [')'], stmt(Then).

stmt(while(While, Do)) --> [while, '('], exp(While), [')'], stmt(Do).
stmt(for(Type, Var, Arr, Do)) -->
    [for, '('], type(Type), [id(Var), :], exp(Arr), [')'], stmt(Do).

stmt(return(E)) --> [return], exp(E), [;], !.
stmt(return) --> [return], [;], !.

stmt(incr(var(Id))) --> [id(Id), '++', ;].
stmt(decr(var(Id))) --> [id(Id), '--', ;].

stmt(block(Stmts)) --> block(Stmts).

stmt(expstmt(Exp)) --> exp(Exp), [;].

% type
simple_types([void, int, boolean, string]).
stype(T) --> { simple_types(Tps), member(T, Tps) }, [T], !.
stype(ref(class(T))) --> [ id(T) ], !.

type(ref(array(T))) --> stype(T), ['[', ']'].
type(T) --> stype(T).

%
% LEFT VALUES %
%

leftval(var(Id)) --> [ id(Id) ].

leftval(method(Exp, Meth, Args)) --> sexp(Exp), ['.'], [id(Meth), '('], !, separated([,], exp, Args), [')'].
leftval(field(Exp, Field)) --> sexp(Exp), ['.'], !, [id(Field)], !.
leftval(arr_index(Arr, Ind)) --> sexp(Arr), ['['], aexp(Ind), [']'], !.

%%%%%%%%%%%%%%%%%%%
%%% expressions %%%
%%%%%%%%%%%%%%%%%%%

exp(E) --> orexp(E).


% simple
sexp(cast(Type, Exp)) --> ['('], type(Type), [')'], !, exp(Exp).
sexp(E) --> ['('], exp(E), [')'], !.
sexp(int(I)) --> [I], { integer(I) }, !.
sexp(neg(Exp)) --> [-], sexp(Exp), !.
sexp(str(S)) --> [str(S)], !.
sexp(app(Fun, Args)) --> [id(Fun), '('], !, separated([,], exp, Args), [')'].
sexp(var(V)) --> [id(V)], !.
sexp(true) --> [true], !.
sexp(false) --> [false], !.
sexp(null) --> [null], !.
sexp(new_arr(Type, Exp)) --> [ new ], type(Type), ['['], !, exp(Exp), [']'], !.
sexp(new(Type)) --> [ new, id(Type) ].

% logical
:- op(600, xfy, '&&').
:- op(600, xfy, '||').
orexp(E) --> andexp(E1), (['||'], !, orexp(E2), { E = '||'(E1,E2)} ; { E = E1 }).
andexp(E) --> lexp(E1), (['&&'], !, andexp(E2), { E = '&&'(E1,E2) } ; { E = E1 }).


% comp
:- op(600, xfy, '!=').
:- op(600, xfy, '<=').
:- op(600, xfy, '>=').

lexp(E) --> aexp(E).
lexp(not(E)) --> [!], !, lexp(E).


lexp(E) --> aexp(E1), [Op], { member(Op, [<,>,'<=','>=',==,'!=']) }, !, lexp(E2), { E =.. [Op, E1, E2] }.

% additive
aexp(E) --> mexp(E1), ([Op], { member(Op, [+,-]) }, !, aexp(E2), { E =.. [Op, E1, E2] } ; {E = E1}).

% multiplicative
mexp(E) --> (leftval(E1) ; sexp(E1)), ( [Op], { member(Op, [*,/,'%']) }, !, mexp(E2), { E =.. [Op, E1, E2] } ; {E = E1}).
