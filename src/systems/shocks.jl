function apply_shocks!(world)
    apply_interest_rate_shock!(world)
    apply_productitvity_shock!(world)
    apply_consumption_shock!(world)
    return nothing
end

function apply_interest_rate_shock!(world)
    time = Ark.get_resource(world, TimeIndex)
    for comps in Ark.Query(world, (InterestRateShock,))
        shock_row = query_row(comps)

        for i in eachindex(shock_row.e)

            if (time.step <= shock_row.interest_rate_shock[i].final_time)
                for comps in Ark.Query(world, (NominalInterestRate,))
                    row = query_row(comps)
                    for j in eachindex(row.e)
                        row.nominal_interest_rate[j] = shock_row.interest_rate_shock[i].rate |> NominalInterestRate
                    end
                end

            end
        end
    end

    return nothing
end

function apply_productitvity_shock!(world)

    for comps in Ark.Query(world, (ProductivityShock,))
        shock_row = query_row(comps)

        for i in eachindex(shock_row.e)
            for comps in Ark.Query(world, (LaborProductivity,))
                row = query_row(comps)
                for j in eachindex(row.e)
                    row.labor_productivity[j] = (
                        shock_row.productivity_shock[i].productivity_multiplier *
                            row.labor_productivity[j].rate
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
    for comps in Ark.Query(world, (ConsumptionShock,))
        row = query_row(comps)

        for i in eachindex(row.e)

            if (time == 1)
                rate = rate * row.consumption_shock[i].consumption_multiplier
            elseif (time == 1)
                rate = rate * row.consumption_shock[i].consumption_multiplier
            end
        end
    end
    Ark.set_resource!(world, update_household_consumption(properties, rate))

    return nothing
end

function add_shock!(model, shock_type)
    return Ark.new_entity!(model.world, (Shock(), shock_type))
end
