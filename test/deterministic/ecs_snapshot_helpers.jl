function _query_sum(world, component_type::Type; with = (), field::Symbol = :amount)
    total = 0.0
    for (entities, values) in Bit.Ark.Query(world, (component_type,), with = with)
        for i in eachindex(entities)
            total += getfield(values[i], field)
        end
    end
    return total
end

function _query_count(world, component_type::Type; with = ())
    total = 0
    for (entities, _) in Bit.Ark.Query(world, (component_type,), with = with)
        total += length(entities)
    end
    return total
end

function _state_signature(model)
    world = model.world
    expectations = Bit.Ark.get_resource(world, Bit.Expectations)
    macro_state = Bit.Ark.get_resource(world, Bit.MacroeconomicState)
    price_indices = Bit.Ark.get_resource(world, Bit.PriceIndices)

    return (
        employed = _query_count(world, Bit.Employed, with = (Bit.Household,)),
        unemployed = _query_count(world, Bit.Unemployed, with = (Bit.Household,)),
        inactive = _query_count(world, Bit.Inactive, with = (Bit.Household,)),
        firms = _query_count(world, Bit.Firm),
        household_income = _query_sum(world, Bit.NetDisposableIncome, with = (Bit.Household,)),
        household_deposits = _query_sum(world, Bit.Deposits, with = (Bit.Household,)),
        household_consumption = _query_sum(world, Bit.RealisedConsumption, with = (Bit.Household,)),
        household_investment = _query_sum(world, Bit.RealisedInvestment, with = (Bit.Household,)),
        firm_output = _query_sum(world, Bit.Output, with = (Bit.Firm,)),
        firm_sales = _query_sum(world, Bit.Sales, with = (Bit.Firm,)),
        firm_goods_demand = _query_sum(world, Bit.GoodsDemand, with = (Bit.Firm,)),
        firm_investment = _query_sum(world, Bit.Investment, with = (Bit.Firm,)),
        firm_intermediates = _query_sum(world, Bit.Intermediates, with = (Bit.Firm,)),
        firm_deposits = _query_sum(world, Bit.Deposits, with = (Bit.Firm,)),
        firm_loans = _query_sum(world, Bit.LoansOutstanding, with = (Bit.Firm,)),
        firm_equity = _query_sum(world, Bit.Equity, with = (Bit.Firm,)),
        firm_profits = _query_sum(world, Bit.Profits, with = (Bit.Firm,)),
        bank_equity = _query_sum(world, Bit.Equity, with = (Bit.Bank,)),
        bank_residual = _query_sum(world, Bit.ResidualItems, with = (Bit.Bank,)),
        bank_rate = _query_sum(world, Bit.LendingRate, with = (Bit.Bank,), field = :rate),
        bank_profits = _query_sum(world, Bit.Profits, with = (Bit.Bank,)),
        government_debt = _query_sum(world, Bit.GovernmentDebt, with = (Bit.Government,)),
        government_revenues = _query_sum(world, Bit.GovernmentRevenues, with = (Bit.Government,)),
        government_consumption = _query_sum(world, Bit.ConsumptionDemand, with = (Bit.Government,)),
        government_price = _query_sum(world, Bit.PriceInflationGovernmentGoods, with = (Bit.Government,), field = :value),
        central_bank_equity = _query_sum(world, Bit.Equity, with = (Bit.CentralBank,)),
        central_bank_rate = _query_sum(world, Bit.NominalInterestRate, with = (Bit.CentralBank,), field = :rate),
        row_net_foreign_position = _query_sum(world, Bit.NetForeignPosition, field = :amount),
        row_gdp = _query_sum(world, Bit.EuroAreaGDP, field = :value),
        row_growth = _query_sum(world, Bit.EuroAreaGrowth, field = :rate),
        row_inflation = _query_sum(world, Bit.EuroAreaInflation, field = :rate),
        expected_gdp = expectations.gross_domestic_product,
        expected_growth = expectations.output_growth,
        expected_inflation = expectations.inflation,
        macro_gdp = macro_state.gross_domestic_product_history[end],
        macro_inflation = macro_state.inflation_history[end],
        aggregate_price = price_indices.aggregate,
        household_price = price_indices.household_consumption,
        capital_goods_price = price_indices.capital_goods,
    )
end

function _assert_approx_signature(lhs, rhs; rtol = 1.0e-8, atol = 1.0e-8)
    for key in keys(lhs)
        left = lhs[key]
        right = rhs[key]
        if left isa Integer
            @test left == right
        else
            @test isapprox(left, right; rtol, atol)
        end
    end
    return
end

function _assert_approx_collector(lhs, rhs; rtol = 1.0e-8, atol = 1.0e-8)
    for field in fieldnames(typeof(lhs))
        @test isapprox(getfield(lhs, field), getfield(rhs, field); rtol, atol)
    end
    return
end
