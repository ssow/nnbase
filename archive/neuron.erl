%%
%% NN system neuron instantiation
%%

-module(neuron).
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
        {NNSPid, {NeuronId, CortexPid, ActFunc, IngressParams, EgressParams}} ->
            loop(NeuronId, CortexPid, ActFunc, {IngressParams, IngressParams}, EgressParams, 0)
    end.

loop(NeuronId, CortexPid, ActFunc, {[{InNeuronPid, WeightVec} | IngressParams], FullIngressParams}, EgressParams, Acc) ->
    receive
        {InNeuronPid, forward, SignalVec} ->
            Result = compute_dot_product(SignalVec, WeightVec, 0),
            loop(NeuronId, CortexPid, ActFunc, {IngressParams, FullIngressParams}, EgressParams, Result + Acc);
            
        {CortexPid, params} ->
            CortexPid ! {self(), NeuronId, FullIngressParams},
            loop(NeuronId, CortexPid, ActFunc, {[{InNeuronPid, WeightVec} | IngressParams], FullIngressParams}, EgressParams, Acc);
        
        {CortexPid, terminate} ->
io:format("Neuron terminating ...~n"),
            ok
    end;

loop(NeuronId, CortexPid, ActFunc, {[Bias], FullIngressParams}, EgressParams, Acc) ->
    Out = neuron:ActFunc(Acc + Bias),
    [EgressUnitPid ! {self(), forward, [Out]} || EgressUnitPid <- EgressParams],
    loop(NeuronId, CortexPid, ActFunc, {FullIngressParams, FullIngressParams}, EgressParams, 0);

loop(NeuronId, CortexPid, ActFunc, {[], FullIngressParams}, EgressParams, Acc) ->
    Out = neuron:ActFunc(Acc),
    [EgressUnitPid ! {self(), forward, [Out]} || EgressUnitPid <- EgressParams],
    loop(NeuronId, CortexPid, ActFunc, {FullIngressParams, FullIngressParams}, EgressParams, 0).


%%
%% Helpers functions
%%

%%
%% compute_dot_product/3
%%  
compute_dot_product([Signal | SignalVec], [ Weight | WeightVec], Acc) ->
    compute_dot_product(SignalVec, WeightVec, Signal * Weight + Acc);

compute_dot_product([], [], Acc) ->
    Acc.
    
%%
%% tanh/1
%%
tanh(Val) when is_number(Val) ->
    math:tanh(Val).
