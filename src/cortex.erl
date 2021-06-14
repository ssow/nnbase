%%
%% NN system cortex instantiation
%%

-module(cortex).
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
    [S1, S2, S3] = [erlang:unique_integer([positive]) || _ <- [1,2,3] ],
    rand:seed(exsplus, {S1, S2, S3}),
    
    receive
        {PhenoPid, CortexId, SensorPidList, NeuronPidList, ActuatorPidList} ->
            erlang:put(start_time, erlang:monotonic_time()),
            [SensorPid ! {self(), sync} || SensorPid <- SensorPidList],
            loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {ActuatorPidList, ActuatorPidList}, 1, 0, 0, active)
    end.
    
    
%%
%% loop/9
%%
loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {[ActuatorPid | ActuatorPidList], FullActuatorPidList}, EvalCount, Fitness, TotalEvals, active) ->
    receive
        {ActuatorPid, sync, CurFitness, EndFlag} ->
            loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {ActuatorPidList, FullActuatorPidList}, EvalCount, Fitness + CurFitness, TotalEvals + EndFlag, active);
            
        terminate ->
            io:format("Cortex: ~p termination ...~n", [CortexId]),
            [Pid ! {self(), terminate} || Pid <- SensorPidList],
            [Pid ! {self(), terminate} || Pid <- FullActuatorPidList],
            [Pid ! {self(), terminate} || Pid <- NeuronPidList]
    end;

loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {[], FullActuatorPidList}, EvalCount, Fitness, TotalEvals, active) ->
    case TotalEvals > 0 of
        true ->
            TimeDiff = erlang:monotonic_time() - erlang:get(start_time),
            PhenoPid ! {self(), eval_completed, Fitness, EvalCount, TimeDiff},
            loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {FullActuatorPidList, FullActuatorPidList}, EvalCount, Fitness, TotalEvals, inactive);
            
        false ->
            [Pid ! {self(), sync} || Pid <- SensorPidList],
            loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {FullActuatorPidList, FullActuatorPidList}, EvalCount + 1, Fitness, TotalEvals, active)
    end;

loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {FullActuatorPidList, FullActuatorPidList}, _EvalCount, _Fitness, _TotalEvals, inactive) ->
    receive
        {PhenoPid, relaunch} ->
            erlang:put(start_time, erlang:monotonic_time()),
            [Pid ! {self(), sync} || Pid <- SensorPidList],
            loop(CortexId, PhenoPid, SensorPidList, NeuronPidList, {FullActuatorPidList, FullActuatorPidList}, 1, 0, 0, active);
            
        {PhenoPid, terminate} -> ok
    end.