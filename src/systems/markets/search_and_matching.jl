function search_and_matching!(world::Ark.World; parallel = false)
    build_intermediate_demand!(world)
    build_consumption_demand!(world)
    build_stock_pool!(world)
    zero_out_components_for_search_and_match!(world)
    perform_search_and_matching!(world; parallel)
    update_search_and_match_realisations!(world)
    finalize_search_and_match!(world)
    return nothing
end

function perform_search_and_matching!(world::Ark.World; parallel = false)
    realisation_cache = Ark.get_resource(world, RetailRealisationCache)
    properties = BeforeIT.properties(world)
    @dub for row in Ark.Query(            world,
            (
                PrincipalProduct,
                IntermediateMarketDemandBook,
                IntermediateMarketDemandClearing,
                FinalMarketDemandBook,
                FinalMarketDemandClearing,
                MarketSupplyPool,
                MarketCapacityPool,
                MarketPricePool,
                FirstPassIntermediateDemand,
                FirstPassFinalDemand,
                MarketWeights,
                MarketWeightVector,
                ActiveBuyers,
            )
        )
        @maybe_threads parallel for i in eachindex(row.e)
            perform_firm_market!(
                row.market_supply_pool[i].amount,
                row.market_capacity_pool[i].amount,
                row.market_price_pool[i].value,
                row.intermediate_market_demand_book[i].amount,
                row.intermediate_market_demand_clearing[i].amount,
                row.first_pass_intermediate_demand[i].amount,
                row.active_buyers[i].ids,
                row.market_weights[i].value,
                row.market_weight_vector[i].value
            )

            perform_retail_market!(
                row.market_supply_pool[i].amount,
                row.market_capacity_pool[i].amount,
                row.market_price_pool[i].value,
                row.final_market_demand_book[i].amount,
                row.final_market_demand_clearing[i].amount,
                row.first_pass_final_demand[i].amount,
                row.active_buyers[i].ids,
                row.market_weights[i].value,
                row.market_weight_vector[i].value
            )

            stage_retail_realisations!(
                properties,
                row.principal_product[i].id,
                row.first_pass_final_demand[i].amount,
                row.final_market_demand_book[i].amount,
                row.final_market_demand_clearing[i].amount,
                realisation_cache,
            )
        end
    end


    return nothing
end

function build_intermediate_demand!(world::Ark.World)

    (; technology_matrix, capital_formation) = BeforeIT.properties(world).product_coeffs

    @dub for market_row in Ark.Query(world, (PrincipalProduct, IntermediateMarketDemandBook, IntermediateMarketDemandClearing))        @inbounds for j in eachindex(market_row.e)
            g = market_row.principal_product[j].id
            market_book_amount = market_row.intermediate_market_demand_book[j].amount
            market_clearing_amount = market_row.intermediate_market_demand_clearing[j].amount
            @dub for buyer_row in Ark.Query(                    world,
                    (PrincipalProduct, DesiredInvestment, DesiredMaterials, IntermediaryDemandCacheIndex)
                )
                for i in eachindex(buyer_row.e)
                    demand_pos = buyer_row.intermediary_demand_cache_index[i].id
                    product_id = buyer_row.principal_product[i].id
                    desired_materials_amount = buyer_row.desired_materials[i].amount
                    desired_investment_amount = buyer_row.desired_investment[i].amount
                    market_book_amount[demand_pos] =
                        technology_matrix[g, product_id] * desired_materials_amount +
                        capital_formation[g] * desired_investment_amount
                    market_clearing_amount[demand_pos] = 0.0
                end
            end
        end
    end
    return nothing
end

function build_consumption_demand!(world::Ark.World)

    properties = BeforeIT.properties(world)
    coeffs = properties.product_coeffs
    (; household_consumption, household_investment) = coeffs
    realisation_cache = Ark.get_resource(world, RetailRealisationCache)
    total_households = properties.population.total
    foreign_consumers = properties.dimensions.foreign_consumers
    local_governments = properties.dimensions.local_governments

    stage_household_consumption_budgets!(world, realisation_cache)
    stage_final_demand_amount!(world, realisation_cache, ForeignConsumptionDemand)
    stage_final_demand_amount!(
        world,
        realisation_cache,
        ConsumptionDemand,
        with = (LocalGovernment,),
    )

    fill_household_consumption_market_books!(
        world,
        realisation_cache,
        household_consumption,
        household_investment,
        total_households,
    )

    fill_scaled_final_demand_market_books!(
        world,
        realisation_cache,
        coeffs.exports,
        (total_households + 1):(total_households + foreign_consumers),
    )
    fill_scaled_final_demand_market_books!(
        world,
        realisation_cache,
        coeffs.government_consumption,
        (total_households + foreign_consumers + 1):(total_households + foreign_consumers + local_governments),
    )

    return nothing
end

@inline function stage_household_consumption_budgets!(
        world::Ark.World,
        realisation_cache,
    )
    @dub for row in Ark.Query(            world,
            (ConsumptionBudget, InvestmentBudget, FinalDemandCacheIndex),
            with = (Household,),
        )
        @inbounds for i in eachindex(row.e)
            cache_pos = row.final_demand_cache_index[i].id
            realisation_cache.consumption_budget[cache_pos] = row.consumption_budget[i].amount
            realisation_cache.investment_budget[cache_pos] = row.investment_budget[i].amount
        end
    end

    return nothing
end

@inline function fill_household_consumption_market_books!(
        world::Ark.World,
        realisation_cache,
        household_consumption,
        household_investment,
        total_households,
    )
    consumption_budget = realisation_cache.consumption_budget
    investment_budget = realisation_cache.investment_budget

    @dub for row in Ark.Query(world, (PrincipalProduct, FinalMarketDemandBook, FinalMarketDemandClearing))        @inbounds for j in eachindex(row.e)
            g = row.principal_product[j].id
            market_book_amount = row.final_market_demand_book[j].amount
            market_clearing_amount = row.final_market_demand_clearing[j].amount
            household_consumption_coeff = household_consumption[g]
            household_investment_coeff = household_investment[g]
            for row in 1:total_households
                market_book_amount[row] =
                    household_consumption_coeff * consumption_budget[row] +
                    household_investment_coeff * investment_budget[row]
                market_clearing_amount[row] = 0.0
            end
        end
    end

    return nothing
end

@inline function stage_final_demand_amount!(
        world::Ark.World,
        realisation_cache,
        ::Type{DemandType},
        ;
        with = (),
    ) where {DemandType}
    @dub for row in Ark.Query(world, (DemandType, FinalDemandCacheIndex), with = with)        demand = query_component(row, DemandType)

        @inbounds for i in eachindex(row.e)
            cache_pos = row.final_demand_cache_index[i].id
            final_demand_pos = cache_pos - length(realisation_cache.consumption_budget)
            realisation_cache.final_demand_amount[final_demand_pos] = demand[i].amount
        end
    end

    return nothing
end

@inline function fill_scaled_final_demand_market_books!(
        world::Ark.World,
        realisation_cache,
        demand_coefficients,
        demand_rows,
    )
    final_demand_offset = length(realisation_cache.consumption_budget)
    final_demand_amount = realisation_cache.final_demand_amount

    @dub for row in Ark.Query(world, (PrincipalProduct, FinalMarketDemandBook, FinalMarketDemandClearing))        @inbounds for j in eachindex(row.e)
            g = row.principal_product[j].id
            market_book_amount = row.final_market_demand_book[j].amount
            market_clearing_amount = row.final_market_demand_clearing[j].amount
            demand_coeff = demand_coefficients[g]
            for row in demand_rows
                market_book_amount[row] = demand_coeff * final_demand_amount[row - final_demand_offset]
                market_clearing_amount[row] = 0.0
            end
        end
    end

    return nothing
end

function build_stock_pool!(world::Ark.World)

    build_domestic_stock_pool!(world)
    build_import_stock_pool!(world)
    build_stock_weights!(world)

    return nothing
end

function build_domestic_stock_pool!(world::Ark.World)
    @dub for pool_row in Ark.Query(world, (MarketSupplyPool, MarketCapacityPool, MarketPricePool))        @dub for stock_row in Ark.Query(                world,
                (
                    PrincipalProduct,
                    Output,
                    Inventories,
                    CapitalStock,
                    CapitalProductivity,
                    Price,
                    StockCacheIndex,
                )
            )
            @inbounds for j in eachindex(stock_row.e)
                market_pos = stock_row.principal_product[j].id
                available_stock = stock_row.output[j].amount + stock_row.inventories[j].amount
                stock_capacity = stock_row.capital_stock[j].amount * stock_row.capital_productivity[j].value - stock_row.output[j].amount
                stock_pos = stock_row.stock_cache_index[j].id

                pool_row.market_supply_pool[market_pos].amount[stock_pos] = available_stock
                pool_row.market_capacity_pool[market_pos].amount[stock_pos] = stock_capacity
                pool_row.market_price_pool[market_pos].value[stock_pos] = stock_row.price[j].value
            end
        end
    end

    return nothing
end

function build_import_stock_pool!(world::Ark.World)
    @dub for pool_row in Ark.Query(world, (MarketSupplyPool, MarketCapacityPool, MarketPricePool))        @dub for stock_row in Ark.Query(                world, (
                    PrincipalProduct,
                    ImportSupply,
                    ImportPrice,
                    StockCacheIndex,
                )
            )
            @inbounds for j in eachindex(stock_row.e)
                market_pos = stock_row.principal_product[j].id
                pos = stock_row.stock_cache_index[j].id
                pool_row.market_supply_pool[market_pos].amount[pos] = stock_row.import_supply[j].amount
                pool_row.market_capacity_pool[market_pos].amount[pos] = Inf
                pool_row.market_price_pool[market_pos].value[pos] = stock_row.import_price[j].value
            end
        end
    end

    return nothing
end

function build_stock_weights!(world::Ark.World)

    @dub for row in Ark.Query(world, (MarketSupplyPool, MarketPricePool, MarketWeights))
        @inbounds for m in eachindex(row.e)
            price_sum = 0.0
            size_sum = 0.0

            stock = row.market_supply_pool[m].amount
            price = row.market_price_pool[m].value
            weight = row.market_weights[m].value
            for i in eachindex(stock)
                if stock[i] > 0.0
                    wp = exp(-2.0 * price[i])
                    ws = stock[i]
                    weight[i] = wp
                    price_sum += wp
                    size_sum += ws
                else
                    weight[i] = 0.0
                end
            end
            inv_price_sum = price_sum > 0 ? inv(price_sum) : 0.0
            inv_size_sum = size_sum > 0 ? inv(size_sum) : 0.0
            for i in eachindex(weight, price, stock)
                if weight[i] > 0.0
                    weight[i] = weight[i] * inv_price_sum + stock[i] * inv_size_sum
                end
            end
        end
    end


    return nothing
end


@generated function _zero_arrays_unrolled!(arrays::Tuple)
    N = length(arrays.parameters)
    exprs = Expr[]

    push!(exprs, :(inds = eachindex(arrays[1])))

    for j in 2:N
        push!(
            exprs, quote
                comp = arrays[$j]
                z = eltype(comp)(0.0)

                @inbounds @simd ivdep for i in inds
                    comp[i] = z
                end
            end
        )
    end
    push!(exprs, :(return nothing))

    return Expr(:block, exprs...)
end

@inline function zero_out_query!(
        world::Ark.World,
        component_types::Tuple{Vararg{DataType, N}};
        kwargs...
    ) where {N}

    for arrays in Ark.Query(world, component_types; kwargs...)
        _zero_arrays_unrolled!(arrays)
    end

    return nothing
end

function zero_out_components_for_search_and_match!(world::Ark.World)
    zero_out_query!(world, (MaterialsStockChange, Investment, PriceIndex, CFPriceIndex))
    zero_out_query!(world, (GoodsDemand,))
    zero_out_query!(world, (ImportDemand,))

    return nothing
end

function rebuild_active_buyers!(active, demand_col)
    nactive = 0
    @inbounds for i in eachindex(demand_col)
        if demand_col[i] > 1.0e-10
            nactive += 1
            active[nactive] = i
        end
    end
    return nactive
end


abstract type ProductType end
struct Intermediate <: ProductType end
struct Final <: ProductType end

abstract type StockType end
struct Stock <: StockType end
struct Capacity <: StockType end

@inline calc_sold_amount(available_stock, stock_capacity, price, demand_cache_val, firm_index, buyer, ::Intermediate, ::Stock) = min(available_stock, demand_cache_val)
@inline calc_sold_amount(available_stocks, stock_capacity, price, demand_cache_val, firm_index, buyer, ::Intermediate, ::Capacity) = min(stock_capacity, demand_cache_val)

@inline function calc_sold_amount(available_stock, stock_capacity, price, demand_cache_val, firm_index, buyer, ::Final, ::Stock)
    return if available_stock * price <= demand_cache_val
        available_stock
    else
        demand_cache_val / price
    end
end

@inline function calc_sold_amount(available_stock, stock_capacity, price, demand_cache_val, firm_index, buyer, ::Final, ::Capacity)
    return if stock_capacity * price <= demand_cache_val
        stock_capacity
    else
        demand_cache_val / price
    end
end


function reduce_stocks_by_sold_amount!(available_stocks, stock_capacity, firm_index, sold_amount, ::Stock)
    available_stocks[firm_index] -= sold_amount
    return nothing
end

function reduce_stocks_by_sold_amount!(available_stocks, stock_capacity, firm_index, sold_amount, ::Capacity)
    available_stocks[firm_index] -= sold_amount
    stock_capacity[firm_index] -= sold_amount
    return nothing
end

function reduce_demand_by_sold_amount!(demand_cache_vals, demand_cache_nominal, sold_amount, buyer, price, ::Intermediate, ::Stock)
    demand_cache_nominal[buyer] += sold_amount * price
    demand_cache_vals[buyer] -= sold_amount
    return nothing
end

function reduce_demand_by_sold_amount!(demand_cache_vals, demand_cache_nominal, sold_amount, buyer, price, ::Intermediate, ::Capacity)
    demand_cache_vals[buyer] -= sold_amount
    return nothing
end

function reduce_demand_by_sold_amount!(demand_cache_vals, demand_cache_nominal, sold_amount, buyer, price, ::Final, ::Stock)
    demand_cache_nominal[buyer] += sold_amount
    demand_cache_vals[buyer] -= sold_amount * price
    return nothing
end

function reduce_demand_by_sold_amount!(demand_cache_vals, demand_cache_nominal, sold_amount, buyer, price, ::Final, ::Capacity)
    demand_cache_vals[buyer] -= sold_amount * price
    return nothing
end

function adjust_weights!(available_stocks, stock_capacity, weights, firm_index, ::Stock)
    if available_stocks[firm_index] <= 0.0
        weights[firm_index] = 0.0
        return true
    end
    return false
end

function adjust_weights!(available_stocks, stock_capacity, weights, firm_index, ::Capacity)
    if stock_capacity[firm_index] <= 0.0
        weights[firm_index] = 0.0
        return true
    end
    return false
end

function _allocate(sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing, active, weights, market::M, stock_source::S) where {M <: ProductType, S <: StockType}

    nactive = rebuild_active_buyers!(active, demand_book)

    @inbounds while nactive > 0 && !iszero(weights)
        shuffle!(view(active, 1:nactive))

        new_nactive = 0
        for i in 1:nactive
            buyer = active[i]
            firm_index = choose_random_firm(weights)

            price = sector_prices[firm_index]
            available_stock = sector_available_stocks[firm_index]
            stock_capacity = sector_stock_capacity[firm_index]

            sold_amount = calc_sold_amount(available_stock, stock_capacity, price, demand_book[buyer], firm_index, buyer, market, stock_source)


            reduce_stocks_by_sold_amount!(sector_available_stocks, sector_stock_capacity, firm_index, sold_amount, stock_source)
            reduce_demand_by_sold_amount!(demand_book, demand_clearing, sold_amount, buyer, price, market, stock_source)

            adjust_weights!(sector_available_stocks, sector_stock_capacity, weights, firm_index, stock_source) && iszero(weights) && break

            if demand_book[buyer] > 1.0e-10
                new_nactive += 1
                active[new_nactive] = buyer
            end
        end

        nactive = new_nactive
    end

    return nothing
end

allocate_intermediate_from_available_stocks!(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
) = _allocate(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active, weights, Intermediate(), Stock()
)

allocate_intermediate_from_stock_capacity!(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
) = _allocate(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active, weights, Intermediate(), Capacity()
)

allocate_retail_from_available_stocks!(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
) = _allocate(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active, weights, Final(), Stock()
)

allocate_retail_from_stock_capacity!(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
) = _allocate(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active, weights, Final(), Capacity()
)


function update_firm_realisations!(world::Ark.World, technology_matrix, capital_formation)
    @dub for market_row in Ark.Query(world, (PrincipalProduct, FirstPassIntermediateDemand, IntermediateMarketDemandClearing))        @inbounds for j in eachindex(market_row.e)
            sector_id = market_row.principal_product[j].id
            first_pass_amount = market_row.first_pass_intermediate_demand[j].amount
            demand_clearing_amount = market_row.intermediate_market_demand_clearing[j].amount
            @dub for row in Ark.Query(                    world,
                    (
                        MaterialsStockChange,
                        Investment,
                        PrincipalProduct,
                        DesiredMaterials,
                        DesiredInvestment,
                        PriceIndex,
                        CFPriceIndex,
                        IntermediaryDemandCacheIndex,
                    ),
                )

                @inbounds for i in eachindex(row.e)
                    update_firm_realisation_components!(
                        i,
                        sector_id,
                        first_pass_amount,
                        demand_clearing_amount,
                        technology_matrix,
                        capital_formation,
                        row.materials_stock_change,
                        row.investment,
                        row.principal_product,
                        row.desired_materials,
                        row.desired_investment,
                        row.price_index,
                        row.cf_price_index,
                        row.intermediary_demand_cache_index[i].id
                    )
                end
            end
        end
    end

    return nothing
end

@inline function update_firm_realisation_components!(
        i,
        sector,
        demand_vals_sector,
        demand_nominal_sector,
        technology_matrix,
        capital_formation,
        material_stock_change,
        investment,
        principal_product,
        desired_materials,
        desired_investment,
        price_index,
        cf_price_index,
        entity_index
    )
    @inbounds begin
        materials_component =
            technology_matrix[sector, principal_product[i].id] * desired_materials[i].amount
        investment_component = capital_formation[sector] * desired_investment[i].amount
        residual_demand = demand_vals_sector[entity_index]
        realised_quantities = materials_component + investment_component - residual_demand

        residual_investment = investment_component - residual_demand
        material_stock_change_amount = materials_component - max(0.0, - residual_investment)
        investment_amount = max(0.0, residual_investment)
        material_stock_change[i] = (
            material_stock_change[i].amount + material_stock_change_amount
        ) |> MaterialsStockChange

        investment[i] = (
            investment[i].amount + investment_amount
        ) |> Investment

        realised_quantities = BeforeIT.zero_to_one(realised_quantities)

        nominal_spent = demand_nominal_sector[entity_index]

        price_index[i] = (
            price_index[i].value +
                nominal_spent *
                material_stock_change_amount / realised_quantities
        ) |> PriceIndex

        cf_price_index[i] = (
            cf_price_index[i].value +
                nominal_spent *
                investment_amount / realised_quantities
        ) |> CFPriceIndex
    end

    return nothing
end

function rebuild_weight_vector(weights, weight_vector)

    if length(weight_vector) != length(weights)
        weight_vector = FixedSizeWeightVector(length(weights))
    end
    for (i, w) in enumerate(weights)
        weight_vector[i] = w
    end
    return weight_vector

end

function perform_firm_market!(
        sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing, first_pass, active, weights, weight_vector
    )


    weight_vector = BeforeIT.rebuild_weight_vector(weights, weight_vector)

    allocate_intermediate_from_available_stocks!(
        sector_available_stocks,
        sector_stock_capacity,
        sector_prices,
        demand_book,
        demand_clearing,
        active,
        weight_vector,
    )

    copyto!(
        first_pass,
        demand_book,
    )

    weight_vector = BeforeIT.rebuild_weight_vector(weights, weight_vector)
    allocate_intermediate_from_stock_capacity!(
        sector_available_stocks,
        sector_stock_capacity,
        sector_prices,
        demand_book,
        demand_clearing,
        active,
        weight_vector,
    )

    return nothing
end


# Demand rows are no longer needed after allocation. Reuse household rows to stage
# realized consumption and investment before the serial ECS writeback.
function stage_retail_realisations!(
        properties,
        sector::Int64,
        first_pass_vals,
        second_pass_vals,
        demand_clearing_sector,
        realisation_cache,
    )
    (; household_consumption, household_investment, government_consumption, exports) =
        properties.product_coeffs
    (; total) = properties.population
    (; foreign_consumers, local_governments) = properties.dimensions

    consumption_budget = realisation_cache.consumption_budget
    investment_budget = realisation_cache.investment_budget

    household_consumption_coeff = household_consumption[sector]
    household_investment_coeff = household_investment[sector]
    total_real_demand = 0.0
    total_realized_consumption_expenditure = 0.0
    total_realized_investment_expenditure = 0.0
    total_expenditure = 0.0

    @inbounds for row in 1:total
        total_real_demand += demand_clearing_sector[row]

        residual = household_investment_coeff * investment_budget[row] - first_pass_vals[row]
        sector_consumption_demand = household_consumption_coeff * consumption_budget[row]

        realised_consumption = sector_consumption_demand - max(0.0, -residual)
        first_pass_vals[row] = realised_consumption
        total_realized_consumption_expenditure += realised_consumption

        realised_investment = max(0.0, residual)
        second_pass_vals[row] = realised_investment
        total_realized_investment_expenditure += realised_investment
        total_expenditure += sector_consumption_demand + residual
    end

    total_expenditure = BeforeIT.zero_to_one(total_expenditure)
    realisation_cache.household_consumption_price[sector] =
        total_real_demand * total_realized_consumption_expenditure / total_expenditure
    realisation_cache.household_investment_price[sector] =
        total_real_demand * total_realized_investment_expenditure / total_expenditure

    final_demand_amount = realisation_cache.final_demand_amount
    foreign_rows = (total + 1):(total + foreign_consumers)
    government_rows = (total + foreign_consumers + 1):(total + foreign_consumers + local_governments)

    foreign_consumption = 0.0
    export_price = 0.0
    @inbounds for row in foreign_rows
        foreign_consumption += exports[sector] * final_demand_amount[row - total] - first_pass_vals[row]
        export_price += demand_clearing_sector[row]
    end
    realisation_cache.foreign_consumption[sector] = foreign_consumption
    realisation_cache.export_price[sector] = export_price

    realised_government_consumption = 0.0
    government_price = 0.0
    @inbounds for row in government_rows
        realised_government_consumption +=
            government_consumption[sector] * final_demand_amount[row - total] - first_pass_vals[row]
        government_price += demand_clearing_sector[row]
    end
    realisation_cache.government_consumption[sector] = realised_government_consumption
    realisation_cache.government_price[sector] = government_price

    return nothing
end

function update_retail_realisations!(world::Ark.World, realisation_cache)
    household_consumption = realisation_cache.household_consumption_price
    household_investment = realisation_cache.household_investment_price
    price_indices = BeforeIT.price_indices(world)

    price_indices.household_consumption = sum(household_consumption)
    price_indices.capital_formation_households = sum(household_investment)
    government_consumption = sum(realisation_cache.government_consumption)
    government_price = sum(realisation_cache.government_price)
    total_foreign_consumption = sum(realisation_cache.foreign_consumption)
    total_export_price = sum(realisation_cache.export_price)


    @dub for row in Ark.Query(world, (RealisedConsumption, RealisedInvestment, FinalDemandCacheIndex), with = (Household,))        @inbounds @simd for i in eachindex(row.e)
            row.realised_consumption[i] = 0.0 |> RealisedConsumption
            row.realised_investment[i] = 0.0 |> RealisedInvestment
        end
    end

    @dub for market_row in Ark.Query(world, (PrincipalProduct, FinalMarketDemandBook, FirstPassFinalDemand))        for j in eachindex(market_row.e)
            demand_book_amount = market_row.final_market_demand_book[j].amount
            first_pass_amount = market_row.first_pass_final_demand[j].amount
            @dub for row in Ark.Query(                    world, (RealisedConsumption, RealisedInvestment, FinalDemandCacheIndex),
                    with = (Household,),
                )

                @inbounds for i in eachindex(row.e)
                    household_index = row.final_demand_cache_index[i].id
                    row.realised_consumption[i] = row.realised_consumption[i].amount + first_pass_amount[household_index] |> RealisedConsumption
                    row.realised_investment[i] = row.realised_investment[i].amount + demand_book_amount[household_index] |> RealisedInvestment
                end
            end
        end
    end

    @dub for row in Ark.Query(world, (RealisedConsumption, PriceInflationGovernmentGoods), with = (Government,))        @inbounds for i in eachindex(row.e)
            row.realised_consumption[i] = government_consumption |> RealisedConsumption
            row.price_inflation_government_goods[i] = government_price |> PriceInflationGovernmentGoods
        end
    end

    @dub for row in Ark.Query(world, (ForeignConsumption, ExportPriceInflation))        @inbounds for i in eachindex(row.e)
            row.foreign_consumption[i] = total_foreign_consumption |> ForeignConsumption
            row.export_price_inflation[i] = total_export_price |> ExportPriceInflation
        end
    end

    return nothing
end

function update_goods_demand_from_remaining_stocks!(world::Ark.World)
    @dub for market_row in Ark.Query(world, (MarketSupplyPool,))        for j in eachindex(market_row.e)

            @dub for row in Ark.Query(world, (GoodsDemand, Output, Inventories, StockCacheIndex), with = (Market => market_row.e[j],))                @inbounds for i in eachindex(row.e)
                    firm_index = row.stock_cache_index[i].id
                    row.goods_demand[i] = (
                        row.goods_demand[i].amount +
                            row.output[i].amount + row.inventories[i].amount -
                            market_row.market_supply_pool[j].amount[firm_index]
                    ) |> GoodsDemand
                end
            end

        end

    end
    return
end

function update_import_demand_from_remaining_stocks!(world::Ark.World)

    @dub for market_row in Ark.Query(world, (MarketSupplyPool,))        for j in eachindex(market_row.e)

            @dub for row in Ark.Query(world, (ImportDemand, ImportSupply, StockCacheIndex), with = (Market => market_row.e[j],))                @inbounds for i in eachindex(row.e)
                    rotw_index = row.stock_cache_index[i].id

                    row.import_demand[i] = (
                        row.import_demand[i].amount +
                            row.import_supply[i].amount - market_row.market_supply_pool[j].amount[rotw_index]
                    ) |> ImportDemand
                end
            end

        end
    end
    return nothing
end

function perform_retail_market!(
        sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing, first_pass, active, weights, weight_vector
    )


    sector_weights = BeforeIT.rebuild_weight_vector(weights, weight_vector)


    zero_inactive_retail_weights!(
        sector_weights,
        sector_available_stocks,
    )
    allocate_retail_from_available_stocks!(
        sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
        active,
        sector_weights,
    )

    copyto!(
        first_pass,
        demand_book,
    )

    sector_weights = BeforeIT.rebuild_weight_vector(weights, weight_vector)

    zero_inactive_retail_weights!(
        sector_weights,
        sector_stock_capacity,
    )
    allocate_retail_from_stock_capacity!(
        sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
        active,
        sector_weights,
    )


    return nothing
end

function zero_inactive_retail_weights!(weights, live_stocks)
    @inbounds for i in eachindex(weights, live_stocks)
        live_stocks[i] > 0.0 || (weights[i] = 0.0)
    end
    return nothing
end

function choose_random_firm(weights)
    return rand(weights)
end

function update_search_and_match_realisations!(world::Ark.World)
    retail_realisation_cache = Ark.get_resource(world, RetailRealisationCache)

    (; technology_matrix, capital_formation) =
        BeforeIT.properties(world).product_coeffs

    update_firm_realisations!(
        world,
        technology_matrix,
        capital_formation,
    )

    update_retail_realisations!(world, retail_realisation_cache)
    update_goods_demand_from_remaining_stocks!(world)
    update_import_demand_from_remaining_stocks!(world)

    return nothing
end

function finalize_search_and_match!(world::Ark.World)
    price_indices = BeforeIT.price_indices(world)

    total_investment = 0.0
    total_consumption = 0.0

    @dub for row in Ark.Query(            world, (RealisedConsumption, RealisedInvestment, CapitalStock),
            with = (Household,),
        )
        total_consumption += sum(row.realised_consumption.amount)
        total_investment += sum(row.realised_investment.amount)
        row.capital_stock.amount .+= row.realised_investment.amount
    end

    price_indices.household_consumption = total_consumption / BeforeIT.zero_to_one(price_indices.household_consumption)
    price_indices.capital_formation_households = total_investment / BeforeIT.zero_to_one(price_indices.capital_formation_households)

    @dub for row in Ark.Query(world, (RealisedConsumption, PriceInflationGovernmentGoods), with = (Government,))        for i in eachindex(row.e)
            row.price_inflation_government_goods[i] = row.realised_consumption[i].amount / BeforeIT.zero_to_one(row.price_inflation_government_goods[i].value) |> PriceInflationGovernmentGoods
        end
    end

    @dub for row in Ark.Query(world, (ForeignConsumption, ExportPriceInflation))        for i in eachindex(row.e)
            row.export_price_inflation[i] = row.foreign_consumption[i].amount / BeforeIT.zero_to_one(row.export_price_inflation[i].value) |> ExportPriceInflation
        end
    end

    @dub for row in Ark.Query(world, (Sales, GoodsDemand, Output, Inventories))        for i in eachindex(row.e)
            row.sales[i] = min(row.goods_demand[i].amount, row.output[i].amount + row.inventories[i].amount) |> Sales
        end
    end

    @dub for row in Ark.Query(world, (ImportSales, ImportDemand, ImportSupply))        for i in eachindex(row.e)
            row.import_sales[i] = min(row.import_demand[i].amount, row.import_supply[i].amount) |> ImportSales
        end
    end

    @dub for row in Ark.Query(world, (PriceIndex, CFPriceIndex, MaterialsStockChange, Investment))        for i in eachindex(row.price_index)
            if row.materials_stock_change[i].amount > 0.0
                row.price_index[i] = row.price_index[i].value / row.materials_stock_change[i].amount |> PriceIndex
            end
            if row.investment[i].amount > 0.0
                row.cf_price_index[i] = row.cf_price_index[i].value / row.investment[i].amount |> CFPriceIndex
            end
        end
    end

    return nothing
end
