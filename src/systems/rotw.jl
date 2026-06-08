function set_rotw_import_export!(world::Ark.World)
    properties = BeforeIT.properties(world)
    sector_price_index = BeforeIT.price_indices(world).sector
    expected_inflation = BeforeIT.expectations(world).inflation
    (; exports, imports) = properties.product_coeffs

    (; E, I) = BeforeIT.epsilons(world)
    (; foreign_consumers) = properties.dimensions
    (; exports_response_to_foreign_output, exports_autoregression) = properties.fiscal_policy
    (; investment_autoregression, investment_response_to_utilization) = properties.sectoral_params

    @dub for t in Ark.Query(world, (TotalExportDemand, TotalImportSupply))
        t.total_export_demand.amount .= exp.(
            exports_response_to_foreign_output .* log.(t.total_export_demand.amount) .+
                exports_autoregression .+ E
        )
        t.total_import_supply.amount .= exp.(
            investment_autoregression .* log.(t.total_import_supply.amount) .+
                investment_response_to_utilization .+ I
        )

        for t2 in Ark.Query(world, (ForeignConsumptionDemand,))
            t2.foreign_consumption_demand.amount .= (
                only(t.total_export_demand.amount) / foreign_consumers *
                    dot(exports, sector_price_index) * (1 + expected_inflation)
            )

        end

        for t2 in Ark.Query(world, (PrincipalProduct, ImportSupply, ImportPrice), with = (ForeignSector,))
            @inbounds for i in eachindex(t2.e)
                g = t2.principal_product[i].id
                t2.import_supply[i] = imports[g] * only(t.total_import_supply.amount) |> ImportSupply
                t2.import_price[i] = (1 + expected_inflation) * sector_price_index[g] |> ImportPrice
            end
        end

    end

    return nothing
end

function set_rotw_deposits!(world::Ark.World)
    properties = BeforeIT.properties(world)

    τ_EXPORT = properties.tax_rates.exports

    @dub for t in Ark.Query(world, (NetForeignPosition, ForeignConsumption))
        for t2 in Ark.Query(world, (ImportPrice, ImportSales))
            t.net_foreign_position.amount .+= dot(t2.import_price.value, t2.import_sales.amount)
        end
        t.net_foreign_position.amount .-= (1 + τ_EXPORT) * t.foreign_consumption.amount
    end

    return nothing
end
