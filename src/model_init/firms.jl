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


    owners = Vector{Ark.Entity}(undef, total_firms)
    Ark.new_entities!(
        world, total_firms,
        (
            NetDisposableIncome,
            ConsumptionBudget,
            InvestmentBudget,
            ExpectedIncome,
            RealisedConsumption,
            RealisedInvestment,
            CapitalStock,
            Deposits,
            Capitalist,
            Household,
            FinalDemandCacheIndex,
        )
    ) do (entities, net_inc, cons_b, inv_b, exp_inc, real_cons, real_inv, cap_s, dep, cap_ist, hh, final_cache_index)
        for i in eachindex(entities)
            owners[i] = entities[i]
            net_inc[i] = NetDisposableIncome(disposable_income[i])
            cons_b[i] = ConsumptionBudget(0.0)
            inv_b[i] = InvestmentBudget(0.0)
            exp_inc[i] = ExpectedIncome(0.0)
            real_cons[i] = RealisedConsumption(0.0)
            real_inv[i] = RealisedInvestment(0.0)
            cap_s[i] = CapitalStock(K_h[i])
            dep[i] = Deposits(D_h[i])
            cap_ist[i] = Capitalist()
            hh[i] = Household()
            final_cache_index[i] = FinalDemandCacheIndex(0)
        end
    end

    firms = Vector{Ark.Entity}(undef, total_firms)
    Ark.new_entities!(
        world, total_firms,
        (
            PrincipalProduct,
            LaborProductivity,
            IntermediateProductivity,
            CapitalProductivity,
            WageBill,
            AverageWageRate,
            CapitalDeprecationRate,
            TaxRates,
            Employment,
            Output,
            Sales,
            GoodsDemand,
            Price,
            Inventories,
            CapitalStock,
            Intermediates,
            LoansOutstanding,
            OperatingMargins,
            Deposits,
            Profits,
            Vacancies,
            Investment,
            Equity,
            PriceIndex,
            CFPriceIndex,
            TargetLoans,
            ExpectedCapital,
            ExpectedLoans,
            ExpectedSales,
            DesiredInvestment,
            DesiredMaterials,
            DesiredEmployment,
            ExpectedProfits,
            FinalGoodsStockChange,
            MaterialsStockChange,
            LoanFlow,
            Firm,
            IntermediaryDemandCacheIndex,
            StockCacheIndex,
            Owner,
        )
    ) do (entities, pp, lp, ip, cp, wb, awr, cdr, tr, emp, out, sal, gd, pr, inv, cs, interm, lo, om, dep, prof, vac, invst, eq, pi, cfpi, tl, ec, el, es, di, dm, de, ep, fgsc, msc, lf, firm, intermediary_cache_index, stock_cache_index, owner)
        for i in eachindex(entities)
            firms[i] = entities[i]
            pp[i] = PrincipalProduct(principal_product[i])
            lp[i] = LaborProductivity(output_elasticities[i])
            ip[i] = IntermediateProductivity(material_coeffs[i])
            cp[i] = CapitalProductivity(capital_coeffs[i])
            wb[i] = WageBill(0.0)
            awr[i] = AverageWageRate(wage_rate[i])
            cdr[i] = CapitalDeprecationRate(deprecation_rate[i])
            tr[i] = TaxRates(output_tax_rate[i], capital_tax_rate[i])
            emp[i] = Employment(employment[i])
            out[i] = Output(output[i])
            sal[i] = Sales(output[i])
            gd[i] = GoodsDemand(output[i])
            pr[i] = Price(1.0)
            inv[i] = Inventories(0.0)
            cs[i] = CapitalStock(capital[i])
            interm[i] = Intermediates(intermediates[i])
            lo[i] = LoansOutstanding(outstanding_loans[i])
            om[i] = OperatingMargins(operating_margins[i])
            dep[i] = Deposits(deposits[i])
            prof[i] = Profits(profits[i])
            vac[i] = Vacancies(employment[i])
            invst[i] = Investment(0.0)
            eq[i] = Equity(0.0)
            pi[i] = PriceIndex(0.0)
            cfpi[i] = CFPriceIndex(0.0)
            tl[i] = TargetLoans(0.0)
            ec[i] = ExpectedCapital(0.0)
            el[i] = ExpectedLoans(0.0)
            es[i] = ExpectedSales(0.0)
            di[i] = DesiredInvestment(0.0)
            dm[i] = DesiredMaterials(0.0)
            de[i] = DesiredEmployment(0.0)
            ep[i] = ExpectedProfits(0.0)
            fgsc[i] = FinalGoodsStockChange(0.0)
            msc[i] = MaterialsStockChange(0.0)
            lf[i] = LoanFlow(0.0)
            firm[i] = Firm()
            intermediary_cache_index[i] = IntermediaryDemandCacheIndex(0)
            stock_cache_index[i] = StockCacheIndex(0)
            owner[i] = Owner(owners[i])
        end
    end

    return nothing

end
