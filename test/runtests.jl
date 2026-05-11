using Pkg

Pkg.develop("Ark")

import BeforeIT as Bit
import Ark

using Test

@testset "BeforeIT.jl Tests" begin
    @testset "Utils" begin
        include("utils/positive.jl")
        include("utils/randpl.jl")
        # include("utils/nfvar3_and_estimate.jl")
        # include("utils/estimations.jl")
        # include("utils/modify.jl")
        # include("utils/zenodo_calibration.jl")
    end

    @testset "Markets" begin
        # include("markets/search_and_matching.jl")
    end

    @testset "Agent Actions" begin
        # include("agent_actions/bank.jl")
        include("agent_actions/central_bank.jl")
        # include("agent_actions/firms.jl")
        # include("agent_actions/estimations.jl")
    end

    @testset "Accounting Identities" begin
        # include("accounting_identities.jl")
    end

    @testset "Shocks" begin
        # include("shocks/shocks.jl")
    end

    @testset "Model Init" begin
        include("model_init/init_model.jl")
    end

    @testset "Systems" begin
        include("systems/old_actions/mock_model.jl")
        include("systems/aggregates.jl")
        include("systems/banks.jl")
        include("systems/central_bank.jl")
        include("systems/epsilon.jl")
        include("systems/estimations.jl")
        include("systems/firms.jl")
        include("systems/government.jl")
        include("systems/households.jl")
        include("systems/rotw.jl")
        # include("systems/markets/search_and_matching.jl")
    end


    @testset "Quality (Aqua.jl)" begin
        include("package_sanity_tests.jl")
    end

    # WARNING: this should be the last include when the deterministic suite is re-enabled.
    # include("deterministic/runtests_deterministic.jl")

    @testset "Format (Runic.jl)" begin
        isformat = Bit.format_package(check = true)
        @test isformat == true
        if isformat == false
            @warn "Formatting failed: use `import BeforeIT as Bit; using Runic; Bit.format_package()` to run the formatter"
        end
    end
end
