import BeforeIT as Bit
using JLD2, Dates

@testset "prediction pipeline deterministic" begin
    reference_file = joinpath(@__DIR__, "2010Q1.jld2")
    reference_predictions = load(reference_file)["model_dict"]

    cal = Bit.ITALY_CALIBRATION
    calibration_date = DateTime(2010, 03, 31)
    parameters, initial_conditions = Bit.get_params_and_initial_conditions(cal, calibration_date; scale = 0.0001)

    T = 12
    n_sims = 2
    model = Bit.Model(parameters, initial_conditions)

    real_data = Bit.ITALY_CALIBRATION.data
    model_vector = Bit.ensemblerun!((deepcopy(model) for _ in 1:n_sims), T, parallel = false)

    predictions_dict = Bit.get_predictions_from_sims(Bit.DataVector(model_vector), real_data, calibration_date)

    @test Set(keys(predictions_dict)) == Set(keys(reference_predictions))
    for key in keys(predictions_dict)
        @test size(predictions_dict[key]) == size(reference_predictions[key])
        size(predictions_dict[key]) == size(reference_predictions[key]) || continue
        @test isapprox(predictions_dict[key], reference_predictions[key], atol = 1.0e-6, rtol = 1.0e-6)
    end
end
