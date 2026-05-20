using BenchmarkTools
using Chairmarks
using BeforeIT

const SUITE = BenchmarkGroup()

include("bench_step.jl")
# Prepares the model right up to the Credit Market phase
function setup_for_credit_market()
    m = BeforeIT.AUSTRIA2010Q1 |> BeforeIT.ECSModel
    world = m.world

    BeforeIT.finance_insolvent_firms!(world)
    BeforeIT.set_growth_inflation_expectations!(world)
    BeforeIT.set_epsilon!(world)
    BeforeIT.set_growth_inflation_EA!(world)
    BeforeIT.set_central_bank_rate!(world)
    BeforeIT.set_bank_rate!(world)
    BeforeIT.set_firms_expectations_and_decisions!(world)

    return m.world
end

function setup_for_labor_market()
    m = BeforeIT.AUSTRIA2010Q1 |> BeforeIT.ECSModel
    world = m.world

    BeforeIT.finance_insolvent_firms!(world)
    BeforeIT.set_growth_inflation_expectations!(world)
    BeforeIT.set_epsilon!(world)
    BeforeIT.set_growth_inflation_EA!(world)
    BeforeIT.set_central_bank_rate!(world)
    BeforeIT.set_bank_rate!(world)
    BeforeIT.set_firms_expectations_and_decisions!(world)
    BeforeIT.search_and_matching_credit!(world)

    return m.world
end

# Prepares the model right up to the General Search and Matching phase
function setup_for_general_sm()
    # Build on top of the previous setup so you don't repeat yourself
    m = BeforeIT.AUSTRIA2010Q1 |> BeforeIT.ECSModel
    world = m.world

    BeforeIT.finance_insolvent_firms!(world)
    BeforeIT.set_growth_inflation_expectations!(world)
    BeforeIT.set_epsilon!(world)
    BeforeIT.set_growth_inflation_EA!(world)
    BeforeIT.set_central_bank_rate!(world)
    BeforeIT.set_bank_rate!(world)
    BeforeIT.set_firms_expectations_and_decisions!(world)
    BeforeIT.search_and_matching_credit!(world)
    BeforeIT.search_and_matching_labor!(world)
    BeforeIT.set_firms_wages!(world)
    BeforeIT.set_firms_production!(world)
    BeforeIT.update_workers_wages!(world)
    BeforeIT.set_gov_social_benefits!(world)
    BeforeIT.set_bank_expected_profits!(world)
    BeforeIT.set_households_expected_income!(world)
    BeforeIT.set_households_budget!(world)
    BeforeIT.set_gov_expenditure!(world)
    BeforeIT.set_rotw_import_export!(world)

    return m.world
end


# Benchmark 1: Credit Market
SUITE["credit_market"] = @be setup_for_credit_market() BeforeIT.search_and_matching_credit!(deepcopy(_))
SUITE["labor_market"] = @be setup_for_labor_market() BeforeIT.search_and_matching_credit!(deepcopy(_))
SUITE["search_and_matching"] = @be setup_for_credit_market() BeforeIT.search_and_matching!(deepcopy(_))
