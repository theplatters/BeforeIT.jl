function setup_firms!(world::Ark.World, properties::Properties, markets)
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
    firm_owner_final_demand_offset =
        properties.population.active - total_firms - 1 + properties.population.inactive

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


    owners = Vector{Ark.Entity}(undef, total_firms)
    Ark.new_entities!(
        world, total_firms,
        (
            NetDisposableIncome, ConsumptionBudget, InvestmentBudget, ExpectedIncome,
            RealisedConsumption, RealisedInvestment, CapitalStock, Deposits, Capitalist,
            Household, FinalDemandCacheIndex,
        )
    ) do (entities, net_inc, cons_b, inv_b, exp_inc, real_cons, real_inv, cap_s, dep, cap_ist, hh, final_cache_index)
        for i in eachindex(entities)
            owners[i] = entities[i]
            net_inc[i] = disposable_income[i] |> NetDisposableIncome
            cons_b[i] = 0.0 |> ConsumptionBudget
            inv_b[i] = 0.0 |> InvestmentBudget
            exp_inc[i] = 0.0 |> ExpectedIncome
            real_cons[i] = 0.0 |> RealisedConsumption
            real_inv[i] = 0.0 |> RealisedInvestment
            cap_s[i] = K_h[i] |> CapitalStock
            dep[i] = D_h[i] |> Deposits
            cap_ist[i] = Capitalist()
            hh[i] = Household()
            final_cache_index[i] = firm_owner_final_demand_offset + i |> FinalDemandCacheIndex
        end
    end

    firm_offset = 0
    for g in 1:properties.dimensions.sectors
        Ark.new_entities!(
            world, firms_per_sector[g],
            (
                PrincipalProduct, LaborProductivity, IntermediateProductivity,
                CapitalProductivity, WageBill, AverageWageRate, CapitalDeprecationRate,
                TaxRates, Employment, Output, Sales, GoodsDemand, Price, Inventories,
                CapitalStock, Intermediates, LoansOutstanding, OperatingMargins,
                Deposits, Profits, Vacancies, Investment, Equity, PriceIndex, CFPriceIndex
                TargetLoans, ExpectedCapital, ExpectedLoans, ExpectedSales, DesiredInvestment,
                DesiredMaterials, DesiredEmployment, ExpectedProfits, FinalGoodsStockChange,
                MaterialsStockChange, LoanFlow, IntermediaryDemandCacheIndex, StockCacheIndex,
                Firm, Owner, Market => markets[g],
            )
        ) do (entities, pp, lp, ip, cp, wb, awr, cdr, tr, emp, out, sal, gd, pr, inv, cs, interm, lo, om, dep, prof, vac, invst, eq, pi, cfpi, tl, ec, el, es, di, dm, de, ep, fgsc, msc, lf, intermediary_cache_index, stock_cache_index, firm, owner, market)
            for i in eachindex(entities)
                firm_index = firm_offset + i
                pp[i] = principal_product[firm_index] |> PrincipalProduct
                lp[i] = output_elasticities[firm_index] |> LaborProductivity
                ip[i] = material_coeffs[firm_index] |> IntermediateProductivity
                cp[i] = capital_coeffs[firm_index] |> CapitalProductivity
                wb[i] = 0.0 |> WageBill
                awr[i] = wage_rate[firm_index] |> AverageWageRate
                cdr[i] = deprecation_rate[firm_index] |> CapitalDeprecationRate
                tr[i] = TaxRates(output_tax_rate[firm_index], capital_tax_rate[firm_index])
                emp[i] = employment[firm_index] |> Employment
                out[i] = output[firm_index] |> Output
                sal[i] = output[firm_index] |> Sales
                gd[i] = output[firm_index] |> GoodsDemand
                pr[i] = 1.0 |> Price
                inv[i] = 0.0 |> Inventories
                cs[i] = capital[firm_index] |> CapitalStock
                interm[i] = intermediates[firm_index] |> Intermediates
                lo[i] = outstanding_loans[firm_index] |> LoansOutstanding
                om[i] = operating_margins[firm_index] |> OperatingMargins
                dep[i] = deposits[firm_index] |> Deposits
                prof[i] = profits[firm_index] |> Profits
                vac[i] = employment[firm_index] |> Vacancies
                invst[i] = 0.0 |> Investment
                eq[i] = 0.0 |> Equity
                pi[i] = 0.0 |> PriceIndex
                cfpi[i] = 0.0 |> CFPriceIndex
                tl[i] = 0.0 |> TargetLoans
                ec[i] = 0.0 |> ExpectedCapital
                el[i] = 0.0 |> ExpectedLoans
                es[i] = 0.0 |> ExpectedSales
                di[i] = 0.0 |> DesiredInvestment
                dm[i] = 0.0 |> DesiredMaterials
                de[i] = 0.0 |> DesiredEmployment
                ep[i] = 0.0 |> ExpectedProfits
                fgsc[i] = 0.0 |> FinalGoodsStockChange
                msc[i] = 0.0 |> MaterialsStockChange
                lf[i] = 0.0 |> LoanFlow
                intermediary_cache_index[i] = firm_index |> IntermediaryDemandCacheIndex
                stock_cache_index[i] = i |> StockCacheIndex
                firm[i] = Firm()
                owner[i] = owners[firm_index] |> Owner
                market[i] = Market()
            end
        end
        firm_offset += firms_per_sector[g]
    end

    return nothing

end
