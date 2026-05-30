function search_and_matching!(world::Ark.World; parallel = false)
    build_intermediate_demand_cache!(world)
    build_consumption_demand_cache!(world)
    build_stock_cache!(world)
    zero_out_components_for_search_and_match!(world)

    intermediate_cache = Ark.get_resource(world, BeforeIT.DesiredIntermediatesCache)
    consumption_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)


    props = BeforeIT.properties(world)
    sectors = props.dimensions.sectors

    if parallel
        t_active_buffer = Ark.get_resource(world, ParallelActiveCache).active
        tasks = map(t_active_buffer) do (sector_range, t_active)
            Threads.@spawn for g in sector_range
                perform_firm_market!(world, g, t_active)
                perform_retail_market!(world, g, t_active)
            end
        end
        fetch.(tasks)

    else

        active = Ark.get_resource(world, SerialActiveCache).active
        for g in 1:sectors
            perform_firm_market!(world, g, active)
            perform_retail_market!(world, g, active)
        end
    end

    update_search_and_match_realisations!(world)
    finalize_search_and_match!(world)
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
            row = BeforeIT.reserve_row!(e[i], demand_cache)
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
    BeforeIT.reset_cache!(demand_cache)

    coeffs = properties.product_coeffs
    build_household_consumption_demand_cache!(world, demand_cache, coeffs)
    append_scaled_final_demand!(world, demand_cache, ForeignConsumptionDemand, coeffs.exports)
    append_scaled_final_demand!(
        world,
        demand_cache,
        ConsumptionDemand,
        coeffs.government_consumption;
        with = (LocalGovernment,),
    )

    return nothing
end

function build_household_consumption_demand_cache!(world::Ark.World, demand_cache, coeffs)
    (; household_consumption, household_investment) = coeffs
    entities = Ark.get_resource(world, HouseholdConsumptionDemandEntityBuffer).entities

    household_groups = (
        (; with = (), without = (Inactive, Capitalist, Banker)),
        (; with = (Inactive,), without = ()),
        (; with = (Capitalist,), without = ()),
        (; with = (Banker,), without = ()),
    )

    for group in household_groups
        append_household_consumption_demand!(
            world,
            demand_cache,
            entities,
            household_consumption,
            household_investment;
            group.with,
            group.without,
        )
    end

    return nothing
end

function append_household_consumption_demand!(
        world::Ark.World,
        demand_cache,
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

    sort!(entities)

    for entity in entities
        cb, ib = Ark.get_components(world, entity, (ConsumptionBudget, InvestmentBudget))
        row = BeforeIT.reserve_row!(entity, demand_cache)
        Ark.set_components!(world, entity, (FinalDemandCacheIndex(row),))
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

function append_scaled_final_demand!(
        world::Ark.World,
        demand_cache,
        ::Type{DemandType},
        demand_coefficients;
        with = (),
    ) where {DemandType}
    for (e, demand, cache_index) in
        Ark.Query(world, (DemandType, FinalDemandCacheIndex), with = with)
        for i in eachindex(e)
            row = BeforeIT.reserve_row!(e[i], demand_cache)
            cache_index[i] = FinalDemandCacheIndex(row)
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
    BeforeIT.finalize_stock_cache!(stock_cache, world)

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
            BeforeIT.emblace!(
                available_stock,
                stock_capacity,
                price[i].value,
                sector,
                e[i],
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
            BeforeIT.emblace!(
                import_supply[i].amount,
                Inf,
                price[i].value,
                sector,
                e[i],
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

function zero_out_query!(
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
    zero_out_query!(world, (ForeignConsumption, ExportPriceInflation))
    zero_out_query!(world, (Sales, GoodsDemand))
    zero_out_query!(world, (ImportSales, ImportDemand))
    zero_out_query!(world, (RealisedConsumption, PriceInflationGovernmentGoods); with = (Government,))
    zero_out_query!(world, (RealisedConsumption, RealisedInvestment); with = (Household,))

    price_indices = BeforeIT.price_indices(world)
    price_indices.household_consumption = 0.0
    price_indices.capital_formation_households = 0.0

    return nothing
end


function rebuild_active_buyers!(active, demand_col)
    nactive = 0
    @inbounds for i in eachindex(demand_col)
        if demand_col[i] > 0.0
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
            firm_index = BeforeIT.choose_random_firm(stock_cache, sector, weights)

            price = sector_prices[firm_index]
            available_stock = sector_available_stocks[firm_index]
            stock_capacity = sector_stock_capacity[firm_index]
            sold_amount = calc_sold_amount(available_stock, stock_capacity, price, demand_vals_sector[buyer], firm_index, buyer, market, stock_source)


            reduce_stocks_by_sold_amount!(sector_available_stocks, sector_stock_capacity, firm_index, sold_amount, stock_source)
            reduce_demand_by_sold_amount!(demand_vals_sector, demand_nominal_sector, sold_amount, buyer, price, market, stock_source)

            adjust_weights!(sector_available_stocks, sector_stock_capacity, weights, firm_index, stock_source)  && iszero(weights) && break

            if demand_vals_sector[buyer] > 0.0
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


function update_firm_realisations!(world::Ark.World, sector::Int64, demand_cache, technology_matrix, capital_formation)
    demand_vals_sector = @view demand_cache.first_pass_vals[:, sector]
    demand_nominal_sector = @view demand_cache.nominal[:, sector]

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
        for i in eachindex(e)
            update_firm_realisation_components!(
                e[i],
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

    return nothing
end

function update_firm_realisation_components!(
        entity,
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


function update_government_realised_consumption!(
        world::Ark.World,
        demand_nominal_sector,
        first_pass_vals,
        government_consumption,
    )
    for (e, realised_consumption, price_inflation) in
        Ark.Query(world, (RealisedConsumption, PriceInflationGovernmentGoods), with = (Government,))
        for i in eachindex(e)
            for (local_gov_e, consumption_demand, cache_index) in
                Ark.Query(world, (ConsumptionDemand, FinalDemandCacheIndex), with = (LocalGovernment => e[i],))
                for j in eachindex(local_gov_e)
                    idx = cache_index[j].id
                    realised_consumption[i] = RealisedConsumption(
                        realised_consumption[i].amount +
                            government_consumption * consumption_demand[j].amount -
                            first_pass_vals[idx],
                    )
                    price_inflation[i] = PriceInflationGovernmentGoods(
                        price_inflation[i].value + demand_nominal_sector[idx]
                    )
                end
            end
        end
    end

    return nothing
end

function update_foreign_consumption!(world::Ark.World, demand_nominal_sector, first_pass_vals, exports)
    for (e, foreign_consumption, export_price) in Ark.Query(world, (ForeignConsumption, ExportPriceInflation))
        for i in eachindex(e)
            for (foreign_sector_e, consumption_demand, cache_index) in
                Ark.Query(world, (ForeignConsumptionDemand, FinalDemandCacheIndex))
                for j in eachindex(foreign_sector_e)
                    idx = cache_index[j].id
                    foreign_consumption[i] = ForeignConsumption(
                        foreign_consumption[i].amount +
                            exports * consumption_demand[j].amount -
                            first_pass_vals[idx],
                    )
                    export_price[i] = ExportPriceInflation(
                        export_price[i].value + demand_nominal_sector[idx]
                    )
                end
            end
        end
    end

    return nothing
end

function update_household_realised_consumption_and_prices!(
        world::Ark.World,
        demand_nominal_sector,
        first_pass_vals,
        household_consumption,
        household_investment,
    )
    price_indices = BeforeIT.price_indices(world)

    total_real_demand = 0.0
    total_realized_consumption_expenditure = 0.0
    total_realized_investment_expenditure = 0.0
    total_expenditure = 0.0

    for (e, consumption_budget, investment_budget, realised_consumption, realised_investment, cache_index) in
        Ark.Query(
            world, (ConsumptionBudget, InvestmentBudget, RealisedConsumption, RealisedInvestment, FinalDemandCacheIndex),
            with = (Household,),
        )
        for i in eachindex(e)
            household_index = cache_index[i].id
            total_real_demand += demand_nominal_sector[household_index]

            residual =
                household_investment * investment_budget[i].amount -
                first_pass_vals[household_index]
            sector_consumption_demand = household_consumption * consumption_budget[i].amount

            realised_consumption_comp = sector_consumption_demand - max(0.0, -residual)
            realised_consumption[i] = RealisedConsumption(
                realised_consumption[i].amount + realised_consumption_comp,
            )
            total_realized_consumption_expenditure += realised_consumption_comp

            realized_investment_comp = max(0.0, residual)
            realised_investment[i] = RealisedInvestment(
                realised_investment[i].amount + realized_investment_comp,
            )
            total_realized_investment_expenditure += realized_investment_comp
            total_expenditure += sector_consumption_demand + residual
        end
    end

    total_expenditure = BeforeIT.zero_to_one(total_expenditure)
    price_indices.household_consumption +=
        total_real_demand * total_realized_consumption_expenditure / total_expenditure
    price_indices.capital_formation_households +=
        total_real_demand * total_realized_investment_expenditure / total_expenditure

    return nothing
end

function update_goods_demand_from_remaining_stocks!(world::Ark.World, sector::Int64, stock_cache)
    sector_available_stocks = stock_cache.available_stocks[sector]
    for (e, principal_product, good_demand, output, inventories, cache_index) in
        Ark.Query(world, (PrincipalProduct, GoodsDemand, Output, Inventories, StockCacheIndex))
        for i in eachindex(e)
            principal_product[i].id != sector && continue
            firm_index = cache_index[i].id
            good_demand[i] = GoodsDemand(
                good_demand[i].amount +
                    output[i].amount + inventories[i].amount - sector_available_stocks[firm_index],
            )
        end
    end

    return nothing
end

function update_import_demand_from_remaining_stocks!(world::Ark.World, sector::Int64, stock_cache)
    sector_available_stocks = stock_cache.available_stocks[sector]
    for (e, principal_product, good_demand, good_supply, cache_index) in
        Ark.Query(world, (PrincipalProduct, ImportDemand, ImportSupply, StockCacheIndex))
        for i in eachindex(e)
            principal_product[i].id != sector && continue
            rotw_index = cache_index[i].id

            good_demand[i] = ImportDemand(
                good_demand[i].amount +
                    good_supply[i].amount - sector_available_stocks[rotw_index],
            )
        end
    end

    return nothing
end

function perform_retail_market!(world::Ark.World, sector::Int64, active)
    demand_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

    demand_cache.nominal[:, sector] .= 0.0

    sector_weights = BeforeIT.get_weight_vector(stock_cache, sector)

    sector_available_stocks = BeforeIT.get_available_stocks(stock_cache, sector)
    zero_inactive_retail_weights!(
        sector_weights,
        sector_available_stocks,
    )
    weights = sector_weights

    allocate_retail_from_available_stocks!(
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

    sector_weights = BeforeIT.get_weight_vector(stock_cache, sector)
    sector_stock_capacity = BeforeIT.get_stock_capacity(stock_cache, sector)
    zero_inactive_retail_weights!(
        sector_weights,
        sector_stock_capacity,
    )
    weights = sector_weights

    allocate_retail_from_stock_capacity!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
    )

    return nothing
end

function update_search_and_match_realisations!(world::Ark.World)
    intermediate_cache = Ark.get_resource(world, BeforeIT.DesiredIntermediatesCache)
    consumption_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

    (; technology_matrix, capital_formation, government_consumption, exports, household_consumption, household_investment) =
        BeforeIT.properties(world).product_coeffs

    for sector in eachindex(household_consumption)
        update_firm_realisations!(
            world,
            sector,
            intermediate_cache,
            technology_matrix,
            capital_formation,
        )

        demand_nominal_sector = @view consumption_cache.nominal[:, sector]
        first_pass_vals_sector = @view consumption_cache.first_pass_vals[:, sector]

        update_government_realised_consumption!(
            world,
            demand_nominal_sector,
            first_pass_vals_sector,
            government_consumption[sector],
        )
        update_foreign_consumption!(
            world,
            demand_nominal_sector,
            first_pass_vals_sector,
            exports[sector],
        )
        update_household_realised_consumption_and_prices!(
            world,
            demand_nominal_sector,
            first_pass_vals_sector,
            household_consumption[sector],
            household_investment[sector],
        )

        update_goods_demand_from_remaining_stocks!(world, sector, stock_cache)
        update_import_demand_from_remaining_stocks!(world, sector, stock_cache)
    end

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
