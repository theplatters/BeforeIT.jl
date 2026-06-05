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
            ForeignConsumptionDemand(0.0),
            RestOfWorldEntity(rotw),
            FinalDemandCacheIndex(0),
        )
    )


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
                IntermediaryDemandCacheIndex(0),
                StockCacheIndex(0),
                Market() => markets[g],
            )
        )

    end

    return nothing
end
