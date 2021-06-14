%%
%% NN system phenotype instantiation
%%

-module(phen_constructor).
-compile(export_all).
-include("records.hrl").


map() ->
    map(ffnn).

map(FileName) ->
    {ok, Genotype} = file:consult(FileName),
    _Pid = spawn_link(fun() -> self() ! {self(), map(FileName, Genotype)} end),
%    receive
%        {Pid, R} -> R
%    end,
    io:format("The End ...").

map(FileName, Genotype) ->
    NeuronId2PidMap = ets:new(neuron_id2pid, [set, private]),
    [Cortex | CerebralUnits] = Genotype,
    
    spawn_cerebral_units(NeuronId2PidMap, cortex, [Cortex#cortex.id]),
    spawn_cerebral_units(NeuronId2PidMap, sensor, Cortex#cortex.sensor_ids),
    spawn_cerebral_units(NeuronId2PidMap, actuator, Cortex#cortex.actuator_ids),
    spawn_cerebral_units(NeuronId2PidMap, neuron, Cortex#cortex.neuron_ids),


    link_cerebral_units(CerebralUnits, NeuronId2PidMap),
    link_cortex(Cortex, NeuronId2PidMap),

    CortexPid = ets:lookup_element(NeuronId2PidMap, Cortex#cortex.id, 2),
    
    receive
        {CortexPid, backup, NeuronParams} ->
            UpdGenotype = update_genotype(NeuronId2PidMap, Genotype, NeuronParams),
            {ok, File} = file:open(FileName, write),
            lists:foreach(fun(Unit) -> io:format(File, "~p.~n", [Unit]) end, UpdGenotype),
            file:close(File),
            io:format("Genotype update to file ~p completed ...~n", [FileName])            
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
%% link_cerebral_units/2
%%  
link_cerebral_units([CUnit | CerebralUnits], NeuronId2PidMap) when is_record(CUnit, sensor) ->
    SensorPid = ets:lookup_element(NeuronId2PidMap, CUnit#sensor.id, 2),
    CortexPid = ets:lookup_element(NeuronId2PidMap, CUnit#sensor.cortex_id, 2),
    FanOutPids = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- CUnit#sensor.fanout_ids],
    SensorPid ! {self(), {CUnit#sensor.id, CortexPid, CUnit#sensor.name, CUnit#sensor.vec_len, FanOutPids}},
    link_cerebral_units(CerebralUnits, NeuronId2PidMap);
    
link_cerebral_units([CUnit | CerebralUnits], NeuronId2PidMap) when is_record(CUnit, actuator) ->
    ActuatorPid = ets:lookup_element(NeuronId2PidMap, CUnit#actuator.id, 2),
    CortexPid = ets:lookup_element(NeuronId2PidMap, CUnit#actuator.cortex_id, 2),
    FanInPids = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- CUnit#actuator.fanin_ids],
    ActuatorPid ! {self(), {CUnit#actuator.id, CortexPid, CUnit#actuator.name, FanInPids}},
    link_cerebral_units(CerebralUnits, NeuronId2PidMap);
    
link_cerebral_units([CUnit | CerebralUnits], NeuronId2PidMap) when is_record(CUnit, neuron) ->
    NeuronPid = ets:lookup_element(NeuronId2PidMap, CUnit#neuron.id, 2),
    CortexPid = ets:lookup_element(NeuronId2PidMap, CUnit#neuron.cortex_id, 2),
    IngressParams = convert_geno_ingress_params(NeuronId2PidMap, CUnit#neuron.in_params, []),
    EgressParams = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- CUnit#neuron.out_params],
    NeuronPid ! {self(), {CUnit#neuron.id, CortexPid, CUnit#neuron.act_func, IngressParams, EgressParams}},
    link_cerebral_units(CerebralUnits, NeuronId2PidMap);
    
link_cerebral_units([], _NeuronId2PidMap) ->
    ok.

    
%%
%% convert_geno_ingress_params/3
%%
convert_geno_ingress_params(_NeuronId2PidMap, [{bias, Bias}], Acc) ->
    lists:reverse([Bias | Acc]);
    
convert_geno_ingress_params(NeuronId2PidMap, [{Id, Weights} | IngressParams], Acc) ->
    convert_geno_ingress_params(NeuronId2PidMap, IngressParams, [{ets:lookup_element(NeuronId2PidMap, Id, 2), Weights} | Acc]).

%%
%% link_cortex/3
%%
link_cortex(Cortex, NeuronId2PidMap) ->
    CortexPid = ets:lookup_element(NeuronId2PidMap, Cortex#cortex.id, 2),
    SensorPids = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Cortex#cortex.sensor_ids],
    ActuatorPids = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Cortex#cortex.actuator_ids],
    NeuronPids = [ets:lookup_element(NeuronId2PidMap, Id, 2) || Id <- Cortex#cortex.neuron_ids],
    CortexPid ! {self(), {Cortex#cortex.id, SensorPids, ActuatorPids, NeuronPids}, 10}.


%%
%% update_genotype/3
%%
update_genotype(NeuronId2PidMap, Genotype, [{NeuronId, NeuronPhenoParams}| NeuronParams]) ->
    Neuron = lists:keyfind(NeuronId, 2, Genotype),
    NewInParams = convert_pheno_ingress_params(NeuronId2PidMap, NeuronPhenoParams, []),
    NewNeuron = Neuron#neuron{in_params = NewInParams},
    NewGenotype = lists:keyreplace(NeuronId, 2, Genotype, NewNeuron),
    io:format("Updating Genotype: ~p ~n Neuron: ~p~n Pheno: ~p ~n ", [NewGenotype, Neuron, NeuronPhenoParams]),
    update_genotype(NeuronId2PidMap, NewGenotype, NeuronParams);

update_genotype(_NeuronId2PidMap, Genotype, []) ->
    Genotype.


%%
%% convert_pheno_ingress_params/3
%%
convert_pheno_ingress_params(NeuronId2PidMap, [{NeuronPid, Weights} | NeuronPhenoParams], Acc) ->
    convert_pheno_ingress_params(NeuronId2PidMap, NeuronPhenoParams, [{ets:lookup_element(NeuronId2PidMap, NeuronPid,2), Weights} | Acc]);
    
convert_pheno_ingress_params(_NeuronId2PidMap, [Bias], Acc) ->
    lists:reverse([{bias, Bias} | Acc]).
