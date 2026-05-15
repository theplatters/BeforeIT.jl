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

    Ark.new_entities!(world, local_governments, (ConsumptionDemand(0.0), LocalGovernment() => e))
    return nothing
end
