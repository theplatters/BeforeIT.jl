function setup_markets!(world::Ark.World, properties::Properties)

    consumers = properties.population.total + properties.dimensions.local_governments + properties.dimensions.foreign_consumers
    producers = properties.dimensions.firms_per_sector .+ 1
    markets = Ark.Entity[]
    Ark.new_entities!(
        world, properties.dimensions.sectors,
        (
            PrincipalProduct,
            FinalMarketDemandBook,
            FinalMarketDemandClearing,
            IntermediateMarketDemandBook,
            IntermediateMarketDemandClearing,
            FirstPassIntermediateDemand,
            FirstPassFinalDemand,
            MarketSupplyPool,
            MarketCapacityPool,
            MarketPricePool,
            MarketWeights,
            MarketWeightVector,
            ActiveBuyers,
        )
    ) do (entities, sector, final_demand_book, final_demand_clearing, intermediate_demand_book, intermediate_demand_clearing, first_pass_intermediate, first_pass_final, supply_pool, capacity_pool, price_pool, weights, weight_vector, active)
        for i in eachindex(entities)
            sector[i] = PrincipalProduct(i)
            final_demand_book[i] = FinalMarketDemandBook(Vector{FloatType}(undef, consumers))
            final_demand_clearing[i] = FinalMarketDemandClearing(Vector{FloatType}(undef, consumers))
            intermediate_demand_book[i] = IntermediateMarketDemandBook(Vector{FloatType}(undef, properties.dimensions.total_firms))
            intermediate_demand_clearing[i] = IntermediateMarketDemandClearing(Vector{FloatType}(undef, properties.dimensions.total_firms))
            first_pass_intermediate[i] = FirstPassIntermediateDemand(Vector{FloatType}(undef, properties.dimensions.total_firms))
            first_pass_final[i] = FirstPassFinalDemand(Vector{FloatType}(undef, consumers))
            supply_pool[i] = MarketSupplyPool(Vector{FloatType}(undef, producers[i]))
            capacity_pool[i] = MarketCapacityPool(Vector{FloatType}(undef, producers[i]))
            price_pool[i] = MarketPricePool(Vector{FloatType}(undef, producers[i]))
            weights[i] = MarketWeights(Vector{FloatType}(undef, producers[i]))
            weight_vector[i] = MarketWeightVector(FixedSizeWeightVector(producers[i]))
            active[i] = ActiveBuyers(
                Vector{Int}(
                    undef,
                    max(consumers, maximum(producers))
                )
            )
            push!(markets, entities[i])

        end
    end


    return markets
end
