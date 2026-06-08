function set_gov_expenditure!(world::Ark.World)
    prop = properties(world)
    expect = expectations(world)
    price_indices = BeforeIT.price_indices(world)

    c_G_g = prop.product_coeffs.government_consumption
    P_bar_g = price_indices.sector
    pi_e = expect.inflation

    local_governments = prop.dimensions.local_governments
    (; consumption_autoregression, consumption_autoregression_scalar, consumption_shock_sd) = prop.fiscal_policy
    epsilon_G = consumption_shock_sd .* randn()

    nominal_sector_demand = dot(P_bar_g, c_G_g)
    for comps in Ark.Query(world, (ConsumptionDemand,), with = (Government,))
        row = query_row(comps)
        for i in eachindex(row.e)

            row.consumption_demand[i] = (
                exp(consumption_autoregression .* log(row.consumption_demand[i].amount) + consumption_autoregression_scalar + epsilon_G)
            ) |> ConsumptionDemand
            for comps in Ark.Query(world, (ConsumptionDemand,), with = (LocalGovernment => row.e[i],))
                local_row = query_row(comps)
                local_row.consumption_demand.amount .= row.consumption_demand[i].amount ./ local_governments .* nominal_sector_demand .* (1 .+ pi_e)
            end
        end

    end

    return nothing
end


function set_gov_revenues!(world::Ark.World)

    prop = properties(world)

    taxes = prop.tax_rates
    τ_income = taxes.income
    τ_vat = taxes.value_added
    τ_firm = taxes.corporate
    τ_cf = taxes.capital_formation
    θ_div = prop.banking_params.dividend_payout_ratio

    (; employers_contribution, employees_contribution) = prop.social_insurance

    cpi = Ark.get_resource(world, PriceIndices).household_consumption

    total_wages = @sum_over (w.rate for  w in Ark.Query(world, (Employed,)))
    total_consumption = 0.0
    for comps in Ark.Query(world, (RealisedConsumption,), with = (Household,))
        row = query_row(comps)
        total_consumption += sum(row.realised_consumption.amount)
    end

    total_investment = 0.0
    for comps in Ark.Query(world, (RealisedInvestment,), with = (Household,))
        row = query_row(comps)
        total_investment += sum(row.realised_investment.amount)
    end
    total_firm_profits = 0.0
    for comps in Ark.Query(world, (Profits,), with = (Firm,))
        row = query_row(comps)
        total_firm_profits += sum(max(0, profit.amount) for profit in row.profits)
    end

    total_bank_profits = 0.0
    for comps in Ark.Query(world, (Profits,), with = (Bank,))
        row = query_row(comps)
        total_bank_profits += sum(max(0, profit.amount) for profit in row.profits)
    end
    total_profits = total_firm_profits + total_bank_profits

    social_security = (employees_contribution + employers_contribution) * total_wages * cpi
    labor_income = τ_income * (1 - employees_contribution) * cpi * total_wages
    value_added = τ_vat * total_consumption
    capital_income = τ_income * (1 - τ_firm) * θ_div * total_profits
    corporate_income = τ_firm * total_profits
    capital_formation = τ_cf * total_investment

    products = 0.0
    production = 0.0
    for comps in Ark.Query(world, (Output, Price, TaxRates))
        row = query_row(comps)
        for i in eachindex(row.e)
            products += row.output[i].amount * row.price[i].value * row.tax_rates[i].output
            production += row.output[i].amount * row.price[i].value * row.tax_rates[i].capital
        end
    end

    τ_export = prop.tax_rates.exports # or matching property name
    exports = @sum_over (
        x.amount for x in Ark.Query(world, (ForeignConsumption,))
    )

    export_tax = τ_export * exports


    for comps in Ark.Query(world, (GovernmentRevenues,))
        row = query_row(comps)
        for i in eachindex(row.e)
            row.government_revenues[i] = (
                social_security
                    + labor_income
                    + value_added
                    + capital_income
                    + capital_formation
                    + products
                    + production
                    + corporate_income
                    + export_tax
            ) |> GovernmentRevenues
        end
    end
    return nothing
end

function set_gov_loans!(world::Ark.World)
    cpi = Ark.get_resource(world, PriceIndices).household_consumption
    properties = Ark.get_resource(world, Properties)
    (; total, inactive) = properties.population
    theta_UB = properties.social_insurance.unemployment_benefit
    r_g = properties.fiscal_policy.government_interest_rate

    total_wages_unemployed = @sum_over (w.unemployment_benefits for  w in Ark.Query(world, (Unemployed,)))
    for comps in Ark.Query(world, (SocialBenefitsInactive, SocialBenefitsOther, GovernmentDebt, RealisedConsumption, GovernmentRevenues))
        row = query_row(comps)
        for i in eachindex(row.e)
            social_benefits = cpi * (inactive * row.social_benefits_inactive[i].amount + theta_UB * total_wages_unemployed + total * row.social_benefits_other[i].amount)
            row.government_debt[i] = (row.government_debt[i].amount + social_benefits + row.realised_consumption[i].amount + r_g * row.government_debt[i].amount - row.government_revenues[i].amount) |> GovernmentDebt
        end
    end


    return nothing
end

function set_gov_social_benefits!(world::Ark.World)
    expected_growth = BeforeIT.expectations(world).output_growth

    for comps in Ark.Query(world, (SocialBenefitsInactive, SocialBenefitsOther, GovernmentDebt))
        row = query_row(comps)
        row.social_benefits_inactive.amount .*= (1 + expected_growth)
        row.social_benefits_other.amount .*= (1 + expected_growth)

    end
    return nothing
end
