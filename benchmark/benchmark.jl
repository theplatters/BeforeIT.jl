using BenchmarkTools
using BeforeIT

const SUITE = BenchmarkGroup()
# Prepares the model right up to the Credit Market phase
function setup_for_credit_market(base_model)
    m = deepcopy(base_model)
    world = m.world

    BeforeIT.finance_insolvent_firms!(world)
    BeforeIT.set_growth_inflation_expectations!(world)
    BeforeIT.set_epsilon!(world)
    BeforeIT.set_growth_inflation_EA!(world)
    BeforeIT.set_central_bank_rate!(world)
    BeforeIT.set_bank_rate!(world)
    BeforeIT.set_firms_expectations_and_decisions!(world)

    return m
end

# Prepares the model right up to the General Search and Matching phase
function setup_for_general_sm(base_model)
    # Build on top of the previous setup so you don't repeat yourself
    m = setup_for_credit_market(base_model)
    world = m.world

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

    return m
end


base_model = BeforeIT.AUSTRIA2010Q1 |> BeforeIT.ECSModel
# Benchmark 1: Credit Market
SUITE["credit_market"] = @benchmarkable BeforeIT.search_and_matching_credit!(m.world) setup = (m = setup_for_credit_market($base_model)) evals = 1

# Benchmark 2: Labor Market (runs immediately after Credit)
# We can just use the credit setup, but run credit inside the setup inline
SUITE["labor_market"] = @benchmarkable BeforeIT.search_and_matching_labor!(m.world) setup = begin
    m = setup_for_credit_market($base_model)
    BeforeIT.search_and_matching_credit!(m.world)
end evals = 1

SUITE["step"] = @benchmarkable BeforeIT.step!(model) setup = (deepcopy($base_model))
