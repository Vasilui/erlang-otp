%% stack_client example file.

-module('stack_client').
 
-export([run/0]).


run() ->
    case catch corba:string_to_object("corbaname:rir:/NameService#StackFactory") of
	{'EXCEPTION', _E} ->
	    io:format("The stack factory server is not registered~n",[]);
	SF ->
	    %% Create the stack
	    SS = 'StackModule_StackFactory':create_stack(SF),

	    'StackModule_Stack':push(SS, 4),
	    'StackModule_Stack':push(SS, 7),
	    'StackModule_Stack':push(SS, 1),
	    'StackModule_Stack':push(SS, 1),
	    Res = 'StackModule_Stack':pop(SS),
	    io:format("~w~n", [Res]),
	    Res1 = 'StackModule_Stack':pop(SS),
	    io:format("~w~n", [Res1]),
	    Res2 = 'StackModule_Stack':pop(SS),
	    io:format("~w~n", [Res2]),
	    Res3 = 'StackModule_Stack':pop(SS),
	    io:format("~w~n", [Res3]),

	    %% Remove the stack
	    'StackModule_StackFactory':destroy_stack(SF, SS)
	    
    end.


