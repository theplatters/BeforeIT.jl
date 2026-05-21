function setup_rotw!(world::Ark.World, properties::Properties)
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


    Ark.new_entities!(
        world, G,
        (

            ForeignSector,
            PrincipalProduct,
            ImportSupply,
            ImportSales,
            ImportDemand,
            ImportPrice,
            ExportPriceInflation,
            RestOfWorldEntity,
            IntermediaryDemandCacheIndex,
            StockCacheIndex,
        )
    ) do (entities, fs, pp, isupply, isales, idemand, iprice, epi, rowe, intermediary_cache_index, stock_cache_index)
        for (g, i) in enumerate(eachindex(entities))
            fs[i] = ForeignSector()
            pp[i] = PrincipalProduct(g)
            isupply[i] = ImportSupply(0.0)
            isales[i] = ImportSales(0.0)
            idemand[i] = ImportDemand(0.0)
            iprice[i] = ImportPrice(0.0)
            epi[i] = ExportPriceInflation(0.0)
            rowe[i] = RestOfWorldEntity(rotw)
            intermediary_cache_index[i] = IntermediaryDemandCacheIndex(0)
            stock_cache_index[i] = StockCacheIndex(0)

        end
    end

    return nothing
end
