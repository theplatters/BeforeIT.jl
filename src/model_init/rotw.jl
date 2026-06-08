function setup_rotw!(world::Ark.World, properties::Properties, markets)
    L = properties.dimensions.foreign_consumers
    G = properties.dimensions.sectors
    T_prime = properties.dimensions.interval_for_expectation_estimation


    external = properties.initial_conditions.external

    rotw = Ark.new_entity!(
        world,
        (
            EuroAreaGDP(external.foreign_output),
            EuroAreaGrowth(0.0),
            EuroAreaInflation(external.foreign_inflation),
            ExportPriceInflation(0.0),
            NetForeignPosition(external.debt),
            ForeignConsumption(0.0),
            TotalExportDemand(external.exports[T_prime]),
            TotalImportSupply(external.imports[T_prime]),
        )
    )

    Ark.new_entities!(
        world, L,
        (
            ForeignConsumptionDemand,
            RestOfWorldEntity,
            FinalDemandCacheIndex,
        )
    ) do (entities, foreign_consumption_demand, rest_of_world_entity, final_cache_index)
        for i in eachindex(entities)
            foreign_consumption_demand[i] = 0.0 |> ForeignConsumptionDemand
            rest_of_world_entity[i] = rotw |> RestOfWorldEntity
            final_cache_index[i] = properties.population.total + i |> FinalDemandCacheIndex
        end
    end


    for g in 1:G

        Ark.new_entity!(
            world,
            (

                ForeignSector(),
                PrincipalProduct(g),
                ImportSupply(0.0),
                ImportSales(0.0),
                ImportDemand(0.0),
                ImportPrice(0.0),
                ExportPriceInflation(0.0),
                RestOfWorldEntity(rotw),
                StockCacheIndex(properties.dimensions.firms_per_sector[g] + 1),
                Market() => markets[g],
            )
        )

    end

    return nothing
end
