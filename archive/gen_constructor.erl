%%
%% NN system genotype generator
%%

-module(gen_constructor).
-compile(export_all).

-include("records.hrl").

construct_genotype(SensorName, ActuatorName, HiddenLayerDensities) ->
    construct_genotype(ffnn, SensorName, ActuatorName, HiddenLayerDensities).
    
construct_genotype(FileName, SensorName, ActuatorName, HiddenLayerDensities) ->
    NewSensor = create_sensor(SensorName),
    NewActuator = create_actuator(ActuatorName),
    OutputVecLen = NewActuator#actuator.vec_len,
    LayerDensities = lists:append(HiddenLayerDensities, [OutputVecLen]),
    CortexId = {cortex, generate_id()},
    NeuronList = create_layers(CortexId, NewSensor, NewActuator, LayerDensities),
    [InputLayer | _] = NeuronList,
    [OutputLayer | _] = lists:reverse(NeuronList),
io:format("Here ----------- LD: ~p ~n In: ~p ~n Out: ~p ~n", [LayerDensities, NeuronList, OutputLayer]),
    InputNeuronIds = [Neuron#neuron.id || Neuron <- InputLayer],
    OutputNeuronIds = [Neuron#neuron.id || Neuron <- OutputLayer],


    NeuronIdList = [Neuron#neuron.id || Neuron <- lists:flatten(NeuronList)],
 
    Sensor = NewSensor#sensor{cortex_id = CortexId, fanout_ids = InputNeuronIds},
    Actuator = NewActuator#actuator{cortex_id = CortexId, fanin_ids = OutputNeuronIds},

    Cortex = create_cortex(CortexId, [NewSensor#sensor.id], [NewActuator#actuator.id], NeuronIdList),

    Genotype = lists:flatten([Cortex, Sensor, Actuator | NeuronList]),

    {ok, File} = file:open(FileName, write),
    lists:foreach(fun(Item) -> io:format(File, "~p.~n", [Item]) end, Genotype),
    file:close(File).
    
%%
%%
%%
create_sensor(SensorName) ->
    case SensorName of
        rng -> #sensor{id = {sensor, generate_id()}, name = SensorName, vec_len = 2};
        
        _ -> exit("System does not yet support sensor named: ~p.~n", [SensorName])
    end.

%%
%%
%%
create_actuator(ActuatorName) ->
    case ActuatorName of
        pts -> #actuator{id = {actuator, generate_id()}, name = ActuatorName, vec_len = 1};
        
        _ -> exit("System does not yet support actuator named: ~p.~n", [ActuatorName])
    end.

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
io:format("Here ----------- Index: ~p - LayerNeurons ~p ~n", [LayerIndex, LayerNeurons]),
    create_layers(CortexId, ActuatorId, LayerIndex + 1, LayersCount, NextInParams, OutputNeuronList, LayerDensities, [LayerNeurons | Acc]);

create_layers(CortexId, ActuatorId, LayersCount, LayersCount, InParams, InputNeuronIds, [], Acc) ->
    OutputIdList = [ActuatorId],
    LayerNeurons = create_neuron_layer(CortexId, InParams, InputNeuronIds, OutputIdList, []),
    Ret = lists:reverse([LayerNeurons | Acc]),
io:format("Here ----------- Index: ~p - LayerNeurons ~p ~n", [LayersCount, LayerNeurons]),
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
    
    
%%
%% Helpers
%%

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
