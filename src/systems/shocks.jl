function apply_shocks!(world)
    apply_interest_rate_shock!(world)
    apply_productitvity_shock!(world)
    return nothing
end

function apply_interest_rate_shock!(world)
    time = Ark.get_resource(world, TimeIndex)
    for (e, interest_rate_shock) in Ark.Query(world, (InterestRateShock,))

        for i in eachindex(e)

            if (time.step <= interest_rate_shock[i].final_time)
                for (e_cb, cb_rate) in Ark.Query(world, (NominalInterestRate,))
                    for j in eachindex(e_cb)
                        cb_rate[j] = NominalInterestRate(interest_rate_shock[i].rate)
                    end
                end

            end
        end
    end

    return nothing
end

function apply_productitvity_shock!(world)

    for (e, productivity_shock) in Ark.Query(world, (ProductivityShock,))

        for i in eachindex(e)
            for (e_firm, labor_productivity) in Ark.Query(world, (LaborProductivity,))
                for j in eachindex(e_firm)
                    labor_productivity[j] = LaborProductivity(productivity_shock[i].productivity_multiplier * labor_productivity[j].rate)
                end
            end

        end
    end

    return nothing
end
