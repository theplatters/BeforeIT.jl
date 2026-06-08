function setup_workers!(world::Ark.World, properties::Properties)
    (; active, inactive, total) = properties.population
    unemployment_benefit_rate = properties.social_insurance.unemployment_benefit
    (; subsidies_other, subsidies_inactive) = properties.initial_conditions.government
    (; debt, capital, unemployment_benefit) = properties.initial_conditions.households

    total_firms = properties.dimensions.total_firms

    employable = active - total_firms - 1

    Ark.new_entities!(
        world, employable, (
            NetDisposableIncome,
            Deposits,
            ExpectedIncome,
            CapitalStock,
            Unemployed,
            ConsumptionBudget,
            InvestmentBudget,
            RealisedConsumption,
            RealisedInvestment,
            Household,
            FinalDemandCacheIndex,
        )
    ) do (entities, income, deposits, expected_income, capital_stock, unemployed, consumption_budget, investment_budget, realised_consumption, realised_investment, household, final_cache_index)
        for i in eachindex(entities)
            income[i] = 0.0 |> NetDisposableIncome
            deposits[i] = 0.0 |> Deposits
            expected_income[i] = 0.0 |> ExpectedIncome
            capital_stock[i] = 0.0 |> CapitalStock
            unemployed[i] = unemployment_benefit / unemployment_benefit_rate |> Unemployed
            consumption_budget[i] = 0.0 |> ConsumptionBudget
            investment_budget[i] = 0.0 |> InvestmentBudget
            realised_consumption[i] = 0.0 |> RealisedConsumption
            realised_investment[i] = 0.0 |> RealisedInvestment
            household[i] = Household()
            final_cache_index[i] = i |> FinalDemandCacheIndex
        end
    end

    disposable_income = subsidies_other + subsidies_inactive
    Ark.new_entities!(
        world, inactive, (
            NetDisposableIncome,
            Deposits,
            ExpectedIncome,
            CapitalStock,
            Inactive,
            ConsumptionBudget,
            InvestmentBudget,
            RealisedConsumption,
            RealisedInvestment,
            Household,
            FinalDemandCacheIndex,
        )
    ) do (entities, income, deposits, expected_income, capital_stock, inactive_component, consumption_budget, investment_budget, realised_consumption, realised_investment, household, final_cache_index)
        for i in eachindex(entities)
            income[i] = disposable_income |> NetDisposableIncome
            deposits[i] = debt * disposable_income |> Deposits
            expected_income[i] = 0.0 |> ExpectedIncome
            capital_stock[i] = capital * disposable_income |> CapitalStock
            inactive_component[i] = Inactive()
            consumption_budget[i] = 0.0 |> ConsumptionBudget
            investment_budget[i] = 0.0 |> InvestmentBudget
            realised_consumption[i] = 0.0 |> RealisedConsumption
            realised_investment[i] = 0.0 |> RealisedInvestment
            household[i] = Household()
            final_cache_index[i] = employable + i |> FinalDemandCacheIndex
        end
    end

    return nothing
end
