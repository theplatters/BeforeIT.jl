function setup_bank!(world::Ark.World, properties::Properties)
    (; equity_ratio, policy_rate) = properties.initial_conditions.banking
    risk_premium = properties.banking_params.risk_premium
    total_loans = 0.0
    for (_, loans) in Ark.Query(world, (Components.LoansOutstanding,), with = (Components.Firm,))
        total_loans += sum(loans.amount)
    end
    initial_profits = risk_premium * total_loans + policy_rate * equity_ratio

    owner = Ark.new_entity!(
        world,
        (
            Components.NetDisposableIncome(0.0),
            Components.ConsumptionBudget(0.0),
            Components.ExpectedIncome(0.0),
            Components.InvestmentBudget(0.0),
            Components.RealisedConsumption(0.0),
            Components.RealisedInvestment(0.0),
            Components.CapitalStock(0.0),
            Components.Deposits(0.0),
            Components.Banker(),
            Components.Household(),
        )
    )
    Ark.new_entity!(
        world, (
            Components.Equity(equity_ratio),
            Components.ResidualItems(0.0),
            Components.Profits(initial_profits),
            Components.ExpectedProfits(initial_profits),
            Components.LendingRate(policy_rate + risk_premium),
            Components.Owner() => owner,
            Components.Bank(),
        )
    )

    return nothing

end

function setup_central_bank!(world::Ark.World, properties::Properties)
    (; central_bank_equity, policy_rate) = properties.initial_conditions.banking
    return Ark.new_entity!(
        world, (
            Components.Equity(central_bank_equity),
            Components.NominalInterestRate(policy_rate),
            Components.CentralBank(),
        )
    )
end
