%%
%% NN system sensor instantiation
%%

-module(sensor).
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
        {NNSPid, {SensorId, CortexPid, SensorName, VecLen, FanOutPids}} ->
        loop(SensorId, CortexPid, SensorName, VecLen, FanOutPids)
    end.


%%
%% loop/5
%%
loop(SensorId, CortexPid, SensorName, VecLen, FanOutPids) ->
    receive
        {CortexPid, sync} ->
            SensoryVec = sensor:SensorName(VecLen),
            [EgressPid ! {self(), forward, SensoryVec} || EgressPid <- FanOutPids],
            loop(SensorId, CortexPid, SensorName, VecLen, FanOutPids);
        
        {CortexPid, terminate} ->
io:format("Sensor: terminating ...~n"),
            ok
    end.


%%
%% Helper functions
%%


%%
%% rng/1
%%
rng(VecLen) ->
    rng(VecLen, []).


%%
%% rng/2
%%  
rng(0, Acc) ->
    Acc;
    
rng(VecLen, Acc) ->
    rng(VecLen - 1, [rand:uniform() | Acc]).
