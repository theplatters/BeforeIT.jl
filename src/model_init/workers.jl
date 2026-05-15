function setup_workers!(world::Ark.World, properties::Properties)
    (; active, inactive, total) = properties.population
    unemployment_benefit_rate = properties.social_insurance.unemployment_benefit
    (; subsidies_other, subsidies_inactive) = properties.initial_conditions.government
    (; debt, capital, unemployment_benefit) = properties.initial_conditions.households

    total_firms = properties.dimensions.total_firms

    employable = active - total_firms - 1

    Ark.new_entities!(
        world, employable, (
            NetDisposableIncome(0.0),
            Deposits(0.0),
            ExpectedIncome(0.0),
            CapitalStock(0.0),
            Unemployed(unemployment_benefit / unemployment_benefit_rate),
            ConsumptionBudget(0.0),
            InvestmentBudget(0.0),
            RealisedConsumption(0.0),
            RealisedInvestment(0.0),
            Household(),
        )
    )

    disposable_income = subsidies_other + subsidies_inactive
    Ark.new_entities!(
        world, inactive, (
            NetDisposableIncome(disposable_income),
            Deposits(debt * disposable_income),
            ExpectedIncome(0.0),
            CapitalStock(capital * disposable_income),
            Inactive(),
            ConsumptionBudget(0.0),
            InvestmentBudget(0.0),
            RealisedConsumption(0.0),
            RealisedInvestment(0.0),
            Household(),
        )
    )

    return nothing
end
