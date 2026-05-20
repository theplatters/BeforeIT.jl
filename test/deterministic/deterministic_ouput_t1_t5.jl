using MAT: matread

@testset "time 1 and 5 deterministic" begin
    dir = @__DIR__
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions

    model = Bit.Model(parameters, initial_conditions)
    Bit.step!(model; parallel = false)
    Bit.collect_data!(model)

    output_t1 = matread(joinpath(dir, "../matlab_code/output_t1.mat"))

    data = model.data
    for fieldname in keys(output_t1)
        julia_output = getfield(data, Symbol(fieldname))
        julia_output = fieldname in ["nominal_sector_gva", "real_sector_gva"] ? reduce(hcat, julia_output)' : julia_output
        matlab_output = output_t1[fieldname]

        if fieldname in ["nominal_sector_gva", "real_sector_gva"]
            @test isapprox(julia_output[2:2, :], matlab_output, rtol = 1.0e-5)
        else
            julia_scalar = julia_output[2]
            matlab_scalar = matlab_output isa AbstractArray ? matlab_output[1] : matlab_output
            @test isapprox(julia_scalar, matlab_scalar, rtol = 1.0e-5)
        end
    end

    model = Bit.Model(parameters, initial_conditions)
    for _ in 1:5
        Bit.step!(model; parallel = false)
        Bit.collect_data!(model)
    end

    output_t5 = matread(joinpath(dir, "../matlab_code/output_t5.mat"))

    data = model.data
    for fieldname in keys(output_t5)
        julia_output = getfield(data, Symbol(fieldname))
        julia_output = fieldname in ["nominal_sector_gva", "real_sector_gva"] ? reduce(hcat, julia_output)' : julia_output
        matlab_output = output_t5[fieldname]

        if fieldname in ["nominal_sector_gva", "real_sector_gva"]
            @test isapprox(julia_output[2:end, :], matlab_output, rtol = 1.0e-5)
        else
            @test isapprox(vec(julia_output[2:end]), vec(matlab_output'), rtol = 1.0e-4)
        end
    end
end
