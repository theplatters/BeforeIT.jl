using MAT: matread

@testset "initialize deterministic" begin
    dir = @__DIR__
    model = Bit.Model(Bit.AUSTRIA2010Q1.parameters, Bit.AUSTRIA2010Q1.initial_conditions)
    props = Bit.properties(model)
    total_firms = props.dimensions.total_firms
    inactive = props.population.inactive
    employable = props.population.active - total_firms - 1
    firm_owner_range = (employable + inactive + 1):(employable + inactive + total_firms)

    firms = _firm_reference_state(model)
    firms_ref = matread(joinpath(dir, "../matlab_code/init_vars_firms.mat"))
    for field in keys(firms)
        matlab_value = if field in (:D_h, :K_h, :Y_h)
            vec(firms_ref[string(field)][firm_owner_range])
        else
            _mat_vector(firms_ref[string(field)])
        end
        @test isapprox(getfield(firms, field), matlab_value)
    end

    bank = _bank_reference_state(model)
    bank_ref = matread(joinpath(dir, "../matlab_code/init_vars_bank.mat"))
    for field in keys(bank)
        @test isapprox(getfield(bank, field), _mat_vector(bank_ref[string(field)]))
    end

    households = _all_household_reference_state(model)
    households_ref = matread(joinpath(dir, "../matlab_code/init_vars_households.mat"))
    @test isapprox(households.w_h, _mat_vector(households_ref["w_h"]))
    @test isapprox(households.O_h, _mat_vector(households_ref["O_h"]))
    @test isapprox(households.Y_h, _mat_vector(households_ref["Y_h"]))
    @test isapprox(households.D_h, _mat_vector(households_ref["D_h"]))
    @test isapprox(households.K_h, _mat_vector(households_ref["K_h"]))
end
