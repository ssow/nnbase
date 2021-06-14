%%
%% NN system neuron instantiation
%%

-module(neuron).
-compile(export_all).
-include("records.hrl").

-define(SAT_LIMIT, math:pi() * 2).
-define(DELTA_MULT, math:pi() * 2).


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
        {PhenoPid, {NeuronId, ActFunc, IngressParams, EgressParams, CortexPid}} ->
            loop(NeuronId, PhenoPid, CortexPid, ActFunc, {IngressParams, IngressParams}, EgressParams, 0)
    end.


loop(NeuronId, PhenoPid, CortexPid, ActFunc, {[{InNeuronPid, WeightVec} | IngressParams], FullIngressParams}, EgressParams, Acc) ->
    receive
        {InNeuronPid, forward, SignalVec} ->
            Result = compute_dot_product(SignalVec, WeightVec, 0),
            loop(NeuronId, PhenoPid, CortexPid, ActFunc, {IngressParams, FullIngressParams}, EgressParams, Result + Acc);
            
        {PhenoPid, weight_backup} ->
            erlang:put(weights, FullIngressParams),
            loop(NeuronId, PhenoPid, CortexPid, ActFunc, {[{InNeuronPid, WeightVec} | IngressParams], FullIngressParams}, EgressParams, Acc);

        {PhenoPid, weight_restore} ->
            PrevIngressParams = erlang:get(weights),
            loop(NeuronId, PhenoPid, CortexPid, ActFunc, {PrevIngressParams, PrevIngressParams}, EgressParams, Acc);
            
        {PhenoPid, weight_altered} ->
            AltIngressParams = alter_ingress_params(FullIngressParams),
            loop(NeuronId, PhenoPid, CortexPid, ActFunc, {AltIngressParams, AltIngressParams}, EgressParams, Acc);
            
        {PhenoPid, params} ->
            PhenoPid ! {self(), NeuronId, FullIngressParams},
            loop(NeuronId, PhenoPid, CortexPid, ActFunc, {[{InNeuronPid, WeightVec} | IngressParams], FullIngressParams}, EgressParams, Acc);
        
        {PhenoPid, terminate} -> ok
    end;

loop(NeuronId, PhenoPid, CortexPid, ActFunc, {[Bias], FullIngressParams}, EgressParams, Acc) ->
    Out = neuron:ActFunc(Acc + Bias),
    [EgressUnitPid ! {self(), forward, [Out]} || EgressUnitPid <- EgressParams],
    loop(NeuronId, PhenoPid, CortexPid, ActFunc, {FullIngressParams, FullIngressParams}, EgressParams, 0);

loop(NeuronId, PhenoPid, CortexPid, ActFunc, {[], FullIngressParams}, EgressParams, Acc) ->
    Out = neuron:ActFunc(Acc),
    [EgressUnitPid ! {self(), forward, [Out]} || EgressUnitPid <- EgressParams],
    loop(NeuronId, PhenoPid, CortexPid, ActFunc, {FullIngressParams, FullIngressParams}, EgressParams, 0).


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

%%
%% alter_ingress_params/1
%%
alter_ingress_params(IngressParams) ->
    Mass = lists:sum([length(WeightVec) || {_InNeuronPid, WeightVec} <- IngressParams]),
    AlterLimit = 1/math:sqrt(Mass),
    alter_ingress_params(IngressParams, AlterLimit, []).

%%
%% alter_ingress_params/3
%%
alter_ingress_params([{InNeuronPid, WeightVec} | IngressParams], AlterLimit, Acc) ->
    NewWeightVec = alter_weight(WeightVec, AlterLimit, []),
    alter_ingress_params(IngressParams, AlterLimit, [{InNeuronPid, NewWeightVec} | Acc]);
    
alter_ingress_params([Bias], AlterLimit, Acc) ->
    NewBias =   case rand:uniform() < AlterLimit of
                    true -> saturation((rand:uniform() - 0.5) * ?DELTA_MULT + Bias, - ?SAT_LIMIT, ?SAT_LIMIT);
                    
                    false -> Bias
                end,
    lists:reverse([NewBias | Acc]);
    
alter_ingress_params(_IngressParams, _AlterLimit, Acc) ->
    lists:reverse(Acc).


%%
%% alter_weight/3
%%
alter_weight([Weight | WeightVec], AlterLimit, Acc) ->
    NewWeight = case rand:uniform() < AlterLimit of
                    true -> saturation((rand:uniform() - 0.5) * ?DELTA_MULT + Weight, - ?SAT_LIMIT, ?SAT_LIMIT);
                    
                    false -> Weight
                end,
    alter_weight(WeightVec, AlterLimit, [NewWeight | Acc]);
    
alter_weight([], _AlterLimit, Acc) ->
    lists:reverse(Acc).


%%
%% saturation/3
%%
saturation(Value, Min, Max) ->
    if
        Value < Min -> Min;
        Value > Max -> Max;
        true -> Value
    end.
