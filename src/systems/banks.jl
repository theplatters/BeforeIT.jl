function set_bank_deposits!(world::Ark.World)
    total_deposits = @sum_over (deposits.amount for deposits in Ark.Query(world, (Deposits,)))
    total_loans = @sum_over (loans.amount for loans in Ark.Query(world, (LoansOutstanding,)))

    for (e, equity, resisdual) in Ark.Query(world, (Equity, ResidualItems), with = (Bank,))
        for i in eachindex(e)
            resisdual[i] = ResidualItems(equity[i].amount - total_loans + total_deposits)
        end
    end

    return nothing
end

function finance_insolvent_firms!(world::Ark.World)
    P_bar_CF = BeforeIT.price_indices(world).capital_goods
    ζ = BeforeIT.properties(world).banking_params.new_firm_loan_ratio

    financed_total_equity = 0.0
    for (e, outstanding_loans, equity, deposits, capital) in Ark.Query(world, (LoansOutstanding, Equity, Deposits, CapitalStock))
        for i in eachindex(e)
            (deposits[i].amount >= 0.0 || equity[i].amount >= 0) && continue
            loan = ζ * P_bar_CF * capital[i].amount
            financed_equity = outstanding_loans[i].amount - deposits[i].amount - loan

            financed_total_equity += financed_equity
            equity[i] = Equity(equity[i].amount + financed_equity)
            outstanding_loans[i] = LoansOutstanding(loan)
            deposits[i] = Deposits(0.0)
        end
    end

    for (_, equity) in Ark.Query(world, (Equity,), with = (Bank,))
        equity.amount .-= financed_total_equity
    end

    return nothing
end

function set_bank_expected_profits!(world)
    (; inflation, output_growth) = BeforeIT.expectations(world)

    for (_, expected_profits, profits) in Ark.Query(world, (ExpectedProfits, Profits), with = (LendingRate,))
        expected_profits.amount .= profits.amount .* (1 + output_growth) .* (1 + inflation)
    end


    return nothing
end

function set_bank_rate!(world)
    cb_rate = 0.0
    for (e, cb) in Ark.Query(world, (NominalInterestRate,))
        for i in eachindex(e)
            cb_rate = cb[i].rate
        end
    end

    mu = Ark.get_resource(world, Properties).banking_params.risk_premium

    for (_, lending_rate) in Ark.Query(world, (LendingRate,))
        lending_rate.rate .= cb_rate + mu
    end

    return nothing
end

function set_bank_equity!(world::Ark.World)
    properties = BeforeIT.properties(world)
    dividend_payout_ratio = properties.banking_params.dividend_payout_ratio
    corporate_tax = properties.tax_rates.corporate

    total_taxed_and_dividend_ratio = (dividend_payout_ratio * (1 - corporate_tax) + corporate_tax)
    for (_, equity, profits) in Ark.Query(world, (Equity, Profits), with = (Bank,))
        equity.amount .= equity.amount .+ profits.amount .- total_taxed_and_dividend_ratio .* max.(0, profits.amount)
    end

    return nothing
end

function set_bank_profits!(world)
    total_positive_deposits = 0.0
    total_negative_deposits = 0.0
    for (e, deposits) in Ark.Query(world, (Deposits,))
        @inbounds for i in eachindex(e)
            total_positive_deposits += max(0.0, deposits[i].amount)
            total_negative_deposits += max(0.0, -deposits[i].amount)
        end
    end
    total_loans = @sum_over (loans.amount for loans in Ark.Query(world, (LoansOutstanding,)))

    (_, cb) = single(Ark.Query(world, (NominalInterestRate,)))
    cb_rate = cb.rate

    rterm = total_loans + total_negative_deposits
    for (e, profits, lending_rate, residual_item) in Ark.Query(world, (Profits, LendingRate, ResidualItems))
        @inbounds for i in eachindex(e)
            central_bank_term = residual_item[i].amount - total_positive_deposits
            profits[i] = Profits(
                lending_rate[i].rate * rterm + cb_rate * central_bank_term
            )
        end
    end

    return nothing
end
