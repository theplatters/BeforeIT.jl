@testset "run deterministic" begin
    T = 3
    function run_deterministic(properties, T, m)
        model = Bit.Model(properties)
        for t in 1:(T - 1)
            Bit.step!(model; parallel = m)
            Bit.collect_data!(model)
        end
        return model
    end

    model = run_deterministic(Bit.AUSTRIA2010Q1, T, false)
    model2 = run_deterministic(Bit.AUSTRIA2010Q1, T, false)
    model3 = run_deterministic(Bit.AUSTRIA2010Q1, T, true)

    # loop over the data fields and compare them
    data, data2, data3 = model.data, model2.data, model3.data
    for field in fieldnames(typeof(data))
        @test isapprox(getproperty(data, field), getproperty(data2, field), rtol = 0.0001)
        @test isapprox(getproperty(data2, field), getproperty(data3, field), rtol = 0.0001)
    end
end
