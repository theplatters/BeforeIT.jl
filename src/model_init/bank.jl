function setup_bank!(world::Ark.World, properties::Properties)
    (; equity_ratio, policy_rate) = properties.initial_conditions.banking
    risk_premium = properties.banking_params.risk_premium
    total_loans = 0.0
    for (_, loans) in Ark.Query(world, (LoansOutstanding,), with = (Firm,))
        total_loans += sum(loans.amount)
    end
    initial_profits = risk_premium * total_loans + policy_rate * equity_ratio

    owner = Ark.new_entity!(
        world,
        (
            NetDisposableIncome(0.0),
            ConsumptionBudget(0.0),
            ExpectedIncome(0.0),
            InvestmentBudget(0.0),
            RealisedConsumption(0.0),
            RealisedInvestment(0.0),
            CapitalStock(0.0),
            Deposits(0.0),
            Banker(),
            Household(),
        )
    )
    Ark.new_entity!(
        world, (
            Equity(equity_ratio),
            ResidualItems(0.0),
            Profits(initial_profits),
            ExpectedProfits(initial_profits),
            LendingRate(policy_rate + risk_premium),
            Owner() => owner,
            Bank(),
        )
    )

    return nothing

end

function setup_central_bank!(world::Ark.World, properties::Properties)
    (; central_bank_equity, policy_rate) = properties.initial_conditions.banking
    return Ark.new_entity!(
        world, (
            Equity(central_bank_equity),
            NominalInterestRate(policy_rate),
            CentralBank(),
        )
    )
end
