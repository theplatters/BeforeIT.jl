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
            (Bit.RealisedConsumption, Bit.RealisedInvestment),
            with = (Bit.Household,)
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
                Bit.Investment,
                Bit.MaterialsStockChange,
                Bit.PriceIndex,
                Bit.CFPriceIndex,
                Bit.GoodsDemand,
            ),
            with = (Bit.Firm,)
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

    for (_, realised_consumption) in Ark.Query(world, (Bit.RealisedConsumption,), with = (Bit.Government,))
        metrics[:gov_C_j] = sum(realised_consumption.amount)
    end

    for (_, foreign_consumption) in Ark.Query(world, (Bit.ForeignConsumption,))
        metrics[:rotw_C_l] = sum(foreign_consumption.amount)
    end

    import_demand = Float64[]
    for (_, demand) in Ark.Query(world, (Bit.ImportDemand,))
        append!(import_demand, demand.amount)
    end
    metrics[:mean_Q_d_m] = mean(import_demand)

    return metrics
end

@testset "Labor Firing Preserves Benefit Base" begin
    world = Bit.ECSModel(Bit.STEADY_STATE2010Q1).world

    firm_entity = nothing
    worker_entity = nothing
    target_wage = nothing
    for (firm_e, employment, average_wage) in collect(
            Ark.Query(
                world,
                (
                    Bit.Employment,
                    Bit.AverageWageRate,
                ),
                with = (Bit.Firm,)
            )
        )
        for i in eachindex(firm_e)
            employment[i].amount > 0 || continue
            firm_entity = firm_e[i]
            target_wage = average_wage[i].rate
            break
        end
        firm_entity === nothing || break
    end

    for (worker_e, employed) in collect(Ark.Query(world, (Bit.Employed,), with = (Bit.EmployedAt => firm_entity,)))
        worker_entity = worker_e[1]
        target_wage = employed[1].rate
        break
    end

    for (firm_e, employment, desired_employment) in collect(
            Ark.Query(
                world,
                (
                    Bit.Employment,
                    Bit.DesiredEmployment,
                ),
                with = (Bit.Firm,)
            )
        )
        for i in eachindex(firm_e)
            firm_e[i] == firm_entity || continue
            desired_employment[i] = Bit.DesiredEmployment(0)
        end
    end

    @test firm_entity !== nothing
    @test worker_entity !== nothing
    @test target_wage !== nothing

    Bit.calculate_initial_vacancies!(world)
    Bit.fire_employed_workers!(world)

    @test !Ark.has_components(world, worker_entity, (Bit.Employed, Bit.EmployedAt))
    @test Ark.has_components(world, worker_entity, (Bit.Unemployed,))
    (unemployed,) = Ark.get_components(world, worker_entity, (Bit.Unemployed,))
    @test isapprox(unemployed.unemployment_benefits, target_wage; atol = 1.0e-9, rtol = 1.0e-9)
end

@testset "Search and Matching Integration Regression" begin
    Random.seed!(1)
    world = Bit.ECSModel(Bit.AUSTRIA2010Q1).world
    run_pre_market_pipeline!(world)
    metrics = collect_market_integration_metrics(world)

    @test isapprox(metrics[:mean_I_h], 0.32975, atol = 3 * 0.0025351)
    @test isapprox(metrics[:mean_C_h], 3.973, atol = 3 * 0.029366)
    @test isapprox(metrics[:mean_I_i], 20.5075, atol = 3 * 0.12763)
    @test isapprox(metrics[:mean_DM_i], 109.3163, atol = 3 * 0.68033)
    @test isapprox(metrics[:mean_P_bar_i], 1.0031, atol = 3 * 0.0044726)
    @test isapprox(metrics[:mean_P_CF_i], 1.0031, atol = 3 * 0.0044726)
    @test isapprox(metrics[:gov_C_j], 14752.2413, atol = 3 * 126.7441)
    @test isapprox(metrics[:rotw_C_l], 34188.1258, atol = 3 * 666.275)
    @test isapprox(metrics[:mean_Q_d_i], 216.2474, atol = 3 * 1.2275)
    @test isapprox(metrics[:mean_Q_d_m], 535.7522, atol = 3 * 9.6082)
end
