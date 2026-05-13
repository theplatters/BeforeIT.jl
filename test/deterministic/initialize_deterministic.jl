@testset "initialize deterministic" begin
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions

    model = Bit.Model(parameters, initial_conditions)
    model2 = Bit.Model(parameters, initial_conditions)

    signature = _state_signature(model)
    signature2 = _state_signature(model2)

    _assert_approx_signature(signature, signature2)

    @test signature.employed > 0
    @test signature.firms > 0
    @test signature.household_income > 0
    @test signature.firm_output > 0
    @test signature.aggregate_price == 1.0
    @test signature.household_price == 1.0
    @test signature.capital_goods_price == 1.0
end
