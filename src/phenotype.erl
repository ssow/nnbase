%%
%% NN system phenotype instantiation
%%

-module(phenotype).
-compile(export_all).
-include("records.hrl").

map() -> map(ffnn).

map(FileName) ->
    {ok, Genotype} = genotype:load_from_file(FileName),
    spawn_link(fun() -> self() ! {self(), initialize(FileName, Genotype)} end).

    

%%
%% initialize/2
%%
initialize(FileName, Genotype) ->
    [S1, S2, S3] = [erlang:unique_integer([positive]) || _ <- [1,2,3] ],
    rand:seed(exsplus, {S1, S2, S3}),
    
    NeuronId2PidMap = ets:new(neuron_id2pid, [set, private]),
    Cortex = genotype:read(Genotype, cortex),
    ScapePidList = spawn_scapes(NeuronId2PidMap, Genotype, Cortex#cortex.sensor_ids, Cortex#cortex.actuator_ids),
    spawn_cerebral_units(NeuronId2PidMap, cortex, [Cortex#cortex.id]),
    spawn_cerebral_units(NeuronId2PidMap, sensor, Cortex#cortex.sensor_ids),
    spawn_cerebral_units(NeuronId2PidMap, actuator, Cortex#cortex.actuator_ids),
    spawn_cerebral_units(NeuronId2PidMap, neuron, Cortex#cortex.neuron_ids),
    link_cerebral_units(NeuronId2PidMap, sensor, Genotype, Cortex#cortex.sensor_ids),
    link_cerebral_units(NeuronId2PidMap, actuator, Genotype, Cortex#cortex.actuator_ids),
    link_cerebral_units(NeuronId2PidMap, neuron, Genotype, Cortex#cortex.neuron_ids),
    {SensorPidList, NeuronPidList, ActuatorPidList} = link_cortex(NeuronId2PidMap, Cortex),
    CortexPid = ets:lookup_element(NeuronId2PidMap, Cortex#cortex.id, 2),
    loop(FileName, Genotype, NeuronId2PidMap, CortexPid, SensorPidList, NeuronPidList, ActuatorPidList, ScapePidList, 0, 0, 0, 0, 1).


%%
%% loop/13
%%
loop(FileName, Genotype, NeuronId2PidMap, CortexPid, SensorPidList, NeuronPidList, ActuatorPidList, ScapePidList, HFitness, TotalEvals, TotalCycles, Duration, Tries) ->
    receive
        {CortexPid, eval_completed, Fitness, EvalCount, Time} ->
            NewTotalCycles = TotalCycles + EvalCount,
            NewDuration = Duration + Time,
            {CurHFitness, CurTries} =   case Fitness > HFitness of
                                            true ->
                                                [NeuronPid ! {self(), weight_backup} || NeuronPid <- NeuronPidList],
                                                {Fitness, 0};
                                                
                                            false ->
                                                AlteredNeuronIdList = erlang:get(altered),
                                                [NeuronId ! {self(), weight_restore} || NeuronId <- AlteredNeuronIdList],
                                                {HFitness, Tries + 1}
                                        end,
    
            case CurTries >= ?MAX_TRIES of
                true ->
                    backup_genotype(Genotype, FileName, NeuronId2PidMap, NeuronPidList),
                    terminate_phenotype(CortexPid, SensorPidList, NeuronPidList, ActuatorPidList, ScapePidList),
                    io:format("Phenotype: Cortex ~p finished training. Genotype backed up.~n Fitness : ~p~n", [CortexPid, CurHFitness]),
                    io:format("TotalEvals: ~p TotalCycles: ~p Duration: ~p~n", [TotalEvals, NewTotalCycles, NewDuration]),
        
                    case whereis(trainer) of
                        undefined -> ok;
                        
                        TrainerPid ->
                            TrainerPid ! {self(), CurHFitness, TotalEvals, NewTotalCycles, NewDuration}
                    end;
                    
                false ->
                     AlteredLimit = 1/math:sqrt(length(NeuronPidList)),
                     AlteredNeuronPidList = [NeuronPid || NeuronPid <- NeuronPidList, rand:uniform() < AlteredLimit],
                     erlang:put(altered, AlteredNeuronPidList),
                     [NeuronPid ! {self(), weight_altered} || NeuronPid <- AlteredNeuronPidList],
                     CortexPid ! {self(), relaunch},
                     loop(FileName, Genotype, NeuronId2PidMap, CortexPid, SensorPidList, NeuronPidList, ActuatorPidList, ScapePidList, CurHFitness, TotalEvals + 1, NewTotalCycles , NewDuration, CurTries)
            end;
            
        Msg -> io:format("Phenotype received unexpected message ~p~n", [Msg])
    end.
    
%%
%% spawn_cerebral_units/3
%%

spawn_cerebral_units(NeuronId2PidMap, CerebralUnitType, [Id | IdList]) ->
    Pid = CerebralUnitType:create(self(), node()),
    ets:insert(NeuronId2PidMap, {Id, Pid}),
    ets:insert(NeuronId2PidMap, {Pid, Id}),
    spawn_cerebral_units(NeuronId2PidMap, CerebralUnitType, IdList);

spawn_cerebral_units(_NeuronId2PidMap, _CerebralUnitType, []) ->
    true.


%%
%% spawn_scapes/4
%%
spawn_scapes(NeuronId2PidMap, Genotype, SensorIdList, ActuatorIdList) ->
    SensorScapes = [(genotype:read(Genotype, Id))#sensor.scape || Id <- SensorIdList],
    ActuatorScapes = [(genotype:read(Genotype, Id))#actuator.scape || Id <- ActuatorIdList],
    UniqueScapes = SensorScapes ++ (ActuatorScapes -- SensorScapes),
    ScapeInstanceList = [{scape:create(self(), node()), ScapeName} || {private, ScapeName} <- UniqueScapes],
    [ets:insert(NeuronId2PidMap, {ScapePid, ScapeName}) || {ScapePid, ScapeName} <- ScapeInstanceList],
    [ets:insert(NeuronId2PidMap, {ScapeName, ScapePid}) || {ScapePid, ScapeName} <- ScapeInstanceList],
    [ScapePid ! {self(), ScapeName} || {ScapePid, ScapeName} <- ScapeInstanceList],
    [ScapePid || {ScapePid, _ScapeName} <- ScapeInstanceList].
    

%%
%% link_cerebral_units/3
%%  
link_cerebral_units(NeuronId2PidMap, sensor, Genotype, [SensorId | SensorIdList]) ->
    Sensor = genotype:read(Genotype, SensorId),
    SensorPid = ets:lookup_element(NeuronId2PidMap, SensorId, 2),
    CortexPid = ets:lookup_element(NeuronId2PidMap, Sensor#sensor.cortex_id, 2),
    FanOutPids = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Sensor#sensor.fanout_ids],
    Scape = case Sensor#sensor.scape of
                {private, ScapeName} ->
                    ets:lookup_element(NeuronId2PidMap, ScapeName, 2)
            end,
    SensorPid ! {self(), {SensorId, Sensor#sensor.name, Sensor#sensor.vec_len, FanOutPids, CortexPid, Scape}},
    link_cerebral_units(NeuronId2PidMap, sensor, Genotype, SensorIdList);

link_cerebral_units(_NeuronId2PidMap, sensor, _Genotype, []) -> ok;
    
link_cerebral_units(NeuronId2PidMap, actuator, Genotype, [ActuatorId | ActuatorIdList]) ->
    Actuator = genotype:read(Genotype, ActuatorId),
    ActuatorPid = ets:lookup_element(NeuronId2PidMap, ActuatorId, 2),
    CortexPid = ets:lookup_element(NeuronId2PidMap, Actuator#actuator.cortex_id, 2),
    FanInPids = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Actuator#actuator.fanin_ids],
    Scape = case Actuator#actuator.scape of
                {private, ScapeName} ->
                    ets:lookup_element(NeuronId2PidMap, ScapeName, 2)
            end,
io:format("Phenotype link actuator ~p ~n", [ActuatorPid]),
    ActuatorPid ! {self(), {ActuatorId, Actuator#actuator.name, FanInPids, CortexPid, Scape}},
    link_cerebral_units(NeuronId2PidMap, actuator, Genotype, ActuatorIdList);

link_cerebral_units(_NeuronId2PidMap, actuator, _Genotype, []) -> ok;
    
link_cerebral_units(NeuronId2PidMap, neuron, Genotype, [NeuronId | NeuronIdList]) ->
    Neuron = genotype:read(Genotype, NeuronId),
    NeuronPid = ets:lookup_element(NeuronId2PidMap, NeuronId, 2),
    CortexPid = ets:lookup_element(NeuronId2PidMap, Neuron#neuron.cortex_id, 2),
    IngressParams = convert_geno_ingress_params(NeuronId2PidMap, Neuron#neuron.in_params, []),
    EgressParams = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Neuron#neuron.out_params],
    NeuronPid ! {self(), {NeuronId, Neuron#neuron.act_func, IngressParams, EgressParams, CortexPid}},
    link_cerebral_units(NeuronId2PidMap, neuron, Genotype, NeuronIdList);
    
link_cerebral_units(_NeuronId2PidMap, neuron, _Genotype, []) -> ok.


%%
%% link_cortex/2
%%
link_cortex(NeuronId2PidMap, Cortex) ->
    CortexPid = ets:lookup_element(NeuronId2PidMap, Cortex#cortex.id, 2),
    SensorPidList = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Cortex#cortex.sensor_ids],
    ActuatorPidList = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Cortex#cortex.actuator_ids],
    NeuronPidList = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Cortex#cortex.neuron_ids],
    CortexPid ! {self(), Cortex#cortex.id, SensorPidList, NeuronPidList, ActuatorPidList},
    {SensorPidList, NeuronPidList, ActuatorPidList}.


%%
%% backup_genotype/4
%%
backup_genotype(Genotype, FileName, NeuronId2PidMap, NeuronPidList) ->
    NeuronParamsList = request_neuron_params(NeuronPidList, []),
    update_genotype(NeuronId2PidMap, Genotype, NeuronParamsList),
genotype:print_from_mem(Genotype),
    genotype:write_to_file(Genotype, FileName),
    io:format("Genotype update to file ~p completed ...~n", [FileName]).


%%
%% request_neuron_params/2
%%
request_neuron_params([NeuronPid | NeuronPidList], Acc) ->
    NeuronPid ! {self(), params},
    receive
        {NeuronPid, NeuronId, IngressParams} ->
            request_neuron_params(NeuronPidList, [{NeuronId, IngressParams} | Acc])
    end;

request_neuron_params([], Acc) -> Acc.


%%
%% convert_geno_ingress_params/3
%%
convert_geno_ingress_params(_NeuronId2PidMap, [{bias, Bias}], Acc) ->
    lists:reverse([Bias | Acc]);
    
convert_geno_ingress_params(NeuronId2PidMap, [{Id, Weights} | IngressParams], Acc) ->
    convert_geno_ingress_params(NeuronId2PidMap, IngressParams, [{ets:lookup_element(NeuronId2PidMap, Id, 2), Weights} | Acc]).



%%
%% update_genotype/3
%%
update_genotype(NeuronId2PidMap, Genotype, [{NeuronId, NeuronPhenoParams}| NeuronParams]) ->
    Neuron = genotype:read(Genotype, NeuronId),
    NewInParams = convert_pheno_ingress_params(NeuronId2PidMap, NeuronPhenoParams, []),
    NewNeuron = Neuron#neuron{in_params = NewInParams},
    genotype:write(Genotype, NewNeuron),
    update_genotype(NeuronId2PidMap, Genotype, NeuronParams);

update_genotype(_NeuronId2PidMap, _Genotype, []) -> ok.


%%
%% convert_pheno_ingress_params/3
%%
convert_pheno_ingress_params(NeuronId2PidMap, [{NeuronPid, Weights} | NeuronPhenoParams], Acc) ->
    convert_pheno_ingress_params(NeuronId2PidMap, NeuronPhenoParams, [{ets:lookup_element(NeuronId2PidMap, NeuronPid,2), Weights} | Acc]);
    
convert_pheno_ingress_params(_NeuronId2PidMap, [Bias], Acc) ->
    lists:reverse([{bias, Bias} | Acc]).


%%
%% terminate_phenotype/5
%%
terminate_phenotype(CortexPid, SensorPidList, NeuronPidList, ActuatorPidList, ScapePidList) ->
    [Pid ! {self(), terminate} || Pid <- SensorPidList],
    [Pid ! {self(), terminate} || Pid <- NeuronPidList],
    [Pid ! {self(), terminate} || Pid <- ActuatorPidList],
    [Pid ! {self(), terminate} || Pid <- ScapePidList],
    CortexPid ! {self(), terminate}.