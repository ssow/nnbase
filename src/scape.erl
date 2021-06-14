%%
%% NN system scape instantiation
%%

-module(scape).
-compile(export_all).
-include("records.hrl").


%%
%% create/2
%%
create(PhenoPid, Node) ->
    spawn_link(Node, fun() -> PhenoPid ! {self(), initialize(PhenoPid)} end).



%%
%% initialize/1
%%
initialize(PhenoPid) ->
    receive
        {PhenoPid, ScapeName} ->
            scape:ScapeName(PhenoPid)
    end.
    
%%
%% xor_sim/1
%%
xor_sim(PhenoPid) ->
    XOR = [{[-1, -1], [-1]}, {[1, -1], [1]}, {[-1, 1], [1]}, {[1, 1], [-1]}],
    xor_sim(PhenoPid, {XOR, XOR}, 0).
    
%%
%% xor_sim/3
%%
xor_sim(PhenoPid, {[{Input, CorrectOuput} | XOR], FullXOR}, Error) ->
    receive
        {From, sense} ->
            From ! {self(), percept, Input},
            xor_sim(PhenoPid, {[{Input, CorrectOuput} | XOR], FullXOR}, Error);
            
        {From, action, Output} ->
            OpsError = compare_lists(Output, CorrectOuput, 0),
            case XOR of
                [] ->
                    Mean2Error = math:sqrt(Error + OpsError),
                    Fitness = 1/(Mean2Error + 0.00001),
                    From ! {self(), Fitness, 1},
                    xor_sim(PhenoPid, {FullXOR, FullXOR}, 0);
                    
                _ ->
                    From ! {self(), 0, 0},
                    xor_sim(PhenoPid, {XOR, FullXOR}, Error + OpsError)
            end;
        
        {PhenoPid, terminate} -> ok
    end.


%%
%% compare_list/3
%%
compare_lists([X | List1], [Y | List2], Error) ->
    compare_lists(List1, List2, Error + math:pow(X-Y, 2));
    
compare_lists([], [], Error) -> math:sqrt(Error).
