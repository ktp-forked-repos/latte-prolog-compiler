:- module(leftval, [leftval//3]).
:- use_module(utils).
:- use_module(environment).
:- use_module(expression).

leftval(var(Id), Type, var(Type, Id)) -->
    ask_state(get_var(Id), VarInfo) ->
        { Type = VarInfo.type }
    ; { throw(not_declared(Id)) }.


leftval( field(Exp, Field), FieldType, field(Class, NExp, Field) ) -->
    get_state(Env), types(Exp, ExpType, NExp),
    { ExpType = ref(class(Class)) or_else
        throw(non_class_field(Exp, ExpType, Field)) },
    
    { ClassInfo = Env.classes.get(Class) or_else
        throw(bad_class(Class)) },
    { member(Field - FieldType, ClassInfo.fields) or_else
        throw(bad_field(Class, Field)) }.


