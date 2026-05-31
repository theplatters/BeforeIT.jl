using PrecompileTools

@setup_workload let
    @compile_workload let
        model = Model(AUSTRIA2010Q1)
        step!(model)
    end
end
