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
        employed = _query_count(world, Bit.Components.Employed, with = (Bit.Components.Household,)),
        unemployed = _query_count(world, Bit.Components.Unemployed, with = (Bit.Components.Household,)),
        inactive = _query_count(world, Bit.Components.Inactive, with = (Bit.Components.Household,)),
        firms = _query_count(world, Bit.Components.Firm),
        household_income = _query_sum(world, Bit.Components.NetDisposableIncome, with = (Bit.Components.Household,)),
        household_deposits = _query_sum(world, Bit.Components.Deposits, with = (Bit.Components.Household,)),
        household_consumption = _query_sum(world, Bit.Components.RealisedConsumption, with = (Bit.Components.Household,)),
        household_investment = _query_sum(world, Bit.Components.RealisedInvestment, with = (Bit.Components.Household,)),
        firm_output = _query_sum(world, Bit.Components.Output, with = (Bit.Components.Firm,)),
        firm_sales = _query_sum(world, Bit.Components.Sales, with = (Bit.Components.Firm,)),
        firm_goods_demand = _query_sum(world, Bit.Components.GoodsDemand, with = (Bit.Components.Firm,)),
        firm_investment = _query_sum(world, Bit.Components.Investment, with = (Bit.Components.Firm,)),
        firm_intermediates = _query_sum(world, Bit.Components.Intermediates, with = (Bit.Components.Firm,)),
        firm_deposits = _query_sum(world, Bit.Components.Deposits, with = (Bit.Components.Firm,)),
        firm_loans = _query_sum(world, Bit.Components.LoansOutstanding, with = (Bit.Components.Firm,)),
        firm_equity = _query_sum(world, Bit.Components.Equity, with = (Bit.Components.Firm,)),
        firm_profits = _query_sum(world, Bit.Components.Profits, with = (Bit.Components.Firm,)),
        bank_equity = _query_sum(world, Bit.Components.Equity, with = (Bit.Components.Bank,)),
        bank_residual = _query_sum(world, Bit.Components.ResidualItems, with = (Bit.Components.Bank,)),
        bank_rate = _query_sum(world, Bit.Components.LendingRate, with = (Bit.Components.Bank,), field = :rate),
        bank_profits = _query_sum(world, Bit.Components.Profits, with = (Bit.Components.Bank,)),
        government_debt = _query_sum(world, Bit.Components.GovernmentDebt, with = (Bit.Components.Government,)),
        government_revenues = _query_sum(world, Bit.Components.GovernmentRevenues, with = (Bit.Components.Government,)),
        government_consumption = _query_sum(world, Bit.Components.ConsumptionDemand, with = (Bit.Components.Government,)),
        government_price = _query_sum(world, Bit.Components.PriceInflationGovernmentGoods, with = (Bit.Components.Government,), field = :value),
        central_bank_equity = _query_sum(world, Bit.Components.Equity, with = (Bit.Components.CentralBank,)),
        central_bank_rate = _query_sum(world, Bit.Components.NominalInterestRate, with = (Bit.Components.CentralBank,), field = :rate),
        row_net_foreign_position = _query_sum(world, Bit.Components.NetForeignPosition, field = :amount),
        row_gdp = _query_sum(world, Bit.Components.EuroAreaGDP, field = :value),
        row_growth = _query_sum(world, Bit.Components.EuroAreaGrowth, field = :rate),
        row_inflation = _query_sum(world, Bit.Components.EuroAreaInflation, field = :rate),
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
