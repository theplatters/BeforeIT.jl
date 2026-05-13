@testset "one epoch deterministic" begin
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions

    serial_model = Bit.Model(parameters, initial_conditions)
    serial_model_2 = Bit.Model(parameters, initial_conditions)
    parallel_model = Bit.Model(parameters, initial_conditions)

    Bit.step!(serial_model; parallel = false)
    Bit.step!(serial_model_2; parallel = false)
    Bit.step!(parallel_model; parallel = true)

    serial_signature = _state_signature(serial_model)
    serial_signature_2 = _state_signature(serial_model_2)
    parallel_signature = _state_signature(parallel_model)

    _assert_approx_signature(serial_signature, serial_signature_2; rtol = 1.0e-6, atol = 1.0e-6)
    _assert_approx_signature(serial_signature, parallel_signature; rtol = 1.0e-6, atol = 1.0e-6)

    _assert_approx_collector(serial_model.data, serial_model_2.data; rtol = 1.0e-6, atol = 1.0e-6)
    _assert_approx_collector(serial_model.data, parallel_model.data; rtol = 1.0e-6, atol = 1.0e-6)

    @test length(serial_model.data.collection_time) == 1
    @test serial_signature.firm_output > 0
    @test serial_signature.household_consumption > 0
    @test serial_signature.bank_equity > 0
end
