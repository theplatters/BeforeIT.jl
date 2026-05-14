import BeforeIT as Bit
using JLD2, Dates


@testset "prediction pipeline deterministic" begin
    cal = Bit.ITALY_CALIBRATION
    calibration_date = DateTime(2010, 03, 31)
    parameters, initial_conditions = Bit.get_params_and_initial_conditions(cal, calibration_date; scale = 0.0001)

    T = 12
    n_sims = 2
    model = Bit.Model(parameters, initial_conditions)

    real_data = Bit.ITALY_CALIBRATION.data
    model_vector_a = Bit.ensemblerun!((deepcopy(model) for _ in 1:n_sims), T, parallel = false)
    model_vector_b = Bit.ensemblerun!((deepcopy(model) for _ in 1:n_sims), T, parallel = false)

    predictions_a = Bit.get_predictions_from_sims(Bit.DataVector(model_vector_a), real_data, calibration_date)
    predictions_b = Bit.get_predictions_from_sims(Bit.DataVector(model_vector_b), real_data, calibration_date)

    @test Set(keys(predictions_a)) == Set(keys(predictions_b))
    for key in keys(predictions_a)
        @test isapprox(predictions_a[key], predictions_b[key], atol = 1.0e-6, rtol = 1.0e-6)
    end

    @test size(predictions_a["real_gdp_quarterly"], 2) == n_sims
    @test size(predictions_a["nominal_gdp_quarterly"], 2) == n_sims
    @test size(predictions_a["euribor"], 2) == n_sims
    @test size(predictions_a["real_gdp_quarterly"], 1) == T
end
