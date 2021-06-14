%%
%% NN system sensor instantiation
%%

-module(sensor).
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
        {PhenoPid, {SensorId, SensorName, VecLen, FanOutPids, CortexPid, ScapePid}} ->
        loop(SensorId, SensorName, VecLen, FanOutPids, PhenoPid, CortexPid, ScapePid)
    end.


%%
%% loop/7
%%
loop(SensorId, SensorName, VecLen, FanOutPids, PhenoPid, CortexPid, ScapePid) ->
    receive
        {CortexPid, sync} ->
            SensoryVec = sensor:SensorName(VecLen, ScapePid),
            [EgressPid ! {self(), forward, SensoryVec} || EgressPid <- FanOutPids],
            loop(SensorId, SensorName, VecLen, FanOutPids, PhenoPid, CortexPid, ScapePid);
        
        {PhenoPid, terminate} -> ok
    end.

%%
%% xor_get_input/2
%%
xor_get_signal(VecLen, ScapePid) ->
    ScapePid ! {self(), sense},
    receive
        {ScapePid, percept, SensoryVec} ->
            case length(SensoryVec) == VecLen of
                true -> SensoryVec;
                
                false ->
                    io:format("Error in sensor:xor_sim/2, VecLen: ~p SensoryVector ~p ~n", [VecLen, SensoryVec]),
                    lists:duplicate(VecLen, 0)
            end
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
