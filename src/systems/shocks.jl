function apply_shocks!(world)
    apply_interest_rate_shock!(world)
    apply_productitvity_shock!(world)
    apply_consumption_shock!(world)
    return nothing
end

function apply_interest_rate_shock!(world)
    time = Ark.get_resource(world, TimeIndex)
    @dub for t in Ark.Query(world, (InterestRateShock,))
        for i in eachindex(t.e)
            if (time.step <= t.interest_rate_shock[i].final_time)
                for t2 in Ark.Query(world, (NominalInterestRate,))
                    for j in eachindex(t2.e)
                        t2.nominal_interest_rate[j] = t.interest_rate_shock[i].rate |> NominalInterestRate
                    end
                end
            end
        end
    end

    return nothing
end

function apply_productitvity_shock!(world)
    @dub for t in Ark.Query(world, (ProductivityShock,))
        for i in eachindex(t.e)
            for t2 in Ark.Query(world, (LaborProductivity,))
                for j in eachindex(t2.e)
                    t2.labor_productivity[j] = (
                        t.productivity_shock[i].productivity_multiplier *
                            t2.labor_productivity[j].rate
                    ) |> LaborProductivity
                end
            end
        end
    end

    return nothing
end

function apply_consumption_shock!(world)
    time = Ark.get_resource(world, TimeIndex)
    properties = BeforeIT.properties(world)
    rate = properties.household_params.consumption_share
    @dub for t in Ark.Query(world, (ConsumptionShock,))
        for i in eachindex(t.e)
            rate *= t.consumption_shock[i].consumption_multiplier
        end
    end
    Ark.set_resource!(world, update_household_consumption(properties, rate))

    return nothing
end

function add_shock!(model, shock_type)
    return Ark.new_entity!(model.world, (Shock(), shock_type))
end
