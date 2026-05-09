using Test
import BeforeIT as Bit
import Ark
using Statistics
using Random
import WeightVectors

# Workaround for missing macro in Main
# This macro is used in the old search_and_matching.jl
zero_to_one(x) = iszero(x) ? one(x) : x

# Include old actions
include("../old_actions/mock_model.jl")
include("../old_actions/search_and_matching.jl")

@testset "Search and Matching Parity - Monte Carlo" begin
    properties = Bit.STEADY_STATE2010Q1
    I = properties.dimensions.total_firms
    G = properties.dimensions.sectors
    H_act = properties.population.active
    H_inact = properties.population.inactive
    J = properties.dimensions.local_governments

    # 100 runs for parity check, 1000 for extensive as requested
    n_runs = 100

    agg_sales_old = zeros(n_runs)
    agg_sales_new = zeros(n_runs)
    agg_cons_old = zeros(n_runs)
    agg_cons_new = zeros(n_runs)

    Random.seed!(42)

    for r in 1:n_runs
        println(r)
        # 1. Generate random state for this iteration
        test_S_i = rand(I) .* 10.0
        test_Y_i = rand(I) .* 20.0
        test_P_i = 1.0 .+ rand(I) .* 0.5
        test_DM_d_i = rand(I) .* 10.0
        test_I_d_i = rand(I) .* 5.0
        test_G_i = rand(1:G, I)

        test_C_d_h_act = rand(H_act) .* 5.0
        test_I_d_h_act = rand(H_act) .* 1.0
        test_C_d_h_inact = rand(H_inact) .* 3.0
        test_I_d_h_inact = rand(H_inact) .* 0.5
        test_C_d_h_firms = rand(I) .* 2.0
        test_I_d_h_firms = rand(I) .* 0.5
        test_C_d_h_bank = 10.0
        test_I_d_h_bank = 2.0

        test_C_d_j = rand(J) .* 10.0
        test_C_d_l = fill(500.0, properties.dimensions.foreign_consumers)

        overrides = (
            firms_S_i = test_S_i,
            firms_Y_i = test_Y_i,
            firms_P_i = test_P_i,
            firms_DM_d_i = test_DM_d_i,
            firms_I_d_i = test_I_d_i,
            firms_G_i = test_G_i,
            w_act_C_d_h = test_C_d_h_act,
            w_act_I_d_h = test_I_d_h_act,
            w_inact_C_d_h = test_C_d_h_inact,
            w_inact_I_d_h = test_I_d_h_inact,
            firms_C_d_h = test_C_d_h_firms,
            firms_I_d_h = test_I_d_h_firms,
            bank_C_d_h = test_C_d_h_bank,
            bank_I_d_h = test_I_d_h_bank,
            gov_C_d_j = test_C_d_j,
            rotw_C_d_l = test_C_d_l,
            rotw_Y_m = rand(G) .* 100.0,
            rotw_P_m = 1.0 .+ rand(G) .* 0.2,
        )

        # 2. Setup ECS Model
        world = Bit.ECSModel(properties).world
        set_mock_components!(world; overrides...)

        # Sync aggregate price indices
        pi_indices = Bit.price_indices(world)
        pi_indices.household_consumption = 1.0
        pi_indices.capital_goods = 1.0
        pi_indices.sector .= 1.0

        # 3. Setup Mock Model (OOP)
        mock_model = build_mock_model(properties; overrides...)
        mock_model.agg.P_bar_HH = 1.0
        mock_model.agg.P_bar_CF = 1.0
        mock_model.agg.P_bar_g .= 1.0

        # 4. Execute both systems
        Random.seed!(r)
        Bit.search_and_matching!(world)
        @info "finished for the new model"

        Random.seed!(r)
        search_and_matching!(mock_model)

        # 5. Extract results
        agg_sales_old[r] = sum(mock_model.firms.Q_i)
        agg_cons_old[r] = sum(mock_model.w_act.C_h) + sum(mock_model.w_inact.C_h) +
            sum(mock_model.firms.C_h) + mock_model.bank.C_h

        total_sales_new = 0.0
        for (_, sales) in Ark.Query(world, (Bit.Components.Sales,), with = (Bit.Components.Firm,))
            total_sales_new += sum(sales.amount)
        end
        agg_sales_new[r] = total_sales_new

        total_cons_new = 0.0
        for (_, realised_c) in Ark.Query(world, (Bit.Components.RealisedConsumption,), with = (Bit.Components.Household,))
            total_cons_new += sum(realised_c.amount)
        end
        agg_cons_new[r] = total_cons_new
    end

    # 6. Statistical Comparison
    # Using 10% tolerance as search and matching is highly sensitive to RNG sequences
    # which might slightly differ in how many times rand() is called between implementations.
    @test isapprox(mean(agg_sales_old), mean(agg_sales_new), rtol = 0.1)
    @test isapprox(mean(agg_cons_old), mean(agg_cons_new), rtol = 0.1)
end
