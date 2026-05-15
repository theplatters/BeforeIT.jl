using PrecompileTools

@setup_workload let
    parameters = AUSTRIA2010Q1.parameters
    initial_conditions = AUSTRIA2010Q1.initial_conditions
    @compile_workload let
        model = Model(parameters, initial_conditions)
        step!(model)
    end
end
