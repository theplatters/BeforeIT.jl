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
        totals_row = query_row(comps)
        totals_row.total_export_demand.amount .= exp.(
            exports_response_to_foreign_output .* log.(totals_row.total_export_demand.amount) .+
                exports_autoregression .+
                E
        )
        totals_row.total_import_supply.amount .= exp.(
            investment_autoregression .* log.(totals_row.total_import_supply.amount) .+
                investment_response_to_utilization .+
                I
        )

        for comps in Ark.Query(world, (ForeignConsumptionDemand,))
            row = query_row(comps)
            row.foreign_consumption_demand.amount .= (
                only(totals_row.total_export_demand.amount) / foreign_consumers *
                    dot(exports, sector_price_index) *
                    (1 + expected_inflation)
            )

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
            @inbounds for i in eachindex(row.e)
                g = row.principal_product[i].id
                row.import_supply[i] = imports[g] * only(totals_row.total_import_supply.amount) |> ImportSupply
                row.import_price[i] = (1 + expected_inflation) * sector_price_index[g] |> ImportPrice
            end
        end

    end

    return nothing
end

function set_rotw_deposits!(world::Ark.World)
    properties = BeforeIT.properties(world)

    τ_EXPORT = properties.tax_rates.exports

    for comps in Ark.Query(world, (NetForeignPosition, ForeignConsumption))
        rotw_row = query_row(comps)

        for comps in Ark.Query(world, (ImportPrice, ImportSales))
            row = query_row(comps)
            rotw_row.net_foreign_position.amount .+= dot(row.import_price.value, row.import_sales.amount)
        end
        rotw_row.net_foreign_position.amount .-= (1 + τ_EXPORT) * rotw_row.foreign_consumption.amount
    end

    return nothing
end
