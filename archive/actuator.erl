%%
%% NN system actuator instantiation
%%

-module(actuator).
-compile(export_all).
-include("records.hrl").


%%
%% create/2
%%
create(NNSPid, Node) ->
    spawn_link(Node, fun() -> NNSPid ! {self(), loop(NNSPid)} end).


%%
%% loop/1
%%    
loop(NNSPid) ->
    receive
        {NNSPid, {ActuatorId, CortexPid, ActuatorName, FanInPids}} ->
            loop(ActuatorId, CortexPid, ActuatorName, {FanInPids, FanInPids}, [])
    end.


%%
%% loop/5
%%       
loop(ActuatorId, CortexPid, ActuatorName, {[IngressPid | FanInPids], FullFanInPids}, Acc) ->
    receive
        {IngressPid, forward, Out} ->
            loop(ActuatorId, CortexPid, ActuatorName, {FanInPids, FullFanInPids}, lists:append(Out,Acc));
            
        {CortexPid, terminate} ->
io:format("Actuator terminating ...~n"),
            ok
    end;

loop(ActuatorId, CortexPid, ActuatorName, {[], FullFanInPids}, Acc) ->
    actuator:ActuatorName(lists:reverse(Acc)),
    CortexPid ! {self(), sync},
    loop(ActuatorId, CortexPid, ActuatorName, {FullFanInPids, FullFanInPids}, []).
 
%%
%% pts/1
%%
pts(Result) ->
    io:format("actuator:pts(Result): ~p ~n", [Result]).