function search_and_matching!(world::Ark.World; parallel = false)
    build_intermediate_demand_cache!(world)
    build_consumption_demand_cache!(world)
    build_stock_cache!(world)
    zero_out_components_for_search_and_match!(world)
    for g in 1:BeforeIT.properties(world).dimensions.sectors
        perform_firm_market!(world, g)
        perform_retail_market!(world, g)
    end
    finalize_search_and_match!(world)
    return nothing
end


function build_intermediate_demand_cache!(world::Ark.World)
    properties = BeforeIT.properties(world)
    demand_cache = Ark.get_resource(world, DesiredIntermediatesCache)
    BeforeIT.reset_cache!(demand_cache)

    (; technology_matrix, capital_formation) = properties.product_coeffs

    for (e, principal_product, desired_investment, desired_materials) in
        Ark.Query(world, (PrincipalProduct, DesiredInvestment, DesiredMaterials))
        for i in eachindex(e)
            demand = compute_intermediate_demand_vector(
                technology_matrix,
                capital_formation,
                principal_product[i].id,
                desired_materials[i].amount,
                desired_investment[i].amount,
            )
            BeforeIT.emblace!(demand, e[i], demand_cache)
        end
    end

    return nothing
end

function compute_intermediate_demand_vector(
        technology_matrix,
        capital_formation,
        product_id,
        desired_materials_amount,
        desired_investment_amount,
    )
    return @view(technology_matrix[:, product_id]) .* desired_materials_amount +
        capital_formation .* desired_investment_amount
end

#TODO: This allocates alot and should be fixed, A single execution takes arround 14ms
function build_consumption_demand_cache!(world::Ark.World)
    properties = BeforeIT.properties(world)
    demand_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)
    BeforeIT.reset_cache!(demand_cache)

    coeffs = properties.product_coeffs
    build_household_consumption_demand_cache!(world, demand_cache, coeffs)
    build_import_consumption_demand_cache!(world, demand_cache, coeffs.exports)
    build_government_consumption_demand_cache!(world, demand_cache, coeffs.government_consumption)

    return nothing
end

function build_household_consumption_demand_cache!(world::Ark.World, demand_cache, coeffs)
    (; household_consumption, household_investment) = coeffs

    append_household_consumption_demand!(
        world,
        demand_cache,
        household_consumption,
        household_investment;
        with = (),
        without = (Inactive, Capitalist, Banker),
    )
    append_household_consumption_demand!(
        world,
        demand_cache,
        household_consumption,
        household_investment;
        with = (Inactive,),
        without = (),
    )
    append_household_consumption_demand!(
        world,
        demand_cache,
        household_consumption,
        household_investment;
        with = (Capitalist,),
        without = (),
    )
    append_household_consumption_demand!(
        world,
        demand_cache,
        household_consumption,
        household_investment;
        with = (Banker,),
        without = (),
    )

    return nothing
end

function append_household_consumption_demand!(
        world::Ark.World,
        demand_cache,
        household_consumption,
        household_investment;
        with,
        without,
    )
    rows = Tuple{Int, Ark.Entity, Float64, Float64}[]
    for (e, consumption_budget, investment_budget) in
        Ark.Query(
            world,
            (ConsumptionBudget, InvestmentBudget),
            with = (Household, with...),
            without = without,
        )
        for i in eachindex(e)
            push!(
                rows, (
                    entity_order_key(e[i]),
                    e[i],
                    consumption_budget[i].amount,
                    investment_budget[i].amount,
                )
            )
        end
    end

    sort!(rows; by = first)
    for (_, entity, consumption_amount, investment_amount) in rows
        demand =
            household_consumption .* consumption_amount +
            household_investment .* investment_amount
        BeforeIT.emblace!(demand, entity, demand_cache)
    end

    return nothing
end

function entity_order_key(entity)
    return parse(Int, match(r"Entity\((\d+),", string(entity)).captures[1])
end

function build_import_consumption_demand_cache!(world::Ark.World, demand_cache, exports)
    for (e, export_demand) in Ark.Query(world, (ForeignConsumptionDemand,))
        for i in eachindex(e)
            BeforeIT.emblace!(exports * export_demand[i].amount, e[i], demand_cache)
        end
    end

    return nothing
end

function build_government_consumption_demand_cache!(world::Ark.World, demand_cache, government_consumption)
    for (e, consumption_demand) in
        Ark.Query(world, (ConsumptionDemand,), with = (LocalGovernment,))
        for i in eachindex(e)
            BeforeIT.emblace!(
                government_consumption * consumption_demand[i].amount,
                e[i],
                demand_cache,
            )
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
    for (e, pp, output, stocks, capital, capital_productivity, price) in
        Ark.Query(
            world,
            (
                PrincipalProduct,
                Output,
                Inventories,
                CapitalStock,
                CapitalProductivity,
                Price,
            ),
        )
        @inbounds for i in eachindex(e)
            available_stock = output[i].amount + stocks[i].amount
            stock_capacity = capital[i].amount * capital_productivity[i].value - output[i].amount

            BeforeIT.emblace!(
                available_stock,
                stock_capacity,
                price[i].value,
                pp[i].id,
                e[i],
                stock_cache,
            )
        end
    end

    return nothing
end

function build_import_stock_cache!(world::Ark.World, stock_cache)
    for (e, pp, import_supply, price) in
        Ark.Query(
            world, (
                PrincipalProduct,
                ImportSupply, ImportPrice,
            )
        )
        @inbounds for i in eachindex(e)
            BeforeIT.emblace!(
                import_supply[i].amount,
                Inf,
                price[i].value,
                pp[i].id,
                e[i],
                stock_cache,
            )
        end
    end
    return nothing
end

function zero_out_components_for_search_and_match!(world::Ark.World)
    price_indices = BeforeIT.price_indices(world)
    for (e, material_stock_change, investment, price_index, cf_price_index) in
        Ark.Query(
            world,
            (
                MaterialsStockChange,
                Investment,
                PriceIndex,
                CFPriceIndex,
            ),
        )
        for i in eachindex(e)
            material_stock_change[i] = MaterialsStockChange(0.0)
            investment[i] = Investment(0.0)
            price_index[i] = PriceIndex(0.0)
            cf_price_index[i] = CFPriceIndex(0.0)

        end
    end
    for (e, realised_consumption, price_inflation) in
        Ark.Query(world, (RealisedConsumption, PriceInflationGovernmentGoods), with = (Government,))
        for i in eachindex(e)
            realised_consumption[i] = RealisedConsumption(0.0)
            price_inflation[i] = PriceInflationGovernmentGoods(0.0)
        end
    end

    for (e, foreign_consumption, export_price) in Ark.Query(world, (ForeignConsumption, ExportPriceInflation))
        for i in eachindex(e)
            foreign_consumption[i] = ForeignConsumption(0.0)
            export_price[i] = ExportPriceInflation(0.0)
        end
    end

    for (e, realised_consumption, realised_investment) in
        Ark.Query(
            world,
            (
                RealisedConsumption,
                RealisedInvestment,
            ),
            with = (Household,),
        )
        for i in eachindex(e)
            realised_consumption[i] = RealisedConsumption(0.0)
            realised_investment[i] = RealisedInvestment(0.0)
        end
    end

    for (e, sales, goods_demand) in Ark.Query(world, (Sales, GoodsDemand))
        for i in eachindex(e)
            sales[i] = Sales(0.0)
            goods_demand[i] = GoodsDemand(0.0)
        end
    end

    for (e, sales, demand) in Ark.Query(world, (ImportSales, ImportDemand))
        for i in eachindex(e)
            sales[i] = ImportSales(0.0)
            demand[i] = ImportDemand(0.0)
        end
    end

    price_indices.household_consumption = 0.0
    price_indices.capital_formation_households = 0.0


    return
end


function rebuild_active_buyers!(active, demand, sector)
    nactive = 0
    @inbounds for i in axes(demand, 1)
        if demand[i, sector] > 0.0
            nactive += 1
            active[nactive] = i
        end
    end
    return nactive
end

function allocate_intermediate_from_available_stocks!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_supply,
    )
    nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)

    while nactive > 0 && !iszero(weights)
        shuffle!(view(active, 1:nactive))

        for i in 1:nactive
            iszero(weights) && break

            buyer = active[i]

            firm_index = BeforeIT.choose_random_firm(stock_cache, sector, weights)


            sold_amount = min(stock_cache.available_stocks[firm_index], demand_cache.vals[buyer, sector])

            stock_cache.available_stocks[firm_index] = max(0.0, stock_cache.available_stocks[firm_index] - sold_amount)
            demand_cache.nominal[buyer, sector] += sold_amount * stock_cache.prices[firm_index]
            demand_cache.vals[buyer, sector] = max(demand_cache.vals[buyer, sector] - sold_amount, 0.0)
            remaining_supply = max(0.0, remaining_supply - sold_amount)

            weights[firm_index - stock_cache.sector_offset[sector] + 1] *=
                (stock_cache.available_stocks[firm_index] > 0.0)
        end

        nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)
    end

    return nothing
end

function allocate_intermediate_from_stock_capacity!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_supply,
    )
    nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)

    while nactive > 0 && !iszero(weights)
        shuffle!(view(active, 1:nactive))

        for i in 1:nactive
            iszero(weights) && break

            buyer = active[i]
            firm_index = BeforeIT.choose_random_firm(stock_cache, sector, weights)
            sold_amount = min(stock_cache.stock_capacity[firm_index], demand_cache.vals[buyer, sector])

            stock_cache.available_stocks[firm_index] -= sold_amount
            stock_cache.stock_capacity[firm_index] -= sold_amount
            demand_cache.vals[buyer, sector] = max(demand_cache.vals[buyer, sector] - sold_amount, 0.0)
            remaining_supply = max(0.0, remaining_supply - sold_amount)

            weights[firm_index - stock_cache.sector_offset[sector] + 1] *=
                (stock_cache.stock_capacity[firm_index] > 0.0)
        end

        nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)
    end

    return nothing
end

function update_firm_realisations!(world::Ark.World, sector::Int64, demand_cache, technology_matrix, capital_formation)
    for (e, material_stock_change, investment, principal_product, desired_materials, desired_investment, price_index, cf_price_index) in
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
            ),
        )
        for i in eachindex(e)
            update_firm_realisation_components!(
                e[i],
                i,
                sector,
                demand_cache,
                technology_matrix,
                capital_formation,
                material_stock_change,
                investment,
                principal_product,
                desired_materials,
                desired_investment,
                price_index,
                cf_price_index,
            )
        end
    end

    return nothing
end

function update_firm_realisation_components!(
        entity,
        i,
        sector,
        demand_cache,
        technology_matrix,
        capital_formation,
        material_stock_change,
        investment,
        principal_product,
        desired_materials,
        desired_investment,
        price_index,
        cf_price_index,
    )
    entity_index = BeforeIT.find_entity_index(entity, demand_cache)

    materials_component =
        technology_matrix[sector, principal_product[i].id] * desired_materials[i].amount
    investment_component = capital_formation[sector] * desired_investment[i].amount
    residual_demand = demand_cache.vals[entity_index, sector]
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

    price_index[i] = PriceIndex(
        price_index[i].value +
            demand_cache.nominal[entity_index, sector] *
            material_stock_change_amount / realised_quantities,
    )

    cf_price_index[i] = CFPriceIndex(
        cf_price_index[i].value +
            demand_cache.nominal[entity_index, sector] *
            investment_amount / realised_quantities,
    )

    return nothing
end

function perform_firm_market!(world::Ark.World, sector::Int64)
    demand_cache = Ark.get_resource(world, BeforeIT.DesiredIntermediatesCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

    (; technology_matrix, capital_formation) = BeforeIT.properties(world).product_coeffs
    active = Vector{Int64}(undef, size(demand_cache.vals, 1))

    weights = BeforeIT.get_weights(stock_cache, sector) |> FixedSizeWeightVector
    remaining_supply = sum(BeforeIT.get_available_stocks(stock_cache, sector))

    allocate_intermediate_from_available_stocks!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_supply,
    )

    remaining_supply = sum(BeforeIT.get_stock_capacity(stock_cache, sector))
    update_firm_realisations!(world, sector, demand_cache, technology_matrix, capital_formation)

    weights = BeforeIT.get_weights(stock_cache, sector) |> FixedSizeWeightVector
    allocate_intermediate_from_stock_capacity!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_supply,
    )


    return nothing
end

function allocate_retail_from_available_stocks!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_stocks,
    )
    nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)
    while nactive > 0 && remaining_stocks > 0.0&& !iszero(weights)
        shuffle!(view(active, 1:nactive))

        for i in 1:nactive
            remaining_stocks <= 0.0 && break
            iszero(weights) && break

            buyer = active[i]
            firm_index = BeforeIT.choose_random_firm(stock_cache, sector, weights)

            price = stock_cache.prices[firm_index]
            sold_amount = min(stock_cache.available_stocks[firm_index], demand_cache.vals[buyer, sector] / price)

            stock_cache.available_stocks[firm_index] -= sold_amount
            demand_cache.nominal[buyer, sector] += sold_amount
            demand_cache.vals[buyer, sector] = max(demand_cache.vals[buyer, sector] - sold_amount * price, 0.0)
            weights[firm_index - stock_cache.sector_offset[sector] + 1] *=
                (stock_cache.available_stocks[firm_index] > 0.0)
            remaining_stocks = max(0.0, remaining_stocks - sold_amount)
        end

        nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)

    end


    return nothing
end

function allocate_retail_from_stock_capacity!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_stocks,
    )
    nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)

    while nactive > 0 && !iszero(weights)
        shuffle!(view(active, 1:nactive))

        for i in 1:nactive
            iszero(weights) && break

            buyer = active[i]

            firm_index = BeforeIT.choose_random_firm(stock_cache, sector, weights)
            price = stock_cache.prices[firm_index]
            sold_amount = min(
                stock_cache.stock_capacity[firm_index],
                demand_cache.vals[buyer, sector] / price,
            )

            stock_cache.available_stocks[firm_index] -= sold_amount
            stock_cache.stock_capacity[firm_index] = max(0.0, stock_cache.stock_capacity[firm_index] - sold_amount)
            demand_cache.vals[buyer, sector] = max(demand_cache.vals[buyer, sector] - sold_amount * price, 0.0)
            weights[firm_index - stock_cache.sector_offset[sector] + 1] *=
                (stock_cache.stock_capacity[firm_index] > 0.0)
        end

        nactive = rebuild_active_buyers!(active, demand_cache.vals, sector)
    end
    return nothing
end

function update_government_realised_consumption!(
        world::Ark.World,
        sector::Int64,
        demand_cache,
        first_pass_vals,
        government_consumption,
    )
    for (e, realised_consumption, price_inflation) in
        Ark.Query(world, (RealisedConsumption, PriceInflationGovernmentGoods), with = (Government,))
        for i in eachindex(e)
            for (local_gov_e, consumption_demand) in
                Ark.Query(world, (ConsumptionDemand,), with = (LocalGovernment => e[i],))
                for j in eachindex(local_gov_e)
                    idx = BeforeIT.find_entity_index(local_gov_e[j], demand_cache)
                    realised_consumption[i] = RealisedConsumption(
                        realised_consumption[i].amount +
                            government_consumption[sector] * consumption_demand[j].amount -
                            first_pass_vals[idx, sector],
                    )
                    price_inflation[i] = PriceInflationGovernmentGoods(
                        price_inflation[i].value + demand_cache.nominal[idx, sector]
                    )
                end
            end
        end
    end

    return nothing
end

function update_foreign_consumption!(world::Ark.World, sector::Int64, demand_cache, first_pass_vals, exports)
    for (e, foreign_consumption, export_price) in Ark.Query(world, (ForeignConsumption, ExportPriceInflation))
        for i in eachindex(e)
            for (foreign_sector_e, consumption_demand) in
                Ark.Query(world, (ForeignConsumptionDemand,))
                for j in eachindex(foreign_sector_e)
                    idx = BeforeIT.find_entity_index(foreign_sector_e[j], demand_cache)
                    foreign_consumption[i] = ForeignConsumption(
                        foreign_consumption[i].amount +
                            exports[sector] * consumption_demand[j].amount -
                            first_pass_vals[idx, sector],
                    )
                    export_price[i] = ExportPriceInflation(
                        export_price[i].value + demand_cache.nominal[idx, sector]
                    )
                end
            end
        end
    end

    return nothing
end

function update_household_realised_consumption_and_prices!(
        world::Ark.World,
        sector::Int64,
        demand_cache,
        first_pass_vals,
        household_consumption,
        household_investment,
    )
    price_indices = BeforeIT.price_indices(world)

    total_real_demand = 0.0
    total_realized_consumption_expenditure = 0.0
    total_realized_investment_expenditure = 0.0
    total_expenditure = 0.0

    for (e, consumption_budget, investment_budget, realised_consumption, realised_investment) in
        Ark.Query(
            world,
            (
                ConsumptionBudget,
                InvestmentBudget,
                RealisedConsumption,
                RealisedInvestment,
            ),
            with = (Household,),
        )
        for i in eachindex(e)
            household_index = BeforeIT.find_entity_index(e[i], demand_cache)

            total_real_demand += demand_cache.nominal[household_index, sector]

            residual =
                household_investment[sector] * investment_budget[i].amount -
                first_pass_vals[household_index, sector]
            sector_consumption_demand = household_consumption[sector] * consumption_budget[i].amount

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
    for (e, principal_product, good_demand, output, inventories) in
        Ark.Query(world, (PrincipalProduct, GoodsDemand, Output, Inventories))
        for i in eachindex(e)
            principal_product[i].id != sector && continue
            firm_index = BeforeIT.find_entity_index(e[i], stock_cache)
            good_demand[i] = GoodsDemand(
                good_demand[i].amount +
                    output[i].amount + inventories[i].amount - stock_cache.available_stocks[firm_index],
            )
        end
    end

    return nothing
end

function update_import_demand_from_remaining_stocks!(world::Ark.World, sector::Int64, stock_cache)
    for (e, principal_product, good_demand, good_supply) in
        Ark.Query(world, (PrincipalProduct, ImportDemand, ImportSupply))
        for i in eachindex(e)
            principal_product[i].id != sector && continue
            rotw_index = BeforeIT.find_entity_index(e[i], stock_cache)

            good_demand[i] = ImportDemand(
                good_demand[i].amount +
                    good_supply[i].amount - stock_cache.available_stocks[rotw_index],
            )
        end
    end

    return nothing
end

function perform_retail_market!(world::Ark.World, sector::Int64)
    demand_cache = Ark.get_resource(world, DesiredHouseholdConsumptionCache)
    stock_cache = Ark.get_resource(world, BeforeIT.StockCache)

    active = Vector{Int64}(undef, size(demand_cache.vals, 1))
    (; government_consumption, exports, household_consumption, household_investment) =
        BeforeIT.properties(world).product_coeffs

    sector_weights = BeforeIT.get_weights(stock_cache, sector)
    original_sector_weights = copy(sector_weights)

    zero_inactive_retail_weights!(
        sector_weights,
        BeforeIT.get_available_stocks(stock_cache, sector),
    )
    weights = sector_weights |> FixedSizeWeightVector
    remaining_stocks = sum(BeforeIT.get_available_stocks(stock_cache, sector))

    allocate_retail_from_available_stocks!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_stocks,
    )

    first_pass_vals = copy(demand_cache.vals)


    update_government_realised_consumption!(
        world,
        sector,
        demand_cache,
        first_pass_vals,
        government_consumption,
    )
    update_foreign_consumption!(world, sector, demand_cache, first_pass_vals, exports)
    update_household_realised_consumption_and_prices!(
        world,
        sector,
        demand_cache,
        first_pass_vals,
        household_consumption,
        household_investment,
    )

    sector_weights .= original_sector_weights
    zero_inactive_retail_weights!(
        sector_weights,
        BeforeIT.get_stock_capacity(stock_cache, sector),
    )
    weights = sector_weights |> FixedSizeWeightVector
    remaining_stocks = sum(BeforeIT.get_stock_capacity(stock_cache, sector))

    allocate_retail_from_stock_capacity!(
        demand_cache,
        stock_cache,
        active,
        sector,
        weights,
        remaining_stocks,
    )

    update_goods_demand_from_remaining_stocks!(world, sector, stock_cache)
    update_import_demand_from_remaining_stocks!(world, sector, stock_cache)


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
            world,
            (
                RealisedConsumption,
                RealisedInvestment,
                CapitalStock,
            ),
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

    for (_, sales, good_demand, output, inventories) in
        Ark.Query(world, (Sales, GoodsDemand, Output, Inventories))
        sales.amount .= min.(good_demand.amount, output.amount .+ inventories.amount)
    end

    for (_, sales, demand, output) in
        Ark.Query(world, (ImportSales, ImportDemand, ImportSupply))
        sales.amount .= min.(demand.amount, output.amount)
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
