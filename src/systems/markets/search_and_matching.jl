function search_and_matching!(world::Ark.World; parallel = false)
    build_intermediate_demand_cache!(world)
    build_consumption_demand_cache!(world)
    build_stock_cache!(world)
    zero_out_components_for_search_and_match!(world)

    props = BeforeIT.properties(world)
    sectors = props.dimensions.sectors

    if parallel
        t_active_buffer = Ark.get_resource(world, ParallelActiveCache).active
        tasks = map(t_active_buffer) do (sector_range, t_active)
            Threads.@spawn for g in sector_range
                perform_sector_markets!(world, g, t_active)
            end
        end
        fetch.(tasks)

    else

        active = Ark.get_resource(world, SerialActiveCache).active
        for g in 1:sectors
            perform_sector_markets!(world, g, active)
        end
    end

    update_search_and_match_realisations!(world)
    finalize_search_and_match!(world)
    return nothing
end

function perform_sector_markets!(world::Ark.World, sector::Int64, active)
    perform_firm_market!(world, sector, active)
    perform_retail_market!(world, sector, active)
    return nothing
end


function build_intermediate_demand_cache!(world::Ark.World)
    properties = BeforeIT.properties(world)
    demand_cache = Ark.get_resource(world, DesiredIntermediatesCache)
    BeforeIT.reset_cache!(demand_cache)

    (; technology_matrix, capital_formation) = properties.product_coeffs

    for (e, principal_product, desired_investment, desired_materials, cache_index) in
        Ark.Query(world, (PrincipalProduct, DesiredInvestment, DesiredMaterials, IntermediaryDemandCacheIndex))
        for i in eachindex(e)
            row = BeforeIT.reserve_row!(demand_cache)
            cache_index[i] = IntermediaryDemandCacheIndex(row)
            demand_row = @view demand_cache.vals[row, :]
            fill_intermediate_demand_row!(
                demand_row,
                technology_matrix,
                capital_formation,
                principal_product[i].id,
                desired_materials[i].amount,
                desired_investment[i].amount,
            )
        end
    end

    return nothing
end

function fill_intermediate_demand_row!(
        demand_row,
        technology_matrix,
        capital_formation,
        product_id,
        desired_materials_amount,
        desired_investment_amount,
    )
    @inbounds for g in eachindex(demand_row, capital_formation)
        demand_row[g] =
            technology_matrix[g, product_id] * desired_materials_amount +
            capital_formation[g] * desired_investment_amount
    end
    return nothing
end

function fill_household_consumption_demand_row!(
        demand_row,
        household_consumption,
        household_investment,
        consumption_budget,
        investment_budget,
    )
    @inbounds for g in eachindex(demand_row, household_consumption, household_investment)
        demand_row[g] =
            household_consumption[g] * consumption_budget +
            household_investment[g] * investment_budget
    end
    return nothing
end

function fill_scaled_demand_row!(demand_row, demand_coefficients, amount)
    @inbounds for g in eachindex(demand_row, demand_coefficients)
        demand_row[g] = demand_coefficients[g] * amount
    end
    return nothing
end

function build_consumption_demand_cache!(world::Ark.World)
    properties = BeforeIT.properties(world)
    demand_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)
    realisation_cache = Ark.get_resource(world, RetailRealisationCache)
    BeforeIT.reset_cache!(demand_cache)

    coeffs = properties.product_coeffs
    build_household_consumption_demand_cache!(world, demand_cache, realisation_cache, coeffs)
    append_scaled_final_demand!(world, demand_cache, realisation_cache, ForeignConsumptionDemand, coeffs.exports)
    append_scaled_final_demand!(
        world,
        demand_cache,
        realisation_cache,
        ConsumptionDemand,
        coeffs.government_consumption;
        with = (LocalGovernment,),
    )

    return nothing
end

function build_household_consumption_demand_cache!(world::Ark.World, demand_cache, realisation_cache, coeffs)
    (; household_consumption, household_investment) = coeffs
    entities = Ark.get_resource(world, HouseholdConsumptionDemandEntityBuffer).entities

    household_groups = (
        (; with = (), without = (Inactive, Capitalist, Banker)),
        (; with = (Inactive,), without = ()),
        (; with = (Capitalist,), without = ()),
        (; with = (Banker,), without = ()),
    )

    Base.Cartesian.@nexprs 4 i -> begin
        group = household_groups[i]
        append_household_consumption_demand!(
            world,
            demand_cache,
            realisation_cache,
            entities,
            household_consumption,
            household_investment;
            group.with,
            group.without,
        )
    end

    return nothing
end

@inline function append_household_consumption_demand!(
        world::Ark.World,
        demand_cache,
        realisation_cache,
        entities,
        household_consumption,
        household_investment;
        with,
        without,
    )
    empty!(entities)
    for (e,) in Ark.Query(
            world,
            (FinalDemandCacheIndex,),
            with = (Household, with...),
            without = without,
        )
        append!(entities, e)
    end

    sort!(entities; alg = Base.Sort.QuickSort)

    for entity in entities
        cb, ib = Ark.get_components(world, entity, (ConsumptionBudget, InvestmentBudget))
        row = BeforeIT.reserve_row!(demand_cache)
        Ark.set_components!(world, entity, (FinalDemandCacheIndex(row),))
        realisation_cache.consumption_budget[row] = cb.amount
        realisation_cache.investment_budget[row] = ib.amount
        demand_row = @view demand_cache.vals[row, :]
        fill_household_consumption_demand_row!(
            demand_row,
            household_consumption,
            household_investment,
            cb.amount,
            ib.amount,
        )
    end

    return nothing
end

@inline function append_scaled_final_demand!(
        world::Ark.World,
        demand_cache,
        realisation_cache,
        ::Type{DemandType},
        demand_coefficients;
        with = (),
    ) where {DemandType}
    for (e, demand, cache_index) in
        Ark.Query(world, (DemandType, FinalDemandCacheIndex), with = with)
        for i in eachindex(e)
            row = BeforeIT.reserve_row!(demand_cache)
            cache_index[i] = FinalDemandCacheIndex(row)
            final_demand_row = row - length(realisation_cache.consumption_budget)
            realisation_cache.final_demand_amount[final_demand_row] = demand[i].amount
            demand_row = @view demand_cache.vals[row, :]
            fill_scaled_demand_row!(demand_row, demand_coefficients, demand[i].amount)
        end
    end

    return nothing
end

function build_stock_cache!(world::Ark.World)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)
    BeforeIT.reset_cache!(stock_cache)

    build_domestic_stock_cache!(world, stock_cache)
    build_import_stock_cache!(world, stock_cache)
    BeforeIT.finalize_stock_cache!(stock_cache)

    return nothing
end

function build_domestic_stock_cache!(world::Ark.World, stock_cache)
    for (e, pp, output, stocks, capital, capital_productivity, price, cache_index) in
        Ark.Query(
            world,
            (
                PrincipalProduct,
                Output,
                Inventories,
                CapitalStock,
                CapitalProductivity,
                Price,
                StockCacheIndex,
            ),
        )
        @inbounds for i in eachindex(e)
            available_stock = output[i].amount + stocks[i].amount
            stock_capacity = capital[i].amount * capital_productivity[i].value - output[i].amount
            sector = pp[i].id

            cache_index[i] = StockCacheIndex(stock_cache.current_indices[sector])
            BeforeIT.append_stock!(
                available_stock,
                stock_capacity,
                price[i].value,
                sector,
                stock_cache,
            )
        end
    end

    return nothing
end

function build_import_stock_cache!(world::Ark.World, stock_cache)
    for (e, pp, import_supply, price, cache_index) in
        Ark.Query(
            world, (
                PrincipalProduct,
                ImportSupply, ImportPrice,
                StockCacheIndex,
            )
        )
        @inbounds for i in eachindex(e)
            sector = pp[i].id

            cache_index[i] = StockCacheIndex(stock_cache.current_indices[sector])
            BeforeIT.append_stock!(
                import_supply[i].amount,
                Inf,
                price[i].value,
                sector,
                stock_cache,
            )
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

function _allocate(demand_cache, stock_cache, active, sector, weights, market::M, stock_source::S) where {M <: ProductType, S <: StockType}
    sector_available_stocks = stock_cache.available_stocks[sector]
    sector_stock_capacity = stock_cache.stock_capacity[sector]
    sector_prices = stock_cache.prices[sector]
    demand_vals_sector = @view demand_cache.vals[:, sector]
    demand_nominal_sector = @view demand_cache.nominal[:, sector]

    nactive = rebuild_active_buyers!(active, demand_vals_sector)

    @inbounds while nactive > 0 && !iszero(weights)
        shuffle!(view(active, 1:nactive))

        new_nactive = 0
        for i in 1:nactive
            buyer = active[i]
            firm_index = BeforeIT.choose_random_firm(weights)

            price = sector_prices[firm_index]
            available_stock = sector_available_stocks[firm_index]
            stock_capacity = sector_stock_capacity[firm_index]

            sold_amount = calc_sold_amount(available_stock, stock_capacity, price, demand_vals_sector[buyer], firm_index, buyer, market, stock_source)


            reduce_stocks_by_sold_amount!(sector_available_stocks, sector_stock_capacity, firm_index, sold_amount, stock_source)
            reduce_demand_by_sold_amount!(demand_vals_sector, demand_nominal_sector, sold_amount, buyer, price, market, stock_source)

            adjust_weights!(sector_available_stocks, sector_stock_capacity, weights, firm_index, stock_source) && iszero(weights) && break

            if demand_vals_sector[buyer] > 1.0e-10
                new_nactive += 1
                active[new_nactive] = buyer
            end
        end

        nactive = new_nactive
    end

    return nothing
end

allocate_intermediate_from_available_stocks!(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
) = _allocate(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
    Intermediate(),
    Stock()
)

allocate_intermediate_from_stock_capacity!(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
) = _allocate(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
    Intermediate(),
    Capacity()
)

allocate_retail_from_available_stocks!(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
) = _allocate(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
    Final(),
    Stock()
)

allocate_retail_from_stock_capacity!(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
) = _allocate(
    demand_cache,
    stock_cache,
    active,
    sector,
    weights,
    Final(),
    Capacity()
)


function update_firm_realisations!(world::Ark.World, demand_cache, technology_matrix, capital_formation)
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
        for sector in axes(demand_cache.first_pass_vals, 2)
            demand_vals_sector = @view demand_cache.first_pass_vals[:, sector]
            demand_nominal_sector = @view demand_cache.nominal[:, sector]

            @inbounds for i in eachindex(e)
                update_firm_realisation_components!(
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
                    entity_index[i].id
                )
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

function perform_firm_market!(world::Ark.World, sector::Int64, active)
    demand_cache = Ark.get_resource(world, BeforeIT.DesiredIntermediatesCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

    demand_cache.nominal[:, sector] .= 0.0

    weights = BeforeIT.get_weight_vector(stock_cache, sector)

    allocate_intermediate_from_available_stocks!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
    )

    copyto!(
        @view(demand_cache.first_pass_vals[:, sector]),
        @view(demand_cache.vals[:, sector]),
    )

    weights = BeforeIT.get_weight_vector(stock_cache, sector)
    allocate_intermediate_from_stock_capacity!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
    )

    return nothing
end


# Demand rows are no longer needed after allocation. Reuse household rows to stage
# realized consumption and investment before the serial ECS writeback.
function stage_retail_realisations!(
        world::Ark.World,
        sector::Int64,
        demand_cache,
        realisation_cache,
    )
    properties = BeforeIT.properties(world)
    (; household_consumption, household_investment, government_consumption, exports) =
        properties.product_coeffs
    (; total) = properties.population
    (; foreign_consumers, local_governments) = properties.dimensions

    demand_nominal_sector = @view demand_cache.nominal[:, sector]
    first_pass_vals = @view demand_cache.first_pass_vals[:, sector]
    second_pass_vals = @view demand_cache.vals[:, sector]
    consumption_budget = realisation_cache.consumption_budget
    investment_budget = realisation_cache.investment_budget

    household_consumption_coeff = household_consumption[sector]
    household_investment_coeff = household_investment[sector]
    total_real_demand = 0.0
    total_realized_consumption_expenditure = 0.0
    total_realized_investment_expenditure = 0.0
    total_expenditure = 0.0

    @inbounds for row in 1:total
        total_real_demand += demand_nominal_sector[row]

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
        export_price += demand_nominal_sector[row]
    end
    realisation_cache.foreign_consumption[sector] = foreign_consumption
    realisation_cache.export_price[sector] = export_price

    realised_government_consumption = 0.0
    government_price = 0.0
    @inbounds for row in government_rows
        realised_government_consumption +=
            government_consumption[sector] * final_demand_amount[row - total] - first_pass_vals[row]
        government_price += demand_nominal_sector[row]
    end
    realisation_cache.government_consumption[sector] = realised_government_consumption
    realisation_cache.government_price[sector] = government_price

    return nothing
end

function update_retail_realisations!(world::Ark.World, demand_cache, realisation_cache)
    properties = BeforeIT.properties(world)
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
        @inbounds for i in eachindex(e)
            household_index = cache_index[i].id
            consumption = 0.0
            investment = 0.0
            for sector in 1:properties.dimensions.sectors
                consumption += demand_cache.first_pass_vals[household_index, sector]
                investment += demand_cache.vals[household_index, sector]
            end
            realised_consumption[i] = RealisedConsumption(consumption)
            realised_investment[i] = RealisedInvestment(investment)
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

function update_goods_demand_from_remaining_stocks!(world::Ark.World, stock_cache)
    for (e, principal_product, good_demand, output, inventories, cache_index) in
        Ark.Query(world, (PrincipalProduct, GoodsDemand, Output, Inventories, StockCacheIndex))
        @inbounds for i in eachindex(e)
            sector = principal_product[i].id
            firm_index = cache_index[i].id
            good_demand[i] = GoodsDemand(
                good_demand[i].amount +
                    output[i].amount + inventories[i].amount -
                    stock_cache.available_stocks[sector][firm_index],
            )
        end
    end

    return nothing
end

function update_import_demand_from_remaining_stocks!(world::Ark.World, stock_cache)
    for (e, principal_product, good_demand, good_supply, cache_index) in
        Ark.Query(world, (PrincipalProduct, ImportDemand, ImportSupply, StockCacheIndex))
        @inbounds for i in eachindex(e)
            sector = principal_product[i].id
            rotw_index = cache_index[i].id

            good_demand[i] = ImportDemand(
                good_demand[i].amount +
                    good_supply[i].amount - stock_cache.available_stocks[sector][rotw_index],
            )
        end
    end

    return nothing
end

function perform_retail_market!(world::Ark.World, sector::Int64, active)
    demand_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)
    realisation_cache = Ark.get_resource(world, RetailRealisationCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

    demand_cache.nominal[:, sector] .= 0.0

    sector_weights = BeforeIT.get_weight_vector(stock_cache, sector)

    sector_available_stocks = BeforeIT.get_available_stocks(stock_cache, sector)
    zero_inactive_retail_weights!(
        sector_weights,
        sector_available_stocks,
    )
    allocate_retail_from_available_stocks!(
        demand_cache,
        stock_cache,
        active,
        sector,
        sector_weights,
    )

    copyto!(
        @view(demand_cache.first_pass_vals[:, sector]),
        @view(demand_cache.vals[:, sector]),
    )

    sector_weights = BeforeIT.get_weight_vector(stock_cache, sector)
    sector_stock_capacity = BeforeIT.get_stock_capacity(stock_cache, sector)
    zero_inactive_retail_weights!(
        sector_weights,
        sector_stock_capacity,
    )
    allocate_retail_from_stock_capacity!(
        demand_cache,
        stock_cache,
        active,
        sector,
        sector_weights,
    )

    stage_retail_realisations!(world, sector, demand_cache, realisation_cache)

    return nothing
end

function update_search_and_match_realisations!(world::Ark.World)
    intermediate_cache = Ark.get_resource(world, BeforeIT.DesiredIntermediatesCache)
    consumption_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)
    retail_realisation_cache = Ark.get_resource(world, RetailRealisationCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

    (; technology_matrix, capital_formation) =
        BeforeIT.properties(world).product_coeffs

    update_firm_realisations!(
        world,
        intermediate_cache,
        technology_matrix,
        capital_formation,
    )

    update_retail_realisations!(world, consumption_cache, retail_realisation_cache)
    update_goods_demand_from_remaining_stocks!(world, stock_cache)
    update_import_demand_from_remaining_stocks!(world, stock_cache)

    return nothing
end

function zero_inactive_retail_weights!(weights, live_stocks)
    @inbounds for i in eachindex(weights, live_stocks)
        live_stocks[i] > 0.0 || (weights[i] = 0.0)
    end
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
