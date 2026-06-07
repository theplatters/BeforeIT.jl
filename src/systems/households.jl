function update_workers_wages!(world::Ark.World)
    for (firm_e, wage_bill) in Ark.Query(world, (WageBill,))
        for i in eachindex(firm_e)
            for (_, employed) in Ark.Query(world, (Employed,), with = (EmployedAt => firm_e[i],))
                employed.rate .= wage_bill[i].amount
            end
        end
    end

    return nothing
end

function employed_worker_income(wage, τ_SIW, τ_INC, social_benefits_other, cpi, expected_inflation)
    after_tax_factor = 1.0 - τ_SIW - τ_INC * (1.0 - τ_SIW)
    return (wage * after_tax_factor + social_benefits_other) * cpi * (1.0 + expected_inflation)
end

function unemployed_worker_income(benefits, θ_UB, social_benefits_other, cpi, expected_inflation)
    return (θ_UB * benefits + social_benefits_other) * cpi * (1.0 + expected_inflation)
end

function inactive_worker_income(sb_inact, sb_other, cpi, expected_inflation)
    return (sb_inact + sb_other) * cpi * (1.0 + expected_inflation)
end

function firm_owner_disposable_income(θ_DIV, τ_INC, τ_FIRM, cpi, sb_other, expected_profits, expected_inflation)
    return θ_DIV * (1 - τ_INC) * (1 - τ_FIRM) * max(0, expected_profits) + sb_other * cpi * (1 + expected_inflation)
end


function set_households_income!(world::Ark.World)
    prop = properties(world)
    τ_INC = prop.tax_rates.income
    τ_SIW = prop.social_insurance.employees_contribution
    τ_FIRM = prop.tax_rates.corporate
    θ_DIV = prop.banking_params.dividend_payout_ratio


    θ_UB = prop.social_insurance.unemployment_benefit
    cpi = price_indices(world).household_consumption
    (_, sb_other, sb_inact) = single(Ark.Query(world, (SocialBenefitsOther, SocialBenefitsInactive)))

    for (e, employment, net_disposable_income) in Ark.Query(world, (Employed, NetDisposableIncome))
        for i in eachindex(e)
            net_disposable_income[i] = employed_worker_income(employment[i].rate, τ_SIW, τ_INC, sb_other.amount, cpi, 0.0) |> NetDisposableIncome
        end
    end

    for (e, unemployed, net_disposable_income) in Ark.Query(world, (Unemployed, NetDisposableIncome))
        for i in eachindex(e)
            net_disposable_income[i] = unemployed_worker_income(unemployed[i].unemployment_benefits, θ_UB, sb_other.amount, cpi, 0.0) |> NetDisposableIncome
        end
    end

    for (e, net_disposable_income) in Ark.Query(world, (NetDisposableIncome,), with = (Inactive,))
        for i in eachindex(e)
            net_disposable_income[i] = inactive_worker_income(sb_inact.amount, sb_other.amount, cpi, 0.0) |> NetDisposableIncome
        end
    end

    for (e, owner, profits) in Ark.Query(world, (Owner, Profits), with = (Firm,))
        for i in eachindex(e)
            new_income = firm_owner_disposable_income(θ_DIV, τ_INC, τ_FIRM, cpi, sb_other.amount, profits[i].amount, 0.0)
            Ark.set_components!(world, owner[i].entity, (NetDisposableIncome(new_income),))
        end
    end

    for (e, owner, profits) in Ark.Query(world, (Owner, Profits), with = (Bank,))
        for i in eachindex(e)
            new_income = firm_owner_disposable_income(θ_DIV, τ_INC, τ_FIRM, cpi, sb_other.amount, profits[i].amount, 0.0)
            Ark.set_components!(world, owner[i].entity, (NetDisposableIncome(new_income),))
        end
    end

    return nothing
end

function set_households_expected_income!(world::Ark.World)
    prop = properties(world)
    τ_INC = prop.tax_rates.income
    τ_SIW = prop.social_insurance.employees_contribution
    τ_FIRM = prop.tax_rates.corporate
    θ_DIV = prop.banking_params.dividend_payout_ratio


    θ_UB = prop.social_insurance.unemployment_benefit
    cpi = price_indices(world).household_consumption
    (_, sb_other, sb_inact) = single(Ark.Query(world, (SocialBenefitsOther, SocialBenefitsInactive)))

    expected_inflation = expectations(world).inflation

    for (e, employment, expected_income) in Ark.Query(world, (Employed, ExpectedIncome))
        for i in eachindex(e)
            expected_income[i] = employed_worker_income(employment[i].rate, τ_SIW, τ_INC, sb_other.amount, cpi, expected_inflation) |> ExpectedIncome
        end
    end

    for (e, unemployed, expected_income) in Ark.Query(world, (Unemployed, ExpectedIncome))
        for i in eachindex(e)
            expected_income[i] = unemployed_worker_income(unemployed[i].unemployment_benefits, θ_UB, sb_other.amount, cpi, expected_inflation) |> ExpectedIncome
        end
    end

    for (e, expected_income) in Ark.Query(world, (ExpectedIncome,), with = (Inactive,))
        for i in eachindex(e)
            expected_income[i] = inactive_worker_income(sb_inact.amount, sb_other.amount, cpi, expected_inflation) |> ExpectedIncome
        end
    end

    for (e, owner, expected_profits) in Ark.Query(world, (Owner, ExpectedProfits), with = (Firm,))
        for i in eachindex(e)
            new_expected_income = firm_owner_disposable_income(θ_DIV, τ_INC, τ_FIRM, cpi, sb_other.amount, expected_profits[i].amount, expected_inflation)
            Ark.set_components!(world, owner[i].entity, (ExpectedIncome(new_expected_income),))
        end
    end

    for (e, owner, expected_profits) in Ark.Query(world, (Owner, ExpectedProfits), with = (Bank,))
        for i in eachindex(e)
            new_expected_income = firm_owner_disposable_income(θ_DIV, τ_INC, τ_FIRM, cpi, sb_other.amount, expected_profits[i].amount, expected_inflation)
            Ark.set_components!(world, owner[i].entity, (ExpectedIncome(new_expected_income),))
        end
    end

    return nothing
end

function set_households_budget!(world::Ark.World)
    prop = properties(world)
    τ_VAT = prop.tax_rates.value_added
    τ_CF = prop.tax_rates.capital_formation

    ψ = prop.household_params.consumption_share
    ψₕ = prop.household_params.housing_investment_share

    for (_, expected_income, consumption_budget, investment_budget) in Ark.Query(world, (ExpectedIncome, ConsumptionBudget, InvestmentBudget))
        consumption_budget.amount .= ψ .* expected_income.amount ./ (1 + τ_VAT)
        investment_budget.amount .= ψₕ .* expected_income.amount ./ (1 + τ_CF)
    end

    return nothing
end

function set_households_deposit!(world::Ark.World)

    prop = properties(world)
    τ_VAT = prop.tax_rates.value_added
    τ_CF = prop.tax_rates.capital_formation

    _, r_bar = single(Ark.Query(world, (NominalInterestRate,)))
    _, r = single(Ark.Query(world, (LendingRate,)))

    for (e, net_disposable_income, realised_consumption, realised_investment, deposits) in Ark.Query(world, (NetDisposableIncome, RealisedConsumption, RealisedInvestment, Deposits))
        for i in eachindex(e)
            previous_deposits = deposits[i].amount
            updated_deposits = (
                previous_deposits
                    + net_disposable_income[i].amount
                    - (1 + τ_VAT) * realised_consumption[i].amount
                    - (1 + τ_CF) * realised_investment[i].amount
                    + r_bar.rate * max(0.0, previous_deposits)
                    + r.rate * min(0.0, previous_deposits)
            )
            deposits[i] = Deposits(updated_deposits)
        end
    end

    return nothing
end
