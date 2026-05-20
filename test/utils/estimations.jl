import BeforeIT as Bit
import Ark

using Random

@testset "estimation functions" begin
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    world = Bit.Model(parameters, initial_conditions).world
    expectations = Bit.expectations(world)
    macroeconomic_state = Ark.get_resource(world, Bit.MacroeconomicState)
    properties = Ark.get_resource(world, Bit.Properties)
    time_index = Ark.get_resource(world, Bit.TimeIndex)

    Random.seed!(123)

    time_index.step = 1

    Bit.set_growth_inflation_expectations!(world)
    Y_e = expectations.gross_domestic_product
    gamma_e = expectations.output_growth
    pi_e = expectations.inflation
    Y_e_matlab_single_run, pi_e_matlab_single_run = 136263.963578048, 0.0120934296669606

    @test time_index.step == 1
    @test length(macroeconomic_state.gross_domestic_product_history) >= properties.dimensions.interval_for_expectation_estimation

    @test isapprox(Y_e, Y_e_matlab_single_run, rtol = 0.1)
    @test isapprox(pi_e, pi_e_matlab_single_run, atol = 0.1)
    @test isfinite(gamma_e)

    r_bar = collect(Float64, 1:10)
    pi_EA = collect(Float64, 5:15)
    gamma_EA = collect(Float64, 10:20)

    rho_e = 0.733333333333333
    r_star_e = 0.001240732893301
    xi_pi_e = 1.250000000000001
    xi_gamma_e = -0.250000000000001
    pi_star_e = 0.004962931573204


    rho, r_star, xi_pi, xi_gamma, pi_star = Bit.estimate_taylor_rule(r_bar, pi_EA, gamma_EA)

    @test isapprox(rho, rho_e, rtol = 1.0e-5)
    @test isapprox(r_star, r_star_e, rtol = 1.0e-5)
    @test isapprox(xi_pi, xi_pi_e, rtol = 1.0e-5)
    @test isapprox(xi_gamma, xi_gamma_e, rtol = 1.0e-5)
    @test isapprox(pi_star, pi_star_e, rtol = 1.0e-5)
end
