using BenchmarkTools
using Chairmarks
using BeforeIT
using Random

Random.seed!(42)

const SUITE = BenchmarkGroup()

# Systems in order as they appear in step!
const SYSTEMS = (
    BeforeIT.finance_insolvent_firms!,
    BeforeIT.set_growth_inflation_expectations!,
    BeforeIT.set_epsilon!,
    BeforeIT.set_growth_inflation_EA!,
    BeforeIT.set_central_bank_rate!,
    BeforeIT.set_bank_rate!,
    BeforeIT.set_firms_expectations_and_decisions!,
    BeforeIT.search_and_matching_credit!,
    BeforeIT.search_and_matching_labor!,
    BeforeIT.set_firms_wages!,
    BeforeIT.set_firms_production!,
    BeforeIT.update_workers_wages!,
    BeforeIT.set_gov_social_benefits!,
    BeforeIT.set_bank_expected_profits!,
    BeforeIT.set_households_expected_income!,
    BeforeIT.set_households_budget!,
    BeforeIT.set_gov_expenditure!,
    BeforeIT.set_rotw_import_export!,
    BeforeIT.search_and_matching!,
    BeforeIT.set_inflation_priceindex!,
    BeforeIT.set_sector_specific_priceindex!,
    BeforeIT.set_capital_formation_priceindex!,
    BeforeIT.set_households_priceindex!,
    BeforeIT.set_firms_stocks!,
    BeforeIT.set_firms_profits!,
    BeforeIT.set_bank_profits!,
    BeforeIT.set_bank_equity!,
    BeforeIT.set_households_income!,
    BeforeIT.set_households_deposit!,
    BeforeIT.set_central_bank_equity!,
    BeforeIT.set_gov_revenues!,
    BeforeIT.set_gov_loans!,
    BeforeIT.set_firms_deposits!,
    BeforeIT.set_firms_loans!,
    BeforeIT.set_firms_equity!,
    BeforeIT.set_rotw_deposits!,
    BeforeIT.set_bank_deposits!,
    BeforeIT.set_gross_domestic_product!,
    BeforeIT.set_time!,
)

function setup_to_system(n)
    m = BeforeIT.AUSTRIA2010Q1 |> BeforeIT.ECSModel
    world = m.world
    for i in 1:(n - 1)
        if SYSTEMS[i] == BeforeIT.search_and_matching!
            SYSTEMS[i](world; parallel = false)
        else
            SYSTEMS[i](world)
        end
    end
    return world
end

setup_for_step() = BeforeIT.AUSTRIA2010Q1 |> BeforeIT.ECSModel

SUITE["step"] = @be setup_for_step() BeforeIT.step!(_) evals = 1 seconds = 10

# Include all individual system benchmarks
for (i, sys) in enumerate(SYSTEMS)
    name = string(sys)
    # Remove "BeforeIT." if present
    name = replace(name, "BeforeIT." => "")
    # Remove "!" if present
    name = replace(name, "!" => "")

    SUITE[name] = @be setup_to_system($i) SYSTEMS[$i](_) evals = 1 seconds = 5
end
