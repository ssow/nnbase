%% simplest_nn.erl
%%
%%
%%

-module(simplest_nn).
-compile(export_all).

%% initialisation
create() ->
    Weights = [rand:uniform() - 0.5, rand:uniform() - 0.5, rand:uniform() - 0.5],
    NrPid = spawn(?MODULE, neuron, [Weights, undefined, undefined]),
    SnPid = spawn(?MODULE, sensor, [NrPid]),
    AcPid = spawn(?MODULE, actuator, [NrPid]),
    
    NrPid ! {init, SnPid, AcPid},
    register(cortex, spawn(?MODULE, cortex, [SnPid, NrPid, AcPid])).

%% Neuron process
neuron(Weights, SnPid, AcPid) ->
    receive
            {SnPid, forward, Input} ->
                io:format("****Thinking****~n Input: ~p~n with Weights: ~p~n", [Input, Weights]),
                DotProduct = dot(Input, Weights, 0),
                Output = [math:tanh(DotProduct)],
                AcPid ! {self(), forward, Output},
                neuron(Weights, SnPid, AcPid);
                
            {init, NewSnPid, NewAcPid} ->
                neuron(Weights, NewSnPid, NewAcPid);
                
            terminate -> ok
    end.

%% Sensor process
sensor(NrPid) ->
    receive
            sync ->
                SensorySignal = [rand:uniform(), rand:uniform()],
                io:format("****Sensing****:~n Signal from environ. ~p~n", [SensorySignal]),
                NrPid ! {self(), forward, SensorySignal},
                sensor(NrPid);

            terminate -> ok
    end.

%% Actuator process
actuator(NrPid) ->
    receive
        {NrPid, forward, ControlSignal} ->
            pts(ControlSignal),
            actuator(NrPid);
            
        terminate -> ok
    end.
    
%% Cortex process - system management
cortex(SensorPid, NeuronPid, ActuatorPid) ->
    receive
        sense_think_act ->
            SensorPid ! sync,
            cortex(SensorPid, NeuronPid, ActuatorPid);
            
        terminate ->
            SensorPid ! terminate,
            NeuronPid ! terminate,
            ActuatorPid ! terminate,
            ok
    end.
    

%% Helpers functions

%% Computes neuron output value based on weighted input and optional bias  
dot([I|Input], [W|Weights], Acc) ->
    dot(Input, Weights, I*W+Acc);

dot([], [], Acc) ->
    Acc;
    
dot([],[Bias], Acc) ->
    Acc+Bias.

pts(ControlSignal) ->
    io:format("****Acting****:~n Using: ~p to act on environ.~n", [ControlSignal]).
