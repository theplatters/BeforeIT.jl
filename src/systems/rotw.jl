function set_rotw_import_export!(world::Ark.World)
    properties = BeforeIT.properties(world)
    sector_price_index = BeforeIT.price_indices(world).sector
    expected_inflation = BeforeIT.expectations(world).inflation
    (; exports, imports) = properties.product_coeffs

    (; E, I) = BeforeIT.epsilons(world)
    (; foreign_consumers) = properties.dimensions
    (; exports_response_to_foreign_output, exports_autoregression) = properties.fiscal_policy
    (; investment_autoregression, investment_response_to_utilization) = properties.sectoral_params

    for comps in Ark.Query(world, (TotalExportDemand, TotalImportSupply))
        row = query_row(comps)
        total_export_demand = row.total_export_demand
        total_import_supply = row.total_import_supply
        total_export_demand.amount .= exp.(exports_response_to_foreign_output .* log.(total_export_demand.amount) .+ exports_autoregression .+ E)
        total_import_supply.amount .= exp.(investment_autoregression .* log.(total_import_supply.amount) .+ investment_response_to_utilization .+ I)

        for comps in Ark.Query(world, (ForeignConsumptionDemand,))
            row = query_row(comps)
            export_demand = row.foreign_consumption_demand
            export_demand.amount .= only(total_export_demand.amount) / foreign_consumers * dot(exports, sector_price_index) * (1 + expected_inflation)

        end

        for comps in Ark.Query(
                world,
                (
                    PrincipalProduct,
                    ImportSupply,
                    ImportPrice,
                ),
                with = (ForeignSector,),
            )
            row = query_row(comps)
            e = row.e
            product = row.principal_product
            import_supply = row.import_supply
            import_price = row.import_price
            @inbounds for i in eachindex(e)
                g = product[i].id # or product[i].index / product[i].sector
                import_supply[i] = imports[g] * only(total_import_supply.amount) |> ImportSupply
                import_price[i] = (1 + expected_inflation) * sector_price_index[g] |> ImportPrice
            end
        end

    end

    return nothing
end

function set_rotw_deposits!(world::Ark.World)
    properties = BeforeIT.properties(world)

    τ_EXPORT = properties.tax_rates.exports

    for comps in Ark.Query(world, (NetForeignPosition, ForeignConsumption))
        row = query_row(comps)
        net_foreign_position = row.net_foreign_position
        foreign_consumption = row.foreign_consumption

        for comps in Ark.Query(world, (ImportPrice, ImportSales))
            row = query_row(comps)
            price = row.import_price
            sales = row.import_sales
            net_foreign_position.amount .+= dot(price.value, sales.amount)
        end
        net_foreign_position.amount .-= (1 + τ_EXPORT) * foreign_consumption.amount
    end

    return nothing
end
