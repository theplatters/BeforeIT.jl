# src/systems/data_collection.jl

function collect_data!(model::AbstractModel)
    return collect_data!(model.world)
end

function collect_data!(world::Ark.World)
    history = Ark.get_resource(world, DataCollector)
    t_resource = Ark.get_resource(world, TimeIndex)
    t = t_resource.step
    props = BeforeIT.properties(world)

    push!(history.collection_time, t)

    # Cache some values
    τ_VAT = props.tax_rates.value_added
    τ_CF = props.tax_rates.capital_formation
    τ_G = props.tax_rates.government_consumption
    τ_EXPORT = props.tax_rates.exports
    τ_SIF = props.social_insurance.employers_contribution

    indices = BeforeIT.price_indices(world)
    P_bar_h = indices.household_consumption
    P_bar_CF_h = indices.capital_formation_households

    # Aggregates
    tot_C_h = 0.0
    tot_I_h = 0.0
    for (_, c, i) in Ark.Query(world, (Components.RealisedConsumption, Components.RealisedInvestment), with = (Components.Household,))
        tot_C_h += sum(c.amount)
        tot_I_h += sum(i.amount)
    end


    gov_P_j = 0.0
    gov_C_j = 0.0
    gov_count = 0
    for (_, p_j, c_j) in Ark.Query(world, (Components.PriceInflationGovernmentGoods, Components.RealisedConsumption), with = (Components.Government,))
        gov_P_j += sum(p_j.value)
        gov_C_j += sum(c_j.amount)
        gov_count += length(p_j.value)
    end
    gov_P_j = gov_count > 0 ? gov_P_j / gov_count : 1.0

    # ROTW
    rotw_C_l = 0.0
    for (_, c) in Ark.Query(world, (Components.ForeignConsumption,))
        rotw_C_l += sum(c.amount)
    end
    rotw_P_l = 0.0
    rotw_count = 0
    for (_, p_l) in Ark.Query(world, (Components.EuroAreaInflation,))
        rotw_P_l += sum(p_l.rate)
        rotw_count += length(p_l.rate)
    end
    rotw_P_l = rotw_count > 0 ? rotw_P_l / rotw_count : 1.0

    # Firms
    nominal_output_tax = 0.0
    real_output_tax = 0.0
    for (_, tau, y, p) in Ark.Query(world, (Components.TaxRates, Components.Output, Components.Price))
        nominal_output_tax += sum(tau.output .* y.amount .* p.value)
        real_output_tax += sum(tau.output .* y.amount)
    end

    nominal_gva_at_basic_prices = 0.0
    for (_, tau, p, y, beta, p_bar) in Ark.Query(world, (Components.TaxRates, Components.Price, Components.Output, Components.IntermediateProductivity, Components.PriceIndex))
        nominal_gva_at_basic_prices += sum((1.0 .- tau.output) .* p.value .* y.amount .- 1.0 ./ beta.value .* p_bar.value .* y.amount)
    end

    real_gva_at_basic_prices = 0.0
    for (_, y, tau, beta) in Ark.Query(world, (Components.Output, Components.TaxRates, Components.IntermediateProductivity))
        real_gva_at_basic_prices += sum(y.amount .* ((1.0 .- tau.output) .- 1.0 ./ beta.value))
    end

    # GDP
    push!(
        history.nominal_gdp, nominal_output_tax +
            τ_VAT * tot_C_h +
            τ_CF * tot_I_h +
            τ_G * gov_C_j +
            τ_EXPORT * rotw_C_l +
            nominal_gva_at_basic_prices
    )

    push!(
        history.real_gdp, real_gva_at_basic_prices +
            real_output_tax +
            τ_VAT * tot_C_h / P_bar_h +
            τ_CF * tot_I_h / P_bar_CF_h +
            τ_G * gov_C_j / gov_P_j +
            τ_EXPORT * rotw_C_l / rotw_P_l
    )

    # GVA
    push!(history.nominal_gva, nominal_gva_at_basic_prices)
    push!(history.real_gva, real_gva_at_basic_prices)

    # Consumption
    push!(history.nominal_household_consumption, (1.0 + τ_VAT) * tot_C_h)
    push!(history.real_household_consumption, (1.0 + τ_VAT) * tot_C_h / P_bar_h)
    push!(history.nominal_government_consumption, (1.0 + τ_G) * gov_C_j)
    push!(history.real_government_consumption, (1.0 + τ_G) * gov_C_j / gov_P_j)

    # Capital Formation
    nominal_firm_inv = 0.0
    for (_, p_cf, i) in Ark.Query(world, (Components.CFPriceIndex, Components.Investment))
        nominal_firm_inv += sum(p_cf.value .* i.amount)
    end
    real_firm_inv = 0.0
    for (_, i) in Ark.Query(world, (Components.Investment,))
        real_firm_inv += sum(i.amount)
    end

    nominal_stock_change = 0.0
    for (_, ds, p) in Ark.Query(world, (Components.FinalGoodsStockChange, Components.Price))
        nominal_stock_change += sum(ds.amount .* p.value)
    end
    nominal_material_stock_adj = 0.0
    for (_, dm, p_bar, beta, y) in Ark.Query(world, (Components.MaterialsStockChange, Components.PriceIndex, Components.IntermediateProductivity, Components.Output))
        nominal_material_stock_adj += sum(dm.amount .* p_bar.value .- 1.0 ./ beta.value .* p_bar.value .* y.amount)
    end

    push!(history.nominal_capitalformation, nominal_firm_inv + (1.0 + τ_CF) * tot_I_h + nominal_stock_change + nominal_material_stock_adj)

    real_material_stock_adj = 0.0
    for (_, dm, y, beta) in Ark.Query(world, (Components.MaterialsStockChange, Components.Output, Components.IntermediateProductivity))
        real_material_stock_adj += sum(dm.amount .- y.amount ./ beta.value)
    end
    real_final_goods_stock_change = 0.0
    for (_, ds) in Ark.Query(world, (Components.FinalGoodsStockChange,))
        real_final_goods_stock_change += sum(ds.amount)
    end

    push!(
        history.real_capitalformation, real_firm_inv + (1.0 + τ_CF) * tot_I_h / P_bar_CF_h +
            real_material_stock_adj + real_final_goods_stock_change
    )

    push!(history.nominal_fixed_capitalformation, nominal_firm_inv + (1.0 + τ_CF) * tot_I_h)
    push!(history.real_fixed_capitalformation, real_firm_inv + (1.0 + τ_CF) * tot_I_h / P_bar_CF_h)

    push!(history.nominal_fixed_capitalformation_dwellings, (1.0 + τ_CF) * tot_I_h)
    push!(history.real_fixed_capitalformation_dwellings, (1.0 + τ_CF) * tot_I_h / P_bar_CF_h)

    # Exports / Imports
    push!(history.nominal_exports, (1.0 + τ_EXPORT) * rotw_C_l)
    push!(history.real_exports, (1.0 + τ_EXPORT) * rotw_C_l / rotw_P_l)

    nom_imp = 0.0
    for (_, p_m, q_m) in Ark.Query(world, (Components.ImportPrice, Components.ImportSales))
        nom_imp += sum(p_m.value .* q_m.amount)
    end
    push!(history.nominal_imports, nom_imp)

    real_imp = 0.0
    for (_, q_m) in Ark.Query(world, (Components.ImportSales,))
        real_imp += sum(q_m.amount)
    end
    push!(history.real_imports, real_imp)

    # OS / Wages / Taxes
    wages_val_acc = 0.0
    for (_, w_bar, n) in Ark.Query(world, (Components.AverageWageRate, Components.Employment))
        wages_val_acc += sum(w_bar.rate .* n.amount)
    end
    wages_val = wages_val_acc * P_bar_h
    push!(history.wages, wages_val)
    push!(history.compensation_employees, (1.0 + τ_SIF) * wages_val)

    taxes_prod = 0.0
    for (_, tau, y, p) in Ark.Query(world, (Components.TaxRates, Components.Output, Components.Price))
        taxes_prod += sum(tau.capital .* y.amount .* p.value)
    end
    push!(history.taxes_production, taxes_prod)

    op_surplus = 0.0
    for (_, p, q, ds, w_bar, n, beta, p_bar, tau, y) in Ark.Query(world, (Components.Price, Components.Sales, Components.FinalGoodsStockChange, Components.AverageWageRate, Components.Employment, Components.IntermediateProductivity, Components.PriceIndex, Components.TaxRates, Components.Output))
        op_surplus += sum(
            p.value .* q.amount .+ p.value .* ds.amount .-
                (1.0 + τ_SIF) .* w_bar.rate .* n.amount .* P_bar_h .-
                1.0 ./ beta.value .* p_bar.value .* y.amount .-
                tau.output .* p.value .* y.amount .-
                tau.capital .* p.value .* y.amount
        )
    end
    push!(history.operating_surplus, op_surplus)

    # External
    (_, cb_euribor) = single(Ark.Query(world, (Components.NominalInterestRate,)))
    push!(history.euribor, cb_euribor.rate)
    push!(history.gdp_deflator_growth_ea, rotw_P_l) # This is pi_EA

    real_gdp_ea = 0.0
    for (_, y_ea) in Ark.Query(world, (Components.EuroAreaGDP,))
        real_gdp_ea += sum(y_ea.value)
    end
    push!(history.real_gdp_ea, real_gdp_ea)

    # Sectoral GVA
    nom_sector_gva = zeros(props.dimensions.sectors)
    real_sector_gva = zeros(props.dimensions.sectors)
    for g in 1:props.dimensions.sectors
        nom_gva_g = 0.0
        real_gva_g = 0.0
        for (_, pp, tau, p, y, beta, p_bar) in Ark.Query(world, (Components.PrincipalProduct, Components.TaxRates, Components.Price, Components.Output, Components.IntermediateProductivity, Components.PriceIndex))
            mask = pp.id .== g
            nom_gva_g += sum(mask .* ((1.0 .- tau.output) .* p.value .* y.amount .- 1.0 ./ beta.value .* p_bar.value .* y.amount))
            real_gva_g += sum(mask .* (y.amount .* ((1.0 .- tau.output) .- 1.0 ./ beta.value)))
        end
        nom_sector_gva[g] = nom_gva_g
        real_sector_gva[g] = real_gva_g
    end
    push!(history.nominal_sector_gva, nom_sector_gva)
    push!(history.real_sector_gva, real_sector_gva)

    return nothing
end
