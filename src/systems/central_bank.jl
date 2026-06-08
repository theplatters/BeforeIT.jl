function taylor_rule(adjustment_rate, interest_rate, natural_rate, inflation_target, inflation_weight, growth_weigth, output_growth_rate, inflation_rate)
    rate = muladd(adjustment_rate, interest_rate, (1.0 - adjustment_rate) * (natural_rate + inflation_target + inflation_weight * (inflation_rate - inflation_target) + growth_weigth * output_growth_rate))
    return max(0.0, rate)
end

function set_central_bank_rate!(world)
    properties = Ark.get_resource(world, Properties)

    (; inflation_target, interest_rate_smoothing, response_to_inflation, response_to_output, natural_rate) = properties.monetary_policy

    e, growth, inflation = single(Ark.Query(world, (EuroAreaGrowth, EuroAreaInflation)))
    rotw_growth = growth.rate
    rotw_inflation = inflation.rate

    @dub for t in Ark.Query(world, (NominalInterestRate,), with = (CentralBank,))
        @inbounds for i in eachindex(t.e)
            t.nominal_interest_rate[i] = (
                taylor_rule(
                    interest_rate_smoothing, t.nominal_interest_rate[i].rate,
                    natural_rate, inflation_target, response_to_inflation,
                    response_to_output, rotw_growth, rotw_inflation,
                )
            ) |> NominalInterestRate
        end
    end

    return
end

function set_central_bank_equity!(world)
    properties = Ark.get_resource(world, Properties)
    government_interest_rate = properties.fiscal_policy.government_interest_rate
    total_government_debt = sum_amount(world, GovernmentDebt)
    total_banking_residuals = sum_amount(world, ResidualItems)

    @dub for t in Ark.Query(world, (Equity, NominalInterestRate), with = (CentralBank,))
        for i in eachindex(t.e)
            profits = government_interest_rate * total_government_debt -
                t.nominal_interest_rate[i].rate * total_banking_residuals
            t.equity[i] = (t.equity[i].amount + profits) |> Equity
        end
    end

    return nothing

end
