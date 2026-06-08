function setup_aggregates!(world::Ark.World, properties::Properties)
    economy = properties.initial_conditions.economy


    Ark.add_resource!(
        world,
        TimeIndex(1)
    )

    Ark.add_resource!(
        world, properties
    )
    Ark.add_resource!(
        world,
        Shocks(
            0.0,                    # foreign_output_shock
            0.0,                    # export_demand_shock
            0.0
        )
    )

    Ark.add_resource!(world, FirmTmpBuffers{Float64}(zeros(properties.dimensions.sectors)))
    Ark.add_resource!(world, HiringFirmsCache(properties.dimensions.total_firms))
    Ark.add_resource!(world, WorkersCache(properties.population.active))
    Ark.add_resource!(world, FireEmployedWorkersCache(properties.population.active))
    Ark.add_resource!(
        world,
        HireWorkersCache(properties.population.active, properties.dimensions.total_firms)
    )
    Ark.add_resource!(world, CreditMatchingCache(properties.dimensions.total_firms))
    Ark.add_resource!(
        world,
        RetailRealisationCache(
            properties.population.total,
            properties.dimensions.foreign_consumers + properties.dimensions.local_governments,
            properties.dimensions.sectors,
        )
    )

    Ark.add_resource!(world, Epsilons(0.0, 0.0, 0.0))

    Ark.add_resource!(world, Expectations(0.0, 0.0, 0.0))
    Ark.add_resource!(world, DataCollector(properties))
    Ark.add_resource!(
        world, PriceIndices(
            ones(Float64, properties.dimensions.sectors), # sector price index
            1.0,                                           # aggregate_price_index
            1.0,                                           # household_consumption_price_index
            1.0,                                           # capital_goods_price_index
            1.0,                                           # household_consumption_price_index_previous
            1.0,                                           # capital_goods_price_index_previous
        )
    )
    Ark.add_resource!(
        world,
        MacroeconomicState(
            copy(economy.total_output),                    # gross_domestic_product_history
            copy(economy.inflation),                       # inflation_history
        )
    )
    return nothing

end
