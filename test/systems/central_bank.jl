using Test

@testset "Central Bank Helper Tests" begin
    @testset "taylor_rule" begin
        rho = 1.0
        r_bar = -0.1
        r_star = 0.1
        pi_star = 0.1
        xi_pi = 0.5
        xi_gamma = 0.5
        gamma_EA = 0.1
        pi_EA = 0.1

        rate = Bit.taylor_rule(rho, r_bar, r_star, pi_star, xi_pi, xi_gamma, gamma_EA, pi_EA)
        @test isapprox(rate, 0.0, atol = 1.0e-10)
    end
end
