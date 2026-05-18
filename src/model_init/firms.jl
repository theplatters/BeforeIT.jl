function setup_firms!(world::Ark.World, properties::Properties)
    (; total_firms, firms_per_sector) = properties.dimensions

    tau_SIF = properties.social_insurance.employers_contribution
    mu = properties.banking_params.risk_premium
    theta_DIV = properties.banking_params.dividend_payout_ratio

    tau_INC = properties.tax_rates.income
    tau_FIRM = properties.tax_rates.corporate

    sb_other = properties.initial_conditions.government.subsidies_other
    r_bar = properties.initial_conditions.banking.policy_rate

    (; total_debt, total_loans) = properties.initial_conditions.firms

    omega = properties.initial_conditions.firms.capacity_utilization

    D_H = properties.initial_conditions.households.debt
    K_H = properties.initial_conditions.households.capital

    sectoral_employment = round.(Int, properties.initial_conditions.sectors.employment)
    principal_product = reduce(vcat, [fill(g, firms_per_sector[g]) for g in 1:properties.dimensions.sectors])

    sectoral_params = properties.sectoral_params

    output_elasticities = sectoral_params.output_elasticity[principal_product]
    material_coeffs = sectoral_params.material_coefficient[principal_product]
    capital_coeffs = sectoral_params.capital_coefficient[principal_product]
    deprecation_rate = sectoral_params.depreciation_rate[principal_product]
    wage_rate = sectoral_params.wage_rate[principal_product]

    output_tax_rate = properties.sector_tax_rates.output[principal_product]
    capital_tax_rate = properties.sector_tax_rates.capital[principal_product]

    employment = Vector{Int}(undef, total_firms)
    for g in 1:properties.dimensions.sectors
        employment[principal_product .== g] .= randpl(firms_per_sector[g], 2.0, sectoral_employment[g])
    end

    output = output_elasticities .* employment


    capital = output ./ (omega .* capital_coeffs)
    intermediates = output ./ (omega .* material_coeffs)
    outstanding_loans = total_loans .* capital / sum(capital)

    operating_margins = 1 .- (1 + tau_SIF) .* wage_rate ./ output_elasticities .- deprecation_rate ./ capital_coeffs .- 1 ./ material_coeffs .- capital_tax_rate .- output_tax_rate
    deposits = total_debt .* max.(0, operating_margins .* output) / sum(max.(0, operating_margins .* output))

    r = r_bar + mu
    profits = operating_margins .* output - r .* outstanding_loans + r_bar .* max.(0, deposits)


    P_bar_HH = one(Float64)
    after_tax_profits = max.(0, profits) .* (1 - tau_INC) .* (1 - tau_FIRM)
    dividends = theta_DIV .* after_tax_profits
    subsidies = sb_other * P_bar_HH
    disposable_income = dividends .+ subsidies
    K_h = K_H * disposable_income
    D_h = D_H * disposable_income


    #TODO: Replace this with a batch entity creation
    for i in 1:total_firms
        owner = Ark.new_entity!(
            world,
            (
                NetDisposableIncome(disposable_income[i]),
                ConsumptionBudget(0.0),
                InvestmentBudget(0.0),
                ExpectedIncome(0.0),
                RealisedConsumption(0.0),
                RealisedInvestment(0.0),
                CapitalStock(K_h[i]),
                Deposits(D_h[i]),
                Capitalist(),
                Household(),
            )
        )
        Ark.new_entity!(
            world,
            (
                PrincipalProduct(principal_product[i]),
                LaborProductivity(output_elasticities[i]),
                IntermediateProductivity(material_coeffs[i]),
                CapitalProductivity(capital_coeffs[i]),
                WageBill(0.0),
                AverageWageRate(wage_rate[i]),
                CapitalDeprecationRate(deprecation_rate[i]),
                TaxRates(output_tax_rate[i], capital_tax_rate[i]),
                Employment(employment[i]),
                Output(output[i]),
                Sales(output[i]),
                GoodsDemand(output[i]),
                Price(1.0),
                Inventories(0.0),
                CapitalStock(capital[i]),
                Intermediates(intermediates[i]),
                LoansOutstanding(outstanding_loans[i]),
                OperatingMargins(operating_margins[i]),
                Deposits(deposits[i]),
                Profits(profits[i]),
                Vacancies(employment[i]),
                Investment(0.0),
                Equity(0.0),
                PriceIndex(0.0),
                CFPriceIndex(0.0),
                TargetLoans(0.0),
                ExpectedCapital(0.0),
                ExpectedLoans(0.0),
                ExpectedSales(0.0),
                DesiredInvestment(0.0),
                DesiredMaterials(0.0),
                DesiredEmployment(0.0),
                ExpectedProfits(0.0),
                FinalGoodsStockChange(0.0),
                MaterialsStockChange(0.0),
                LoanFlow(0.0),
                Owner() => owner,
                Firm(),
            )
        )
    end

    return nothing

end
