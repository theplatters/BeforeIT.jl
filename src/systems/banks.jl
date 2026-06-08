function set_bank_deposits!(world::Ark.World)
    total_deposits = sum_amount(world, Deposits)
    total_loans = sum_amount(world, LoansOutstanding)

    for comps in Ark.Query(world, (Equity, ResidualItems), with = (Bank,))
        row = query_row(comps)
        for i in eachindex(row.e)
            row.residual_items[i] = row.equity[i].amount - total_loans + total_deposits |> ResidualItems
        end
    end

    return nothing
end

function finance_insolvent_firms!(world::Ark.World)
    P_bar_CF = BeforeIT.price_indices(world).capital_goods
    ζ = BeforeIT.properties(world).banking_params.new_firm_loan_ratio

    financed_total_equity = 0.0
    for comps in Ark.Query(world, (LoansOutstanding, Equity, Deposits, CapitalStock))
        row = query_row(comps)
        for i in eachindex(row.e)
            (row.deposits[i].amount >= 0.0 || row.equity[i].amount >= 0) && continue
            loan = ζ * P_bar_CF * row.capital_stock[i].amount
            financed_equity = row.loans_outstanding[i].amount - row.deposits[i].amount - loan

            financed_total_equity += financed_equity
            row.equity[i] = row.equity[i].amount + financed_equity |> Equity
            row.loans_outstanding[i] = loan |> LoansOutstanding
            row.deposits[i] = 0.0 |> Deposits
        end
    end

    for comps in Ark.Query(world, (Equity,), with = (Bank,))
        row = query_row(comps)
        row.equity.amount .-= financed_total_equity
    end

    return nothing
end

function set_bank_expected_profits!(world)
    (; inflation, output_growth) = BeforeIT.expectations(world)

    for comps in Ark.Query(world, (ExpectedProfits, Profits), with = (LendingRate,))
        row = query_row(comps)
        row.expected_profits.amount .= row.profits.amount .* (1 + output_growth) .* (1 + inflation)
    end


    return nothing
end

function set_bank_rate!(world)
    cb_rate = 0.0
    for comps in Ark.Query(world, (NominalInterestRate,))
        row = query_row(comps)
        for i in eachindex(row.e)
            cb_rate = row.nominal_interest_rate[i].rate
        end
    end

    mu = Ark.get_resource(world, Properties).banking_params.risk_premium

    for comps in Ark.Query(world, (LendingRate,))
        row = query_row(comps)
        row.lending_rate.rate .= cb_rate + mu
    end

    return nothing
end

function set_bank_equity!(world::Ark.World)
    properties = BeforeIT.properties(world)
    dividend_payout_ratio = properties.banking_params.dividend_payout_ratio
    corporate_tax = properties.tax_rates.corporate

    total_taxed_and_dividend_ratio = (dividend_payout_ratio * (1 - corporate_tax) + corporate_tax)
    for comps in Ark.Query(world, (Equity, Profits), with = (Bank,))
        row = query_row(comps)
        row.equity.amount .= row.equity.amount .+
            row.profits.amount .-
            total_taxed_and_dividend_ratio .* max.(0, row.profits.amount)
    end

    return nothing
end

function set_bank_profits!(world)
    total_positive_deposits = sum_positive_amount(world, Deposits)
    total_negative_deposits = sum_negative_amount(world, Deposits)
    total_loans = sum_amount(world, LoansOutstanding)

    _, cb = single(Ark.Query(world, (NominalInterestRate,)))
    cb_rate = cb.rate

    rterm = total_loans + total_negative_deposits
    for comps in Ark.Query(world, (Profits, LendingRate, ResidualItems))
        row = query_row(comps)
        @inbounds for i in eachindex(row.e)
            central_bank_term = row.residual_items[i].amount - total_positive_deposits
            row.profits[i] = (
                row.lending_rate[i].rate * rterm + cb_rate * central_bank_term
            ) |> Profits
        end
    end

    return nothing
end
