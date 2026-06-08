function setup_government!(world, properties::Properties)::Nothing
    (; consumption, debt, subsidies_inactive, subsidies_other) = properties.initial_conditions.government
    T_prime = properties.dimensions.interval_for_expectation_estimation
    local_governments = properties.dimensions.local_governments


    e = Ark.new_entity!(
        world, (
            GovernmentRevenues(0.0),
            ConsumptionDemand(consumption[T_prime]),
            RealisedConsumption(0.0),
            GovernmentDebt(debt),
            SocialBenefitsInactive(subsidies_inactive),
            SocialBenefitsOther(subsidies_other),
            PriceInflationGovernmentGoods(0.0),
            Government(),

        )
    )

    final_demand_offset = properties.population.total + properties.dimensions.foreign_consumers
    Ark.new_entities!(world, local_governments, (ConsumptionDemand, FinalDemandCacheIndex, LocalGovernment => e)) do (entities, consumption_demand, final_cache_index, local_government)
        for i in eachindex(entities)
            consumption_demand[i] = 0.0 |> ConsumptionDemand
            final_cache_index[i] = final_demand_offset + i |> FinalDemandCacheIndex
            local_government[i] = LocalGovernment()
        end
    end
    return nothing
end
