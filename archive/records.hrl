%%
%% NN system objects representation
%%

-record(sensor, {id, cortex_id, name, vec_len, fanout_ids, scape}).
-record(actuator, {id, cortex_id, name, vec_len, fanin_ids, scape}).
-record(neuron, {id, cortex_id, act_func, in_params, out_params}).
-record(cortex, {id, sensor_ids, actuator_ids, neuron_ids}).
