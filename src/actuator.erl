%%
%% NN system actuator instantiation
%%

-module(actuator).
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
        {PhenoPid, {ActuatorId, ActuatorName, FanInPids, CortexPid, ScapePid}} ->
            loop(ActuatorId, ActuatorName, {FanInPids, FanInPids}, PhenoPid, CortexPid, ScapePid, [])
    end.


%%
%% loop/7
%%       
loop(ActuatorId, ActuatorName, {[IngressPid | FanInPids], FullFanInPids}, PhenoPid, CortexPid, ScapePid, Acc) ->
    receive
        {IngressPid, forward, Out} ->
            loop(ActuatorId, ActuatorName, {FanInPids, FullFanInPids}, PhenoPid, CortexPid, ScapePid, lists:append(Out,Acc));
            
        {CortexPid, terminate} ->
            io:format("Actuator terminating ...~n"),
            ok
    end;

loop(ActuatorId, ActuatorName, {[], FullFanInPids}, PhenoPid, CortexPid, ScapePid, Acc) ->
    {Fitness, EndFlag} = actuator:ActuatorName(lists:reverse(Acc), ScapePid),
    CortexPid ! {self(), sync, Fitness, EndFlag},
    loop(ActuatorId, ActuatorName, {FullFanInPids, FullFanInPids}, PhenoPid, CortexPid, ScapePid, []).


%%
%%xor_send_out/2
%%
xor_send_out(Out, ScapePid) ->
    ScapePid ! {self(), action, Out},
    receive
        {ScapePid, Fitness, HaltFlag} ->
            {Fitness, HaltFlag}
    end.
%%
%% pts/1
%%
pts(Result) ->
    io:format("actuator:pts(Result): ~p ~n", [Result]).