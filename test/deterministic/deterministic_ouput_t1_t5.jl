@testset "time 1 and 5 deterministic" begin
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions

    step1_a = Bit.Model(parameters, initial_conditions)
    step1_b = Bit.Model(parameters, initial_conditions)
    Bit.step!(step1_a; parallel = false)
    Bit.step!(step1_b; parallel = false)

    _assert_approx_collector(step1_a.data, step1_b.data; rtol = 1.0e-6, atol = 1.0e-6)
    @test length(step1_a.data.collection_time) == 1

    step5_a = Bit.Model(parameters, initial_conditions)
    step5_b = Bit.Model(parameters, initial_conditions)
    Bit.run!(step5_a, 5; parallel = false)
    for _ in 1:5
        Bit.step!(step5_b; parallel = false)
    end

    _assert_approx_collector(step5_a.data, step5_b.data; rtol = 1.0e-6, atol = 1.0e-6)
    @test length(step5_a.data.collection_time) == 5

    for field in fieldnames(typeof(step1_a.data))
        @test isapprox(
            getfield(step1_a.data, field),
            getfield(step5_a.data, field)[begin:begin],
            rtol = 1.0e-6,
            atol = 1.0e-6,
        )
    end
end
