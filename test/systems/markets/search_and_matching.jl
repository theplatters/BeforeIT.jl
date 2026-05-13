using Test
import BeforeIT as Bit
import Ark
using Statistics
using Random
import WeightVectors

# Workaround for missing macro and types in scope
const AbstractModel = Bit.AbstractModel
zero_to_one(x) = iszero(x) ? one(x) : x
macro maybe_threads(parallel, loop)
    return esc(loop)
end

# Include old actions
include("../old_actions/mock_model.jl")
include("../old_actions/search_and_matching.jl")

function setup_test_world(properties; overrides...)
    world = Bit.ECSModel(properties).world

    # Ensure all demand sources are zeroed unless specified
    I = properties.dimensions.total_firms
    H_act = properties.population.active
    H_inact = properties.population.inactive
    G = properties.dimensions.sectors
    J = properties.dimensions.local_governments
    L = properties.dimensions.foreign_consumers

    base_overrides = (
        firms_DM_d_i = fill(0.0, I),
        firms_I_d_i = fill(0.0, I),
        w_act_C_d_h = fill(0.0, H_act),
        w_act_I_d_h = fill(0.0, H_act),
        w_inact_C_d_h = fill(0.0, H_inact),
        w_inact_I_d_h = fill(0.0, H_inact),
        firms_C_d_h = fill(0.0, I),
        firms_I_d_h = fill(0.0, I),
        bank_C_d_h = 0.0,
        bank_I_d_h = 0.0,
        gov_C_d_j = fill(0.0, J),
        rotw_C_d_l = fill(0.0, L),
    )

    # Merge overrides (user overrides take precedence)
    final_overrides = merge(base_overrides, overrides)

    set_mock_components!(world; final_overrides...)

    # Sync aggregate price indices
    pi_indices = Bit.price_indices(world)
    pi_indices.household_consumption = 1.0
    pi_indices.capital_goods = 1.0
    pi_indices.sector .= 1.0
    pi_indices.aggregate = 1.0
    pi_indices.household_consumption_previous = 1.0
    pi_indices.capital_formation_households = 1.0

    return world
end

function run_pre_market_pipeline!(world)
    Bit.finance_insolvent_firms!(world)
    Bit.set_growth_inflation_expectations!(world)
    Bit.set_epsilon!(world)
    Bit.set_growth_inflation_EA!(world)
    Bit.set_central_bank_rate!(world)
    Bit.set_bank_rate!(world)
    Bit.set_firms_expectations_and_decisions!(world)
    Bit.search_and_matching_credit!(world)
    Bit.search_and_matching_labor!(world)
    Bit.set_firms_wages!(world)
    Bit.set_firms_production!(world)
    Bit.update_workers_wages!(world)
    Bit.set_gov_social_benefits!(world)
    Bit.set_bank_expected_profits!(world)
    Bit.set_households_expected_income!(world)
    Bit.set_households_budget!(world)
    Bit.set_gov_expenditure!(world)
    Bit.set_rotw_import_export!(world)
    Bit.search_and_matching!(world)
    return world
end

function collect_market_integration_metrics(world)
    metrics = Dict{Symbol, Float64}()

    household_consumption = Float64[]
    household_investment = Float64[]
    for (_, realised_consumption, realised_investment) in Ark.Query(
            world,
            (Bit.Components.RealisedConsumption, Bit.Components.RealisedInvestment),
            with = (Bit.Components.Household,)
        )
        append!(household_consumption, realised_consumption.amount)
        append!(household_investment, realised_investment.amount)
    end
    metrics[:mean_I_h] = mean(household_investment)
    metrics[:mean_C_h] = mean(household_consumption)

    firm_investment = Float64[]
    firm_materials = Float64[]
    firm_price_index = Float64[]
    firm_cf_price_index = Float64[]
    firm_goods_demand = Float64[]
    for (_, investment, materials, price_index, cf_price_index, goods_demand) in Ark.Query(
            world,
            (
                Bit.Components.Investment,
                Bit.Components.MaterialsStockChange,
                Bit.Components.PriceIndex,
                Bit.Components.CFPriceIndex,
                Bit.Components.GoodsDemand,
            ),
            with = (Bit.Components.Firm,)
        )
        append!(firm_investment, investment.amount)
        append!(firm_materials, materials.amount)
        append!(firm_price_index, price_index.value)
        append!(firm_cf_price_index, cf_price_index.value)
        append!(firm_goods_demand, goods_demand.amount)
    end
    metrics[:mean_I_i] = mean(firm_investment)
    metrics[:mean_DM_i] = mean(firm_materials)
    metrics[:mean_P_bar_i] = mean(firm_price_index)
    metrics[:mean_P_CF_i] = mean(firm_cf_price_index)
    metrics[:mean_Q_d_i] = mean(firm_goods_demand)

    for (_, realised_consumption) in Ark.Query(world, (Bit.Components.RealisedConsumption,), with = (Bit.Components.Government,))
        metrics[:gov_C_j] = sum(realised_consumption.amount)
    end

    for (_, foreign_consumption) in Ark.Query(world, (Bit.Components.ForeignConsumption,))
        metrics[:rotw_C_l] = sum(foreign_consumption.amount)
    end

    import_demand = Float64[]
    for (_, demand) in Ark.Query(world, (Bit.Components.ImportDemand,))
        append!(import_demand, demand.amount)
    end
    metrics[:mean_Q_d_m] = mean(import_demand)

    return metrics
end

@testset "Search and Matching - Edge Cases" begin
    properties = Bit.STEADY_STATE2010Q1
    I = properties.dimensions.total_firms
    G = properties.dimensions.sectors
    H_act = properties.population.active
    H_inact = properties.population.inactive
    J = properties.dimensions.local_governments
    L = properties.dimensions.foreign_consumers

    @testset "Absolute Zero (No Supply, No Demand)" begin
        Random.seed!(42)
        world = setup_test_world(
            properties;
            firms_S_i = fill(0.0, I),
            firms_Y_i = fill(0.0, I),
            rotw_Y_m = fill(0.0, G)
        )
        Bit.search_and_matching!(world)

        total_sales = 0.0
        for (_, sales) in Ark.Query(world, (Bit.Components.Sales,), with = (Bit.Components.Firm,))
            total_sales += sum(sales.amount)
        end
        @test total_sales == 0.0
    end

    @testset "Floating Point Precision (Very Small Demand)" begin
        Random.seed!(42)
        tiny_val = 1.0e-15
        world = setup_test_world(
            properties;
            firms_S_i = fill(1.0, I),
            firms_Y_i = fill(0.0, I),
            firms_P_i = fill(1.0, I),
            w_act_C_d_h = [tiny_val; fill(0.0, H_act - 1)]
        )
        prop_res = Bit.properties(world)
        prop_res.product_coeffs.household_consumption .= 0.0
        prop_res.product_coeffs.household_consumption[1] = 1.0

        Bit.search_and_matching!(world)

        total_sales = 0.0
        for (_, sales) in Ark.Query(world, (Bit.Components.Sales,), with = (Bit.Components.Firm,))
            total_sales += sum(sales.amount)
        end
        @test total_sales > 0.0
    end

    @testset "Mixed Supply (Domestic and Imports)" begin
        Random.seed!(42)
        world = setup_test_world(
            properties;
            firms_S_i = [fill(0.0, 4); 10.0; fill(0.0, I - 5)],
            firms_Y_i = fill(0.0, I),
            firms_G_i = fill(1, I),
            rotw_Y_m = fill(20.0, G),
            rotw_P_m = fill(1.0, G),
            w_act_C_d_h = [25.0; fill(0.0, H_act - 1)]
        )
        prop_res = Bit.properties(world)
        prop_res.product_coeffs.household_consumption .= 0.0
        prop_res.product_coeffs.household_consumption[1] = 1.0

        Bit.search_and_matching!(world)

        total_sales = 0.0
        for (_, sales) in Ark.Query(world, (Bit.Components.Sales,), with = (Bit.Components.Firm,))
            total_sales += sum(sales.amount)
        end
        @test total_sales == 5.0

        total_cons = 0.0
        for (_, realised_c) in Ark.Query(world, (Bit.Components.RealisedConsumption,), with = (Bit.Components.Household,))
            total_cons += sum(realised_c.amount)
        end
        @test total_cons == 25.0
    end

    @testset "Sector Isolation" begin
        Random.seed!(42)
        # Firm 1 in Sector 1, Firm 2 in Sector 2
        # Demand only for Sector 2
        overrides = (
            firms_S_i = [10.0; 10.0; fill(0.0, I - 2)],
            firms_Y_i = fill(0.0, I),
            firms_G_i = [1; 2; fill(3, I - 2)],
            w_act_C_d_h = [15.0; fill(0.0, H_act - 1)],
        )
        world = setup_test_world(properties; overrides...)
        prop_res = Bit.properties(world)
        prop_res.product_coeffs.household_consumption .= 0.0
        prop_res.product_coeffs.household_consumption[2] = 1.0 # Only demand for sector 2

        Bit.search_and_matching!(world)

        # Firm 1 (Sector 1) should have 0 sales
        # Firm 2 (Sector 2) should have 10 sales
        idx = 1
        for (e, sales) in Ark.Query(world, (Bit.Components.Sales,), with = (Bit.Components.Firm,))
            for i in eachindex(e)
                if idx == 1
                    @test sales[i].amount == 0.0
                elseif idx == 2
                    @test sales[i].amount == 10.0
                end
                idx += 1
            end
        end
    end
end

@testset "Search and Matching Parity - Monte Carlo" begin
    properties = Bit.STEADY_STATE2010Q1
    I = properties.dimensions.total_firms
    G = properties.dimensions.sectors
    H_act = properties.population.active
    H_inact = properties.population.inactive
    J = properties.dimensions.local_governments
    L = properties.dimensions.foreign_consumers

    n_runs = 10

    agg_sales_old = zeros(n_runs)
    agg_sales_new = zeros(n_runs)
    agg_cons_old = zeros(n_runs)
    agg_cons_new = zeros(n_runs)

    Random.seed!(42)

    for r in 1:n_runs
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
        test_C_d_l = fill(500.0, L)

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

        world = setup_test_world(properties; overrides...)
        mock_model = build_mock_model(properties; overrides...)

        mock_model.agg.P_bar_HH = 1.0
        mock_model.agg.P_bar_CF = 1.0
        mock_model.agg.P_bar_g .= 1.0

        Random.seed!(r)
        Bit.search_and_matching!(world)

        Random.seed!(r)
        search_and_matching!(mock_model)

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

    @test isapprox(mean(agg_sales_old), mean(agg_sales_new), rtol = 0.2)
    @test isapprox(mean(agg_cons_old), mean(agg_cons_new), rtol = 0.2)
end

@testset "Search and Matching Integration Regression" begin
    Random.seed!(1)
    world = Bit.ECSModel(Bit.AUSTRIA2010Q1).world
    run_pre_market_pipeline!(world)
    metrics = collect_market_integration_metrics(world)

    @test isapprox(metrics[:mean_I_h], 0.28012067227587173, rtol = 0.02)
    @test isapprox(metrics[:mean_C_h], 3.373900754892568, rtol = 0.02)
    @test isapprox(metrics[:mean_I_i], 20.44490406457435, rtol = 0.02)
    @test isapprox(metrics[:mean_DM_i], 108.98282471230276, rtol = 0.02)
    @test isapprox(metrics[:mean_P_bar_i], 0.9967957252316543, rtol = 0.02)
    @test isapprox(metrics[:mean_P_CF_i], 0.9967957252316543, rtol = 0.02)
    @test isapprox(metrics[:gov_C_j], 14883.394898352044, rtol = 0.02)
    @test isapprox(metrics[:rotw_C_l], 33152.52973913658, rtol = 0.05)
    @test isapprox(metrics[:mean_Q_d_i], 208.46284581727244, rtol = 0.02)
    @test isapprox(metrics[:mean_Q_d_m], 508.0841371772294, rtol = 0.05)
end
