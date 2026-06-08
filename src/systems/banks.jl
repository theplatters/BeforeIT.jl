function set_bank_deposits!(world::Ark.World)
    total_deposits = sum_amount(world, Deposits)
    total_loans = sum_amount(world, LoansOutstanding)

    for comps in Ark.Query(world, (Equity, ResidualItems), with = (Bank,))
        row = query_row(comps)
        e = row.e
        equity = row.equity
        residual = row.residual_items
        for i in eachindex(e)
            residual[i] = equity[i].amount - total_loans + total_deposits |> ResidualItems
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
        e = row.e
        outstanding_loans = row.loans_outstanding
        equity = row.equity
        deposits = row.deposits
        capital = row.capital_stock
        for i in eachindex(e)
            (deposits[i].amount >= 0.0 || equity[i].amount >= 0) && continue
            loan = ζ * P_bar_CF * capital[i].amount
            financed_equity = outstanding_loans[i].amount - deposits[i].amount - loan

            financed_total_equity += financed_equity
            equity[i] = equity[i].amount + financed_equity |> Equity
            outstanding_loans[i] = loan |> LoansOutstanding
            deposits[i] = 0.0 |> Deposits
        end
    end

    for comps in Ark.Query(world, (Equity,), with = (Bank,))
        row = query_row(comps)
        equity = row.equity
        equity.amount .-= financed_total_equity
    end

    return nothing
end

function set_bank_expected_profits!(world)
    (; inflation, output_growth) = BeforeIT.expectations(world)

    for comps in Ark.Query(world, (ExpectedProfits, Profits), with = (LendingRate,))
        row = query_row(comps)
        expected_profits = row.expected_profits
        profits = row.profits
        expected_profits.amount .= profits.amount .* (1 + output_growth) .* (1 + inflation)
    end


    return nothing
end

function set_bank_rate!(world)
    cb_rate = 0.0
    for comps in Ark.Query(world, (NominalInterestRate,))
        row = query_row(comps)
        e = row.e
        cb = row.nominal_interest_rate
        for i in eachindex(e)
            cb_rate = cb[i].rate
        end
    end

    mu = Ark.get_resource(world, Properties).banking_params.risk_premium

    for comps in Ark.Query(world, (LendingRate,))
        row = query_row(comps)
        lending_rate = row.lending_rate
        lending_rate.rate .= cb_rate + mu
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
        equity = row.equity
        profits = row.profits
        equity.amount .= equity.amount .+ profits.amount .- total_taxed_and_dividend_ratio .* max.(0, profits.amount)
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
        e = row.e
        profits = row.profits
        lending_rate = row.lending_rate
        residual_item = row.residual_items
        @inbounds for i in eachindex(e)
            central_bank_term = residual_item[i].amount - total_positive_deposits
            profits[i] = (
                lending_rate[i].rate * rterm + cb_rate * central_bank_term
            ) |> Profits
        end
    end

    return nothing
end
