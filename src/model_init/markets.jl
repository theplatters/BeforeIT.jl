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
            sector[i] = i |> PrincipalProduct
            final_demand_book[i] = Vector{FloatType}(undef, consumers) |> FinalMarketDemandBook
            final_demand_clearing[i] = Vector{FloatType}(undef, consumers) |> FinalMarketDemandClearing
            intermediate_demand_book[i] = Vector{FloatType}(undef, properties.dimensions.total_firms) |> IntermediateMarketDemandBook
            intermediate_demand_clearing[i] = Vector{FloatType}(undef, properties.dimensions.total_firms) |> IntermediateMarketDemandClearing
            first_pass_intermediate[i] = Vector{FloatType}(undef, properties.dimensions.total_firms) |> FirstPassIntermediateDemand
            first_pass_final[i] = Vector{FloatType}(undef, consumers) |> FirstPassFinalDemand
            supply_pool[i] = Vector{FloatType}(undef, producers[i]) |> MarketSupplyPool
            capacity_pool[i] = Vector{FloatType}(undef, producers[i]) |> MarketCapacityPool
            price_pool[i] = Vector{FloatType}(undef, producers[i]) |> MarketPricePool
            weights[i] = Vector{FloatType}(undef, producers[i]) |> MarketWeights
            weight_vector[i] = FixedSizeWeightVector(producers[i]) |> MarketWeightVector
            active[i] = (
                Vector{Int}(
                    undef,
                    max(consumers, maximum(producers))
                )
            ) |> ActiveBuyers
            push!(markets, entities[i])

        end
    end


    return markets
end
