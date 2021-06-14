%%%
%%% NN trainer
%%%

-module(trainer).
-compile(export_all).
-include("records.hrl").

%%
%% train/2
%%
train(Morphology, HiddenLayerDensities) ->
    train(Morphology, HiddenLayerDensities, ?MAX_TRIES, ?EVAL_LIMIT, ?FITNESS_TARGET).


%%
%% train/5
%%
train(Morphology, HiddenLayerDensities, MaxTries, EvalLimit, FitnessTarget) ->
    Pid = spawn_link(?MODULE, loop, [Morphology, HiddenLayerDensities, FitnessTarget, {1, MaxTries}, {0, EvalLimit}, {0, best}, experimental, 0, 0]),
    register(?MODULE, Pid).

%%
%% loop/9
%%
loop(Morphology, _HiddenLayerDensities, FitnessTarget, {Tries, MaxTries}, {TotalEvals, EvalLimit}, {BestFitness, BestBreed}, _BreedType, _Cycles, _Duration)
    when (Tries >= MaxTries) or (TotalEvals >= EvalLimit) or (BestFitness >= FitnessTarget) ->
    genotype:print(BestBreed),
    unregister(trainer);
    
loop(Morphology, HiddenLayerDensities, FitnessTarget, {Tries, MaxTries}, {TotalEvals, EvalLimit}, {BestFitness, BestBreed}, BreedType, Cycles, Duration) ->
    genotype:construct(BreedType, Morphology, HiddenLayerDensities),
    AgentPid = phenotype:map(BreedType),

    receive
        {AgentPid, Fitness, EvalCount, Loops, Time} ->
            NewTotalEvals = TotalEvals + EvalCount,
            NewCycles = Cycles + Loops,
            NewDuration = Duration + Time,
            case Fitness > BestFitness of
                true ->
                    file:rename(BreedType, BestBreed),
                    ?MODULE:loop(Morphology, HiddenLayerDensities, FitnessTarget, {1, MaxTries}, {NewTotalEvals, EvalLimit}, {Fitness, BestBreed}, BreedType, NewCycles, NewDuration);
                
                false ->
                    ?MODULE:loop(Morphology, HiddenLayerDensities, FitnessTarget, {Tries + 1, MaxTries}, {NewTotalEvals, EvalLimit}, {BestFitness, BestBreed}, BreedType, NewCycles, NewDuration)
            end;

        terminate ->
            io:format("Trainer Terminated ...~n"),
            genotype:print(BestBreed),
            io:format("Morphology: ~p Best Fitness: ~p EvalCount: ~p~n", [Morphology, BestFitness, TotalEvals])
    end.
