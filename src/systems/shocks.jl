function apply_shocks!(world)
    apply_interest_rate_shock!(world)
    apply_productitvity_shock!(world)
    apply_consumption_shock!(world)
    return nothing
end

function apply_interest_rate_shock!(world)
    time = Ark.get_resource(world, TimeIndex)
    for comps in Ark.Query(world, (InterestRateShock,))
        e, interest_rate_shock = comps

        for i in eachindex(e)

            if (time.step <= interest_rate_shock[i].final_time)
                for comps in Ark.Query(world, (NominalInterestRate,))
                    e_cb, cb_rate = comps
                    for j in eachindex(e_cb)
                        cb_rate[j] = interest_rate_shock[i].rate |> NominalInterestRate
                    end
                end

            end
        end
    end

    return nothing
end

function apply_productitvity_shock!(world)

    for comps in Ark.Query(world, (ProductivityShock,))
        e, productivity_shock = comps

        for i in eachindex(e)
            for comps in Ark.Query(world, (LaborProductivity,))
                e_firm, labor_productivity = comps
                for j in eachindex(e_firm)
                    labor_productivity[j] = productivity_shock[i].productivity_multiplier * labor_productivity[j].rate |> LaborProductivity
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
    for comps in Ark.Query(world, (ConsumptionShock,))
        e, interest_rate_shock = comps

        for i in eachindex(e)

            if (time == 1)
                rate = rate * interest_rate_shock[i].consumption_multiplier
            elseif (time == 1)
                rate = rate * interest_rate_shock[i].consumption_multiplier
            end
        end
    end
    Ark.set_resource!(world, update_household_consumption(properties, rate))

    return nothing
end

function add_shock!(model, shock_type)
    return Ark.new_entity!(model.world, (Shock(), shock_type))
end
