function setup_markets!(world::Ark.World, properties::Properties)

    consumers = properties.population.total + properties.dimensions.local_governments + properties.dimensions.foreign_consumers
    producers = properties.dimensions.firms_per_sector .+ 1

    Ark.new_entities!(
        world, properties.dimensions.sectors,
        (
            PrincipalProduct,
            FinalMarketDemandBook,
            FinalMarketDemandClearing,
            IntermediateMarketDemandBook,
            IntermediateMarketDemandClearing,
            MarketSupplyPool,
            MarketCapacityPool,
            MarketPricePool,
            MarketWeights,
            FinalDemandCursor,
            IntermediateDemandCursor,
            SupplyCursor,
        )
    ) do entities, sector, final_demand_book, final_demand_clearing, intermediate_demand_book, intermediate_demand_clearing, supply_pool, capacity_pool, price_pool, weights, final_demand_cursor, intermediate_demand_cursor, supply_cursor
        for i in eachindex(entities)
            sector[i] = PrincipalProduct(i)
            final_demand_book[i] = FinalMarketDemandBook(Vector{FloatType}(undef, consumers))
            final_demand_clearing[i] = FinalMarketDemandClearing(Vector{FloatType}(undef, consumers))
            intermediate_demand_book[i] = IntermediateMarketDemandBook(Vector{FloatType}(undef, properties.dimensions.total_firms))
            intermediate_demand_clearing[i] = IntermediateMarketDemandClearing(Vector{FloatType}(undef, properties.dimensions.total_firms))
            supply_pool[i] = MarketSupplyPool(Vector{FloatType}(undef, producers[i]))
            capacity_pool[i] = MarketSupplyPool(Vector{FloatType}(undef, producers[i]))
            price_pool[i] = MarketSupplyPool(Vector{FloatType}(undef, producers[i]))
            weights[i] = MarketWeights(Vector{FloatType}(undef, producers[i]))
            final_demand_cursor[i] = FinalDemandCursor(1)
            intermediate_demand_cursor[i] = IntermediateDemandCursor(1)
            supply_cursor[i] = SupplyCursor(1)
        end
    end


    return nothing
end
