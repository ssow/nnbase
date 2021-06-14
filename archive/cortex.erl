%%
%% NN system cortex instantiation
%%

-module(cortex).
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
        {NNSPid, {CortexId, SensorPidList, ActuatorPidList, NeuronPidList}, RunCycles} ->
            [SensorPid ! {self(), sync} || SensorPid <- SensorPidList],
            loop(NNSPid, CortexId, SensorPidList, {ActuatorPidList, ActuatorPidList}, NeuronPidList, RunCycles)
    end.
    

%%
%% loop/6
%%
loop(NNSPid, CortexId, SensorPidList, {_ActuatorPidList, FullActuatorPidList}, NeuronPidList, 0) ->
    io:format("Cortex ~p backup and intermination ...~n", [CortexId]),
    NeuronParamsList = request_neuron_params(NeuronPidList, []),
    NNSPid ! {self(), backup, NeuronParamsList},
    [Pid ! {self(), terminate} || Pid <- SensorPidList],
    [Pid ! {self(), terminate} || Pid <- FullActuatorPidList],
    [Pid ! {self(), terminate} || Pid <- NeuronPidList];

    
loop(NNSPid, CortexId, SensorPidList, {[ActuatorPid | ActuatorPidList], FullActuatorPidList}, NeuronPidList, RunCycles) ->
    receive
        {ActuatorPid, sync} ->
            loop(NNSPid, CortexId, SensorPidList, {ActuatorPidList, FullActuatorPidList}, NeuronPidList, RunCycles);
        
        terminate ->
            io:format("Cortex: ~p terminating ...~n", [CortexId]),
            [Pid ! {self(), terminate} || Pid <- SensorPidList],
            [Pid ! {self(), terminate} || Pid <- FullActuatorPidList],
            [Pid ! {self(), terminate} || Pid <- NeuronPidList]
    end;

loop(NNSPid, CortexId, SensorPidList, {[], FullActuatorPidList}, NeuronPidList, RunCycles) ->
    [SensorPid ! {self(), sync} || SensorPid <- SensorPidList],
    loop(NNSPid, CortexId, SensorPidList, {FullActuatorPidList, FullActuatorPidList}, NeuronPidList, RunCycles - 1).
    

%%
%% request_neuron_params/2
%%
request_neuron_params([NeuronPid | NeuronPidList], Acc) ->
    NeuronPid ! {self(), params},
    receive
        {NeuronPid, NeuronId, WeightList} ->
            request_neuron_params(NeuronPidList, [{NeuronId, WeightList} | Acc])
    end;

request_neuron_params([], Acc) ->
    Acc.
