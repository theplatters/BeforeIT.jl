function set_growth_inflation_expectations!(world::Ark.World)
    macro_state = Ark.get_resource(world, MacroeconomicState)
    properties = BeforeIT.properties(world)
    expectations = BeforeIT.expectations(world)
    interval = properties.dimensions.interval_for_expectation_estimation
    time = Ark.get_resource(world, TimeIndex).step

    (; gross_domestic_product_history, inflation_history) = macro_state


    expected_gdp = estimate_next_value(log.(gross_domestic_product_history[1:(interval + time - 1)])) |> exp
    expected_growth = expected_gdp / gross_domestic_product_history[interval + time - 1] - 1.0
    expected_inflation = exp(estimate_next_value(inflation_history[1:(interval + time - 1)])) - 1.0

    expectations.gross_domestic_product = expected_gdp
    expectations.output_growth = expected_growth
    expectations.inflation = expected_inflation


    return nothing
end

function set_growth_inflation_EA!(world::Ark.World)
    epsilon_Y_EA = Ark.get_resource(world, Epsilons).Y_EA
    (;
        inflation_shock_sd,
        output_autoregression,
        inflation_response_to_output_gap,
        inflation_autoregression, output_autoregression_scalar,
    ) = Ark.get_resource(world, Properties).external_params

    random_inflation_shock = inflation_shock_sd * randn()


    @dub for t in Ark.Query(world, (EuroAreaGDP, EuroAreaGrowth, EuroAreaInflation))
        @inbounds for i in eachindex(t.e)
            expected_growth = exp(
                output_autoregression * log(t.euro_area_gdp[i].value) +
                    output_autoregression_scalar +
                    epsilon_Y_EA
            )
            t.euro_area_growth[i] = expected_growth / t.euro_area_gdp[i].value - 1 |> EuroAreaGrowth
            t.euro_area_gdp[i] = expected_growth |> EuroAreaGDP
            t.euro_area_inflation[i] = (
                exp(
                    inflation_autoregression * log1p(t.euro_area_inflation[i].rate) +
                        inflation_response_to_output_gap +
                        random_inflation_shock
                ) - 1
            ) |> EuroAreaInflation
        end
    end


    return nothing
end

function set_inflation_priceindex!(world::Ark.World)
    macro_state = Ark.get_resource(world, MacroeconomicState)
    price_indices = Ark.get_resource(world, PriceIndices)
    properties = Ark.get_resource(world, Properties)

    interval = properties.dimensions.interval_for_expectation_estimation
    time = Ark.get_resource(world, TimeIndex).step

    total_monetary_output_value = 0.0
    total_output = 0.0
    @dub for t in Ark.Query(world, (Price, Output))
        for i in eachindex(t.e)
            total_monetary_output_value += t.price[i].value * t.output[i].amount
            total_output += t.output[i].amount
        end
    end
    price_index = total_monetary_output_value / total_output

    inflation = log(price_index / price_indices.aggregate)
    price_indices.aggregate = price_index
    push!(macro_state.inflation_history, 0.0)
    macro_state.inflation_history[interval + time] = inflation

    return nothing
end

function set_sector_specific_priceindex!(world::Ark.World)
    price_indices = Ark.get_resource(world, PriceIndices)
    fill!(price_indices.sector, 0.0)
    total_sales = zeros(size(price_indices.sector))

    @dub for t in Ark.Query(world, (PrincipalProduct, Price, Sales))
        @inbounds for i in eachindex(t.e)
            price_indices.sector[t.principal_product[i].id] += t.price[i].value * t.sales[i].amount
            total_sales[t.principal_product[i].id] += t.sales[i].amount
        end
    end

    @dub for t in Ark.Query(world, (PrincipalProduct, ImportPrice, ImportSales))
        @inbounds for i in eachindex(t.e)
            price_indices.sector[t.principal_product[i].id] += t.import_price[i].value * t.import_sales[i].amount
            total_sales[t.principal_product[i].id] += t.import_sales[i].amount
        end
    end

    price_indices.sector ./= total_sales
    return nothing
end

function set_capital_formation_priceindex!(world::Ark.World)
    price_indices = BeforeIT.price_indices(world)
    properties = BeforeIT.properties(world)
    price_indices.capital_goods = LinearAlgebra.dot(properties.product_coeffs.capital_formation, price_indices.sector)
    return nothing
end

function set_households_priceindex!(world::Ark.World)
    price_indices = BeforeIT.price_indices(world)
    properties = BeforeIT.properties(world)

    price_indices.household_consumption = LinearAlgebra.dot(properties.product_coeffs.household_consumption, price_indices.sector)
    return nothing

end
