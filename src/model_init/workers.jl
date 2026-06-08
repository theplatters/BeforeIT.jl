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
            income[i] = NetDisposableIncome(0.0)
            deposits[i] = Deposits(0.0)
            expected_income[i] = ExpectedIncome(0.0)
            capital_stock[i] = CapitalStock(0.0)
            unemployed[i] = Unemployed(unemployment_benefit / unemployment_benefit_rate)
            consumption_budget[i] = ConsumptionBudget(0.0)
            investment_budget[i] = InvestmentBudget(0.0)
            realised_consumption[i] = RealisedConsumption(0.0)
            realised_investment[i] = RealisedInvestment(0.0)
            household[i] = Household()
            final_cache_index[i] = FinalDemandCacheIndex(i)
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
            income[i] = NetDisposableIncome(disposable_income)
            deposits[i] = Deposits(debt * disposable_income)
            expected_income[i] = ExpectedIncome(0.0)
            capital_stock[i] = CapitalStock(capital * disposable_income)
            inactive_component[i] = Inactive()
            consumption_budget[i] = ConsumptionBudget(0.0)
            investment_budget[i] = InvestmentBudget(0.0)
            realised_consumption[i] = RealisedConsumption(0.0)
            realised_investment[i] = RealisedInvestment(0.0)
            household[i] = Household()
            final_cache_index[i] = FinalDemandCacheIndex(employable + i)
        end
    end

    return nothing
end
