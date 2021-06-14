-module(morphology).
-compile(export_all).
-include("records.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Get Init Standard Actuators/Sensors %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_init_sensors(Morphology) ->
	Sensors = morphology:Morphology(sensors),
	[lists:nth(1,Sensors)].

get_init_actuators(Morphology) ->
	Actuators = morphology:Morphology(actuators),
	[lists:nth(1,Actuators)].

get_sensors(Morphology) ->
	morphology:Morphology(sensors).

get_actuators(Morphology) ->
	morphology:Morphology(actuators).
	
%% MORPHOLOGIES
%%
xor_mimic(sensors) ->
	[
		#sensor{id={sensor, generate_id()}, name=xor_get_signal, scape={private, xor_sim}, vec_len=2}
	];
xor_mimic(actuators) ->
	[
		#actuator{id={actuator, generate_id()}, name=xor_send_out, scape={private, xor_sim}, vec_len=1}
	].
%*Every sensor and actuator uses some kind of function associated with it. A function that either polls the environment for sensory signals (in the case of a sensor) or acts upon the environment (in the case of an actuator). It is a function that we need to define and program before it is used, and the name of the function is the same as the name of the sensor or actuator it self. For example, the create_Sensor/1 has specified only the rng sensor, because that is the only sensor function we've finished developing. The rng function has its own vl specification, which will determine the number of weights that a neuron will need to allocate if it is to accept this sensor's output vector. The same principles apply to the create_Actuator function. Both, create_Sensor and create_Actuator function, given the name of the sensor or actuator, will return a record with all the specifications of that element, each with its own unique Id.


%%
%% generate unique id
%%
generate_id() ->
    1/erlang:unique_integer([positive]).