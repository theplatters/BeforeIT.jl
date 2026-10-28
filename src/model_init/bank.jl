function setup_banks!(world::Ark.World, properties::Properties)
    (; equity_ratio, policy_rate) = properties.initial_conditions.banking
    risk_premium = properties.banking_params.risk_premium
    n_banks = properties.population.banks

    # owners are attached in setup_bankers!, profits in initialize_bank_profits!
    return [
        Ark.new_entity!(
                world, (
                    Equity(equity_ratio / n_banks), ResidualItems(0.0), Profits(0.0),
                    ExpectedProfits(0.0), LendingRate(policy_rate + risk_premium),
                    Owner(Ark.zero_entity), Bank(),
                )
            ) for _ in 1:n_banks
    ]
end

function setup_bankers!(world::Ark.World, properties::Properties, banks::Vector{Ark.Entity})
    total = properties.population.total
    n_banks = properties.population.banks

    for (b, bank) in enumerate(banks)
        owner = Ark.new_entity!(
            world,
            (
                NetDisposableIncome(0.0), ConsumptionBudget(0.0), ExpectedIncome(0.0),
                InvestmentBudget(0.0), RealisedConsumption(0.0), RealisedInvestment(0.0),
                CapitalStock(0.0), Deposits(0.0), Banker(), Household(),
                FinalDemandCacheIndex(total - n_banks + b), BankAccount() => bank,
            )
        )
        Ark.set_components!(world, bank, (Owner(owner),))
    end

    return nothing
end

"""
    assign_bank_accounts!(world, properties)

Randomly assign firms (together with their owners), then unemployed and inactive
households to banks. The assignment is sticky for the whole simulation. With a
single bank every entity already points to it and no random numbers are drawn.
"""
function assign_bank_accounts!(world::Ark.World, properties::Properties)
    n_banks = properties.population.banks
    n_banks == 1 && return nothing

    banks = bank_entities(world)

    firms = Tuple{Ark.Entity, Ark.Entity}[]
    @dub for t in Ark.Query(world, (Owner,), with = (Firm,))
        for i in eachindex(t.e)
            push!(firms, (t.e[i], t.owner[i].entity))
        end
    end
    for (firm, owner) in firms
        bank = banks[rand(1:n_banks)]
        Ark.set_relations!(world, firm, (BankAccount => bank,))
        Ark.set_relations!(world, owner, (BankAccount => bank,))
    end

    for status in (Unemployed, Inactive)
        households = Ark.Entity[]
        @dub for t in Ark.Query(world, (), with = (status,))
            append!(households, t.e)
        end
        for household in households
            Ark.set_relations!(world, household, (BankAccount => banks[rand(1:n_banks)],))
        end
    end

    return nothing
end

function initialize_bank_profits!(world::Ark.World, properties::Properties)
    policy_rate = properties.initial_conditions.banking.policy_rate
    risk_premium = properties.banking_params.risk_premium

    @dub for t in Ark.Query(world, (Equity, Profits, ExpectedProfits), with = (Bank,))
        for i in eachindex(t.e)
            loans = sum_amount(world, LoansOutstanding, with = (Firm, BankAccount => t.e[i]))
            profits = risk_premium * loans + policy_rate * t.equity[i].amount
            t.profits[i] = Profits(profits)
            t.expected_profits[i] = ExpectedProfits(profits)
        end
    end

    return nothing
end

function bank_entities(world::Ark.World)
    banks = Ark.Entity[]
    @dub for t in Ark.Query(world, (), with = (Bank,))
        append!(banks, t.e)
    end
    return banks
end

function setup_central_bank!(world::Ark.World, properties::Properties)
    (; central_bank_equity, policy_rate) = properties.initial_conditions.banking
    return Ark.new_entity!(
        world, (
            Equity(central_bank_equity), NominalInterestRate(policy_rate), CentralBank(),
        )
    )
end
