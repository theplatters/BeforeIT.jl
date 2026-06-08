function set_bank_deposits!(world::Ark.World)
    total_deposits = sum_amount(world, Deposits)
    total_loans = sum_amount(world, LoansOutstanding)

    @dub for t in Ark.Query(world, (Equity, ResidualItems), with = (Bank,))
        for i in eachindex(t.e)
            t.residual_items[i] = t.equity[i].amount - total_loans + total_deposits |> ResidualItems
        end
    end

    return nothing
end

function finance_insolvent_firms!(world::Ark.World)
    P_bar_CF = BeforeIT.price_indices(world).capital_goods
    ζ = BeforeIT.properties(world).banking_params.new_firm_loan_ratio

    financed_total_equity = 0.0
    @dub for t in Ark.Query(world, (LoansOutstanding, Equity, Deposits, CapitalStock))
        for i in eachindex(t.e)
            (t.deposits[i].amount >= 0.0 || t.equity[i].amount >= 0) && continue
            loan = ζ * P_bar_CF * t.capital_stock[i].amount
            financed_equity = t.loans_outstanding[i].amount - t.deposits[i].amount - loan

            financed_total_equity += financed_equity
            t.equity[i] = t.equity[i].amount + financed_equity |> Equity
            t.loans_outstanding[i] = loan |> LoansOutstanding
            t.deposits[i] = 0.0 |> Deposits
        end
    end

    @dub for t in Ark.Query(world, (Equity,), with = (Bank,))
        t.equity.amount .-= financed_total_equity
    end

    return nothing
end

function set_bank_expected_profits!(world)
    (; inflation, output_growth) = BeforeIT.expectations(world)

    @dub for t in Ark.Query(world, (ExpectedProfits, Profits), with = (LendingRate,))
        t.expected_profits.amount .= t.profits.amount .* (1 + output_growth) .* (1 + inflation)
    end


    return nothing
end

function set_bank_rate!(world)
    cb_rate = 0.0
    @dub for t in Ark.Query(world, (NominalInterestRate,))
        for i in eachindex(t.e)
            cb_rate = t.nominal_interest_rate[i].rate
        end
    end

    mu = Ark.get_resource(world, Properties).banking_params.risk_premium

    @dub for t in Ark.Query(world, (LendingRate,))
        t.lending_rate.rate .= cb_rate + mu
    end

    return nothing
end

function set_bank_equity!(world::Ark.World)
    properties = BeforeIT.properties(world)
    dividend_payout_ratio = properties.banking_params.dividend_payout_ratio
    corporate_tax = properties.tax_rates.corporate

    total_taxed_and_dividend_ratio = (dividend_payout_ratio * (1 - corporate_tax) + corporate_tax)
    @dub for t in Ark.Query(world, (Equity, Profits), with = (Bank,))
        t.equity.amount .= t.equity.amount .+
            t.profits.amount .-
            total_taxed_and_dividend_ratio .* max.(0, t.profits.amount)
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
    @dub for t in Ark.Query(world, (Profits, LendingRate, ResidualItems))
        @inbounds for i in eachindex(t.e)
            central_bank_term = t.residual_items[i].amount - total_positive_deposits
            t.profits[i] = (
                t.lending_rate[i].rate * rterm + cb_rate * central_bank_term
            ) |> Profits
        end
    end

    return nothing
end
