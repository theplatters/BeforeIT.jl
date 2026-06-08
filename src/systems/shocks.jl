function apply_shocks!(world)
    apply_interest_rate_shock!(world)
    apply_productitvity_shock!(world)
    apply_consumption_shock!(world)
    return nothing
end

function apply_interest_rate_shock!(world)
    time = Ark.get_resource(world, TimeIndex)
    @dub for shock_row in Ark.Query(world, (InterestRateShock,))
        for i in eachindex(shock_row.e)

            if (time.step <= shock_row.interest_rate_shock[i].final_time)
                @dub for row in Ark.Query(world, (NominalInterestRate,))                    for j in eachindex(row.e)
                        row.nominal_interest_rate[j] = shock_row.interest_rate_shock[i].rate |> NominalInterestRate
                    end
                end

            end
        end
    end

    return nothing
end

function apply_productitvity_shock!(world)

    @dub for shock_row in Ark.Query(world, (ProductivityShock,))
        for i in eachindex(shock_row.e)
            @dub for row in Ark.Query(world, (LaborProductivity,))                for j in eachindex(row.e)
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
    @dub for row in Ark.Query(world, (ConsumptionShock,))
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
