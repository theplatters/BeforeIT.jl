function search_and_matching!(world::Ark.World; parallel = false)
    build_intermediate_demand!(world)
    build_consumption_demand!(world)
    build_stock_pool!(world)
    zero_out_components_for_search_and_match!(world)


    perform_search_and_matching!(world)

    update_search_and_match_realisations!(world)
    finalize_search_and_match!(world)
    return nothing
end


function perform_search_and_matching!(world::Ark.World)
    realisation_cache = Ark.get_resource(world, RetailRealisationCache)
    properties = BeforeIT.properties(world)
    for (e, demand_book, demand_clearing, sector_available_stocks, sector_stock_capacity, sector_prices, first_pass, weights, weight_vector, active) in Ark.Query(
            world,
            (
                IntermediateMarketDemandBook,
                IntermediateMarketDemandClearing,
                MarketSupplyPool,
                MarketCapacityPool,
                MarketPricePool,
                FirstPassIntermediateDemand,
                MarketWeights,
                MarketWeightVector,
                ActiveBuyers,
            )
        )
        for i in eachindex(e)
            perform_firm_market!(
                sector_available_stocks[i].amount,
                sector_stock_capacity[i].amount,
                sector_prices[i].value,
                demand_book[i].amount,
                demand_clearing[i].amount,
                first_pass[i].amount,
                active[i].ids,
                weights[i].value,
                weight_vector[i].value
            )

        end
    end

    for (e, sector, demand_book, demand_clearing, sector_available_stocks, sector_stock_capacity, sector_prices, first_pass, weights, weight_vector, active) in Ark.Query(
            world,
            (
                PrincipalProduct,
                FinalMarketDemandBook,
                FinalMarketDemandClearing,
                MarketSupplyPool,
                MarketCapacityPool,
                MarketPricePool,
                FirstPassFinalDemand,
                MarketWeights,
                MarketWeightVector,
                ActiveBuyers,
            )
        )
        for i in eachindex(e)
            perform_retail_market!(
                sector_available_stocks[i].amount,
                sector_stock_capacity[i].amount,
                sector_prices[i].value,
                demand_book[i].amount,
                demand_clearing[i].amount,
                first_pass[i].amount,
                active[i].ids,
                weights[i].value,
                weight_vector[i].value
            )

            stage_retail_realisations!(properties, sector[i].id, first_pass[i].amount, demand_book[i].amount, demand_clearing[i].amount, realisation_cache)
        end
    end


    return nothing
end

function build_intermediate_demand!(world::Ark.World)

    (; technology_matrix, capital_formation) = BeforeIT.properties(world).product_coeffs
    last_pos = 1
    for (e_buyer, principal_product, desired_investment, desired_materials, index) in Ark.Query(
            world,
            (PrincipalProduct, DesiredInvestment, DesiredMaterials, IntermediaryDemandCacheIndex)
        )
        @inbounds for i in eachindex(e_buyer)
            index[i] = IntermediaryDemandCacheIndex(last_pos)
            last_pos += 1
            for (e_market, sector, market_book, market_clearing) in Ark.Query(
                    world,
                    (PrincipalProduct, IntermediateMarketDemandBook, IntermediateMarketDemandClearing)
                )

                for j in eachindex(e_market)
                    product_id = principal_product[i].id
                    desired_materials_amount = desired_materials[i].amount
                    desired_investment_amount = desired_investment[i].amount
                    g = sector[j].id
                    market_book[j].amount[i] =
                        technology_matrix[g, product_id] * desired_materials_amount +
                        capital_formation[g] * desired_investment_amount
                    market_clearing[j].amount[i] = 0.0
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
    entities = Ark.get_resource(world, HouseholdConsumptionDemandEntityBuffer).entities
    realisation_cache = Ark.get_resource(world, RetailRealisationCache)


    household_groups = (
        (; with = (), without = (Inactive, Capitalist, Banker)),
        (; with = (Inactive,), without = ()),
        (; with = (Capitalist,), without = ()),
        (; with = (Banker,), without = ()),
    )

    last_pos = 1
    Base.Cartesian.@nexprs 4 i -> begin
        group = household_groups[i]
        last_pos = append_household_consumption_demand!(
            world,
            realisation_cache,
            entities,
            household_consumption,
            household_investment,
            last_pos;
            group.with,
            group.without,
        )
    end

    last_pos = append_scaled_final_demand!(world, realisation_cache, ForeignConsumptionDemand, coeffs.exports, last_pos)
    append_scaled_final_demand!(
        world,
        realisation_cache,
        ConsumptionDemand,
        coeffs.government_consumption,
        last_pos;
        with = (LocalGovernment,),
    )


    return nothing
end

@inline function append_household_consumption_demand!(
        world::Ark.World,
        realisation_cache,
        entities,
        household_consumption,
        household_investment,
        last_pos;
        with,
        without,
    )
    empty!(entities)
    for (e,) in Ark.Query(
            world,
            (),
            with = (Household, with...),
            without = without,
        )
        append!(entities, e)
    end

    sort!(entities; alg = Base.Sort.QuickSort)

    for entity in entities
        cb, ib = Ark.get_components(world, entity, (ConsumptionBudget, InvestmentBudget))

        Ark.set_components!(world, entity, (FinalDemandCacheIndex(last_pos),))
        for (e_market, sector, market_book, market_clearing) in
            Ark.Query(world, (PrincipalProduct, FinalMarketDemandBook, FinalMarketDemandClearing))

            realisation_cache.consumption_budget[last_pos] = cb.amount
            realisation_cache.investment_budget[last_pos] = ib.amount

            for j in eachindex(e_market)
                g = sector[j].id
                market_book[j].amount[last_pos] =
                    household_consumption[g] * cb.amount +
                    household_investment[g] * ib.amount
                market_clearing[j].amount[last_pos] = 0.0
            end
        end

        last_pos += 1
    end


    return last_pos
end

@inline function append_scaled_final_demand!(
        world::Ark.World,
        realisation_cache,
        ::Type{DemandType},
        demand_coefficients,
        last_pos;
        with = (),
    ) where {DemandType}
    for (e, demand, cache_index) in
        Ark.Query(world, (DemandType, FinalDemandCacheIndex), with = with)

        for i in eachindex(e)

            final_demand_pos = last_pos - length(realisation_cache.consumption_budget)
            realisation_cache.final_demand_amount[final_demand_pos] = demand[i].amount
            cache_index[i] = FinalDemandCacheIndex(last_pos)
            for (e_market, sector, market_book, market_clearing) in
                Ark.Query(world, (PrincipalProduct, FinalMarketDemandBook, FinalMarketDemandClearing))
                for j in eachindex(e_market)
                    g = sector[j].id
                    market_book[j].amount[last_pos] =
                        demand_coefficients[g] * demand[i].amount
                    market_clearing[j].amount[last_pos] = 0.0
                end
            end

            last_pos += 1
        end
    end

    return last_pos
end

function build_stock_pool!(world::Ark.World)

    build_domestic_stock_pool!(world)
    build_import_stock_pool!(world)
    build_stock_weights!(world)

    return nothing
end

function build_domestic_stock_pool!(world::Ark.World)
    for (e_market, supply, capacity, price) in
        Ark.Query(world, (MarketSupplyPool, MarketCapacityPool, MarketPricePool))
        @inbounds for i in eachindex(e_market)
            for (e, output, stocks, capital, capital_productivity, firm_price, index) in
                Ark.Query(
                    world,
                    (
                        Output,
                        Inventories,
                        CapitalStock,
                        CapitalProductivity,
                        Price,
                        StockCacheIndex,
                    );
                    with = (Market => e_market[i],)
                )
                for j in eachindex(e)
                    available_stock = output[j].amount + stocks[j].amount
                    stock_capacity = capital[j].amount * capital_productivity[j].value - output[j].amount

                    index[j] = StockCacheIndex(j)
                    supply[i].amount[j] = available_stock
                    capacity[i].amount[j] = stock_capacity
                    price[i].value[j] = firm_price[j].value
                end
            end


        end
    end

    return nothing
end

function build_import_stock_pool!(world::Ark.World)
    properties = BeforeIT.properties(world)
    for (e_market, sector, supply, capacity, price) in
        Ark.Query(world, (PrincipalProduct, MarketSupplyPool, MarketCapacityPool, MarketPricePool))
        @inbounds for i in eachindex(e_market)
            for (e, import_supply, firm_price, index) in
                Ark.Query(
                    world, (
                        ImportSupply, ImportPrice, StockCacheIndex,
                    ),
                    with = (Market => e_market[i],)

                )
                for j in eachindex(e)
                    pos = properties.dimensions.firms_per_sector[sector[i].id] + j
                    supply[i].amount[pos] = import_supply[j].amount
                    capacity[i].amount[pos] = Inf
                    price[i].value[pos] = firm_price[j].value
                    index[j] = StockCacheIndex(pos)
                end
            end


        end
    end

    return nothing
end

function build_stock_weights!(world::Ark.World)

    for (e_market, stocks, prices, weights) in
        Ark.Query(world, (MarketSupplyPool, MarketPricePool, MarketWeights))

        @inbounds for m in eachindex(e_market)
            price_sum = 0.0
            size_sum = 0.0

            stock = stocks[m].amount
            price = prices[m].value
            weight = weights[m].value
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
            @inbounds for i in eachindex(weight, price, stock)
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
            firm_index = BeforeIT.choose_random_firm(weights)

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
    active,
    weights,
    Intermediate(),
    Stock()
)

allocate_intermediate_from_stock_capacity!(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
) = _allocate(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
    Intermediate(),
    Capacity()
)

allocate_retail_from_available_stocks!(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
) = _allocate(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
    Final(),
    Stock()
)

allocate_retail_from_stock_capacity!(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
) = _allocate(
    sector_available_stocks, sector_stock_capacity, sector_prices, demand_book, demand_clearing,
    active,
    weights,
    Final(),
    Capacity()
)


function update_firm_realisations!(world::Ark.World, technology_matrix, capital_formation)
    for (e, material_stock_change, investment, principal_product, desired_materials, desired_investment, price_index, cf_price_index, entity_index) in
        Ark.Query(
            world,
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

        @inbounds for i in eachindex(e)
            for (e_market, sector, demand_book, demand_clearing) in Ark.Query(world, (PrincipalProduct, IntermediateMarketDemandBook, IntermediateMarketDemandClearing))
                @inbounds for j in eachindex(e_market)

                    update_firm_realisation_components!(
                        i,
                        sector[j].id,
                        demand_book[j].amount,
                        demand_clearing[j].amount,
                        technology_matrix,
                        capital_formation,
                        material_stock_change,
                        investment,
                        principal_product,
                        desired_materials,
                        desired_investment,
                        price_index,
                        cf_price_index,
                        entity_index[i].id
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
        material_stock_change[i] = MaterialsStockChange(
            material_stock_change[i].amount + material_stock_change_amount
        )

        investment[i] = Investment(
            investment[i].amount + investment_amount
        )

        realised_quantities = BeforeIT.zero_to_one(realised_quantities)

        nominal_spent = demand_nominal_sector[entity_index]

        price_index[i] = PriceIndex(
            price_index[i].value +
                nominal_spent *
                material_stock_change_amount / realised_quantities,
        )

        cf_price_index[i] = CFPriceIndex(
            cf_price_index[i].value +
                nominal_spent *
                investment_amount / realised_quantities,
        )
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


    for (e, realised_consumption, realised_investment, cache_index) in
        Ark.Query(
            world, (RealisedConsumption, RealisedInvestment, FinalDemandCacheIndex),
            with = (Household,),
        )
        @inbounds @simd for i in eachindex(e)
            household_index = cache_index[i].id
            realised_consumption[i] = RealisedConsumption(0.0)
            realised_investment[i] = RealisedInvestment(0.0)
        end
    end

    for (e, realised_consumption, realised_investment, cache_index) in
        Ark.Query(
            world, (RealisedConsumption, RealisedInvestment, FinalDemandCacheIndex),
            with = (Household,),
        )

        @inbounds for i in eachindex(e)

            household_index = cache_index[i].id
            for (e_market, sector, demand_book, first_pass) in
                Ark.Query(world, (PrincipalProduct, FinalMarketDemandBook, FirstPassFinalDemand))

                for j in eachindex(e_market)
                    realised_consumption[i] = RealisedConsumption(realised_consumption[i].amount + first_pass[j].amount[household_index])
                    realised_investment[i] = RealisedInvestment(realised_investment[i].amount + demand_book[j].amount[household_index])
                end
            end
        end
    end

    for (e, realised_consumption, price_inflation) in
        Ark.Query(world, (RealisedConsumption, PriceInflationGovernmentGoods), with = (Government,))
        @inbounds for i in eachindex(e)
            realised_consumption[i] = RealisedConsumption(government_consumption)
            price_inflation[i] = PriceInflationGovernmentGoods(government_price)
        end
    end

    for (e, foreign_consumption, export_price) in Ark.Query(world, (ForeignConsumption, ExportPriceInflation))
        @inbounds for i in eachindex(e)
            foreign_consumption[i] = ForeignConsumption(total_foreign_consumption)
            export_price[i] = ExportPriceInflation(total_export_price)
        end
    end

    return nothing
end

function update_goods_demand_from_remaining_stocks!(world::Ark.World)
    for (e_market, supply) in Ark.Query(world, (MarketSupplyPool,))
        for j in eachindex(e_market)

            for (e, good_demand, output, inventories, cache_index) in
                Ark.Query(world, (GoodsDemand, Output, Inventories, StockCacheIndex), with = (Market => e_market[j],))
                @inbounds for i in eachindex(e)
                    firm_index = cache_index[i].id
                    good_demand[i] = GoodsDemand(
                        good_demand[i].amount +
                            output[i].amount + inventories[i].amount -
                            supply[j].amount[firm_index],
                    )
                end
            end

        end

    end
    return
end

function update_import_demand_from_remaining_stocks!(world::Ark.World)

    for (e_market, supply) in Ark.Query(world, (MarketSupplyPool,))
        for j in eachindex(e_market)

            for (e, good_demand, good_supply, cache_index) in
                Ark.Query(world, (ImportDemand, ImportSupply, StockCacheIndex), with = (Market => e_market[j],))
                @inbounds for i in eachindex(e)
                    rotw_index = cache_index[i].id

                    good_demand[i] = ImportDemand(
                        good_demand[i].amount +
                            good_supply[i].amount - supply[j].amount[rotw_index],
                    )
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

function update_search_and_match_realisations!(world::Ark.World)
    retail_realisation_cache = Ark.get_resource(world, RetailRealisationCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

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

    for (_, realised_consumption, realised_investment, capital_stock) in
        Ark.Query(
            world, (RealisedConsumption, RealisedInvestment, CapitalStock),
            with = (Household,),
        )
        total_consumption += sum(realised_consumption.amount)
        total_investment += sum(realised_investment.amount)
        capital_stock.amount .+= realised_investment.amount
    end

    price_indices.household_consumption = total_consumption / BeforeIT.zero_to_one(price_indices.household_consumption)
    price_indices.capital_formation_households = total_investment / BeforeIT.zero_to_one(price_indices.capital_formation_households)

    for (e, realised_consumption, price_inflation) in
        Ark.Query(world, (RealisedConsumption, PriceInflationGovernmentGoods), with = (Government,))
        for i in eachindex(e)
            price_inflation[i] = PriceInflationGovernmentGoods(realised_consumption[i].amount / BeforeIT.zero_to_one(price_inflation[i].value))
        end
    end

    for (e, foreign_consumption, export_price) in Ark.Query(world, (ForeignConsumption, ExportPriceInflation))
        for i in eachindex(e)
            export_price[i] = ExportPriceInflation(foreign_consumption[i].amount / BeforeIT.zero_to_one(export_price[i].value))
        end
    end

    for (e, sales, good_demand, output, inventories) in Ark.Query(world, (Sales, GoodsDemand, Output, Inventories))
        for i in eachindex(e)
            sales[i] = Sales(min(good_demand[i].amount, output[i].amount + inventories[i].amount))
        end
    end

    for (e, sales, demand, output) in Ark.Query(world, (ImportSales, ImportDemand, ImportSupply))
        for i in eachindex(e)
            sales[i] = ImportSales(min(demand[i].amount, output[i].amount))
        end
    end

    for (_, price_index, cf_price_index, materials, investment) in Ark.Query(world, (PriceIndex, CFPriceIndex, MaterialsStockChange, Investment))
        for i in eachindex(price_index)
            if materials[i].amount > 0.0
                price_index[i] = PriceIndex(price_index[i].value / materials[i].amount)
            end
            if investment[i].amount > 0.0
                cf_price_index[i] = CFPriceIndex(cf_price_index[i].value / investment[i].amount)
            end
        end
    end

    return nothing
end
