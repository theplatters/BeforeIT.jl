using Pkg

Pkg.develop("Ark")

import BeforeIT as Bit
import Ark

using Test
using Runic

@testset "BeforeIT.jl Tests" begin
    @testset "Utils" begin
        include("utils/positive.jl")
        include("utils/randpl.jl")
        include("utils/nfvar3_and_estimate.jl")
        include("utils/estimations.jl")
        include("utils/zenodo_calibration.jl")
    end

    @testset "Shocks" begin
        # include("shocks/shocks.jl")
    end

    @testset "Invariants" begin
        include("invariants/init_model.jl")
        include("invariants/accounting_identities.jl")
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
        include("systems/markets/search_and_matching.jl")
        include("systems/rotw.jl")
    end


    @testset "Quality (Aqua.jl)" begin
        include("package_sanity_tests.jl")
    end

    # WARNING: this should be the last include among behavior tests because it
    # overrides randomness to make subsequent model runs deterministic.
    include("deterministic/runtests_deterministic.jl")

    @testset "Format (Runic.jl)" begin
        isformat = Bit.format_package(check = true)
        @test isformat == true
        if isformat == false
            @warn "Formatting failed: use `import BeforeIT as Bit; using Runic; Bit.format_package()` to run the formatter"
        end
    end
end
