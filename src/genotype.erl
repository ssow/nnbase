%%
%% NN system genotype generator
%%

-module(genotype).
-compile(export_all).

-include("records.hrl").

construct(Morphology, HiddenLayerDensities) ->
    construct(ffnn, Morphology, HiddenLayerDensities).
    
construct(FileName, Morphology, HiddenLayerDensities) ->
    [S1, S2, S3] = [erlang:unique_integer([positive]) || _Value <- [1,2,3] ],
    rand:seed(exsplus, {S1, S2, S3}),
    %NewSensor = morphology:get_init_sensors(Morphology),
    %NewActuator = morphology:get_init_actuators(Morphology),
    NewSensor = #sensor{id={sensor, generate_id()}, name=xor_get_signal, scape={private, xor_sim}, vec_len=2},
    NewActuator = #actuator{id={actuator, generate_id()}, name=xor_send_out, scape={private, xor_sim}, vec_len=1},
    OutputVecLen = NewActuator#actuator.vec_len,

    LayerDensities = lists:append(HiddenLayerDensities, [OutputVecLen]),
    CortexId = cortex,
    NeuronList = create_layers(CortexId, NewSensor, NewActuator, LayerDensities),
    [InputLayer | _] = NeuronList,
    [OutputLayer | _] = lists:reverse(NeuronList),
%io:format("Here ----------- LD: ~p ~n In: ~p ~n Out: ~p ~n", [LayerDensities, NeuronList, OutputLayer]),
    InputNeuronIds = [Neuron#neuron.id || Neuron <- InputLayer],
    OutputNeuronIds = [Neuron#neuron.id || Neuron <- OutputLayer],


    NeuronIdList = [Neuron#neuron.id || Neuron <- lists:flatten(NeuronList)],
 
    Sensor = NewSensor#sensor{cortex_id = CortexId, fanout_ids = InputNeuronIds},
    Actuator = NewActuator#actuator{cortex_id = CortexId, fanin_ids = OutputNeuronIds},

    Cortex = create_cortex(CortexId, [NewSensor#sensor.id], [NewActuator#actuator.id], NeuronIdList),

    Genotype = lists:flatten([Cortex, Sensor, Actuator, NeuronList]),

    write_genotype_to_file(Genotype, FileName),
    io:format("Initial genotype built and saved ~n"),
    Genotype.
    

%%
%% create_neuron_layers/4
%%
create_layers(CortexId, Sensor, Actuator, LayerDensities) ->
    InParams = [{Sensor#sensor.id, Sensor#sensor.vec_len}],
    LayersCount = length(LayerDensities),
    [InLayerDensity | TailLayersDensities] = LayerDensities,
    InputNeuronIds = [{neuron, {1, Id}} || Id <- generate_id_list(InLayerDensity, [])],
    create_layers(CortexId, Actuator#actuator.id, 1, LayersCount, InParams, InputNeuronIds, TailLayersDensities, []).

%%
%% create_layers/8
%%
create_layers(CortexId, ActuatorId, LayerIndex, LayersCount, InParams, InputNeuronIds, [LayerDensity | LayerDensities], Acc) ->
    OutputNeuronList = [{neuron, {LayerIndex + 1, Id}} || Id <- generate_id_list(LayerDensity, [])],
    LayerNeurons = create_neuron_layer(CortexId, InParams, InputNeuronIds, OutputNeuronList, []),
    NextInParams = [{NeuronId, 1} || NeuronId <- InputNeuronIds],
%io:format("Here ----------- Index: ~p - LayerNeurons ~p ~n", [LayerIndex, LayerNeurons]),
    create_layers(CortexId, ActuatorId, LayerIndex + 1, LayersCount, NextInParams, OutputNeuronList, LayerDensities, [LayerNeurons | Acc]);

create_layers(CortexId, ActuatorId, LayersCount, LayersCount, InParams, InputNeuronIds, [], Acc) ->
    OutputIdList = [ActuatorId],
    LayerNeurons = create_neuron_layer(CortexId, InParams, InputNeuronIds, OutputIdList, []),
    Ret = lists:reverse([LayerNeurons | Acc]),
%io:format("Here ----------- Index: ~p - LayerNeurons ~p ~n", [LayersCount, LayerNeurons]),
    Ret.

%%
%% create_neuron_layer/5
%%
create_neuron_layer(CortexId, InParams, [NeuronId | NeuronIdList], OutputIdList, Acc) ->
    Neuron = create_neuron(NeuronId, InParams, OutputIdList, CortexId),
    create_neuron_layer(CortexId, InParams, NeuronIdList, OutputIdList, [Neuron | Acc]);
    
create_neuron_layer(_CortexId, _InParams, [], _OutputIdList, Acc) ->
    Acc.


%%
%% create_neuron/4
%%
create_neuron(NeuronId, InParams, OutputIdList, CortexId) ->
    NeuralInputs = create_neural_inputs(InParams, []),
    #neuron{id = NeuronId, cortex_id = CortexId, act_func = tanh, in_params = NeuralInputs, out_params = OutputIdList}.
    

%%
%% create_neural_inputs
%%
create_neural_inputs([{NodeId, VecLen} | InParams], Acc) ->
    Weights = create_neural_weights(VecLen, []),
    create_neural_inputs(InParams, [{NodeId, Weights} | Acc]);

create_neural_inputs([], Acc) ->
    lists:reverse([{bias, rand:uniform() - 0.5} | Acc]).

%%
%% create_neural_weights/2
%%
create_neural_weights(0, Acc) ->
    Acc;

create_neural_weights(VecLen, Acc) ->
    Weight = rand:uniform() - 0.5,
    create_neural_weights(VecLen - 1, [Weight | Acc]).


%%
%% create_cortex/4
%%
create_cortex(CortexId, SensorId, ActuatorId, NeuronIdList) ->
    #cortex{id = CortexId, sensor_ids = SensorId, actuator_ids = ActuatorId, neuron_ids = NeuronIdList}.

    
%%%
%%% Helpers
%%%

%%
%% print/1
%%
print(FileName) ->
    {ok, Genotype} = load_from_file(FileName),
    Cortex = read(Genotype, cortex),
    io:format("Cortex: ~p~n", [Cortex]),
    io:format("Sensors: ~p~n", [Cortex#cortex.sensor_ids]),
    io:format("Neurons: ~p~n", [Cortex#cortex.neuron_ids]),
    io:format("Actuators: ~p~n", [Cortex#cortex.actuator_ids]).

print_from_mem(Genotype) ->
    Cortex = read(Genotype, cortex),
    io:format("Cortex: ~p~n", [Cortex]),
    io:format("Sensors: ~p~n", [Cortex#cortex.sensor_ids]),
    io:format("Neurons: ~p~n", [Cortex#cortex.neuron_ids]),
    io:format("Actuators: ~p~n", [Cortex#cortex.actuator_ids]).

%%
%% write_genotype_to_file/2
%%
write_genotype_to_file(Genotype, FileName) ->
    TabStor = ets:new(FileName, [public, set, {keypos, 2}]),
    [write(TabStor, CerebralUnit) || CerebralUnit <- Genotype],
    write_to_file(TabStor, FileName).

%%
%% write_genotype_to_file/2
%%
write_genotype_to_mem(Genotype) ->
    TabStor = ets:new(geno_mem, [public, set, {keypos, 2}]),
    [write(TabStor, CerebralUnit) || CerebralUnit <- Genotype],
    TabStor.


%%
%% load_from_file/1
%%
%%
load_from_file(FileName) ->
    {ok, _TabStor} = ets:file2tab(FileName).

%%
%% write_to_file/2
%%
%%
write_to_file(TabStor, FileName) ->
    Ret = ets:tab2file(TabStor, FileName),
    case Ret of
        ok -> {true, "success"};
        
        {_, Reason} -> {false, Reason}
    end.

%%
%% read/2
%%
read(TabStor, Key) ->
    [Record] = ets:lookup(TabStor, Key),
    Record.

%%
%% write/2
%%

write(TabStor, Record) ->
    ets:insert(TabStor, Record).


%%
%% generate unique id
%%
generate_id() ->
    1/erlang:unique_integer([positive]).


%%
%% generate list of unique ids
%%
generate_id_list(0, Acc) ->
    Acc;
    
generate_id_list(Index, Acc) ->
    Id = generate_id(),
    generate_id_list(Index - 1, [Id | Acc]).
