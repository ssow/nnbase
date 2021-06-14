{application, 'nnbase', [
	{description, "TWEANNS"},
	{vsn, "rolling"},
	{modules, ['actuator','cortex','genotype','morphology','neuron','phenotype','scape','sensor','trainer']},
	{registered, []},
	{applications, [kernel,stdlib]},
	{env, []}
]}.