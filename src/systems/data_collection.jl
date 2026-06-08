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

    if length(history.collection_time) == 1
        collect_data_init!(world, history, props)
        return nothing
    end

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
    tot_C_h = sum_amount(world, RealisedConsumption, with = (Household,))
    tot_I_h = sum_amount(world, RealisedInvestment, with = (Household,))


    gov_P_j = 0.0
    gov_C_j = 0.0
    gov_count = 0
    for comps in Ark.Query(world, (PriceInflationGovernmentGoods, RealisedConsumption), with = (Government,))
        row = query_row(comps)
        gov_P_j += sum(row.price_inflation_government_goods.value)
        gov_C_j += sum(row.realised_consumption.amount)
        gov_count += length(row.price_inflation_government_goods.value)
    end
    gov_P_j = gov_count > 0 ? gov_P_j / gov_count : 1.0

    # ROTW
    rotw_C_l = sum_amount(world, ForeignConsumption)
    rotw_P_l = sum_value(world, ExportPriceInflation)
    rotw_pi_ea = sum_rate(world, EuroAreaInflation)

    # Firms
    nominal_output_tax = sum_query(world, (TaxRates, Output, Price)) do row
        total = 0.0
        @inbounds for i in eachindex(row.output.amount)
            total += row.tax_rates.output[i] * row.output.amount[i] * row.price.value[i]
        end
        total
    end
    real_output_tax = sum_query(world, (TaxRates, Output, Price)) do row
        total = 0.0
        @inbounds for i in eachindex(row.output.amount)
            total += row.tax_rates.output[i] * row.output.amount[i]
        end
        total
    end

    nominal_gva_at_basic_prices = sum_query(world, (TaxRates, Price, Output, IntermediateProductivity, PriceIndex)) do row
        total = 0.0
        @inbounds for i in eachindex(row.output.amount)
            total += (
                (1.0 - row.tax_rates.output[i]) * row.price.value[i] * row.output.amount[i] -
                    row.price_index.value[i] * row.output.amount[i] / row.intermediate_productivity.value[i]
            )
        end
        total
    end

    real_gva_at_basic_prices = sum_query(world, (Output, TaxRates, IntermediateProductivity)) do row
        total = 0.0
        @inbounds for i in eachindex(row.output.amount)
            total += row.output.amount[i] * (
                (1.0 - row.tax_rates.output[i]) - 1.0 / row.intermediate_productivity.value[i]
            )
        end
        total
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
            τ_EXPORT * rotw_C_l / BeforeIT.zero_to_one(rotw_P_l)
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
    nominal_firm_inv = sum_query(world, (CFPriceIndex, Investment)) do row
        total = 0.0
        @inbounds for i in eachindex(row.investment.amount)
            total += row.cf_price_index.value[i] * row.investment.amount[i]
        end
        total
    end
    real_firm_inv = sum_amount(world, Investment)

    nominal_stock_change = sum_query(world, (FinalGoodsStockChange, Price)) do row
        total = 0.0
        @inbounds for i in eachindex(row.final_goods_stock_change.amount)
            total += row.final_goods_stock_change.amount[i] * row.price.value[i]
        end
        total
    end
    nominal_material_stock_adj = sum_query(world, (MaterialsStockChange, PriceIndex, IntermediateProductivity, Output)) do row
        total = 0.0
        @inbounds for i in eachindex(row.materials_stock_change.amount)
            total += (
                row.materials_stock_change.amount[i] * row.price_index.value[i] -
                    row.price_index.value[i] * row.output.amount[i] / row.intermediate_productivity.value[i]
            )
        end
        total
    end

    push!(history.nominal_capitalformation, nominal_firm_inv + (1.0 + τ_CF) * tot_I_h + nominal_stock_change + nominal_material_stock_adj)

    real_material_stock_adj = sum_query(world, (MaterialsStockChange, Output, IntermediateProductivity)) do row
        total = 0.0
        @inbounds for i in eachindex(row.materials_stock_change.amount)
            total += row.materials_stock_change.amount[i] -
                row.output.amount[i] / row.intermediate_productivity.value[i]
        end
        total
    end
    real_final_goods_stock_change = sum_amount(world, FinalGoodsStockChange)

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
    push!(history.real_exports, (1.0 + τ_EXPORT) * rotw_C_l / BeforeIT.zero_to_one(rotw_P_l))

    nom_imp = sum_query(world, (ImportPrice, ImportSales)) do row
        total = 0.0
        @inbounds for i in eachindex(row.import_sales.amount)
            total += row.import_price.value[i] * row.import_sales.amount[i]
        end
        total
    end
    push!(history.nominal_imports, nom_imp)

    real_imp = sum_amount(world, ImportSales)
    push!(history.real_imports, real_imp)

    # OS / Wages / Taxes
    wages_val_acc = sum_query(world, (WageBill, Employment)) do row
        total = 0.0
        @inbounds for i in eachindex(row.wage_bill.amount)
            total += row.wage_bill.amount[i] * row.employment.amount[i]
        end
        total
    end
    wages_val = wages_val_acc * P_bar_h
    push!(history.wages, wages_val)
    push!(history.compensation_employees, (1.0 + τ_SIF) * wages_val)

    taxes_prod = sum_query(world, (TaxRates, Output, Price)) do row
        total = 0.0
        @inbounds for i in eachindex(row.output.amount)
            total += row.tax_rates.capital[i] * row.output.amount[i] * row.price.value[i]
        end
        total
    end
    push!(history.taxes_production, taxes_prod)

    op_surplus = sum_query(world, (Price, Sales, FinalGoodsStockChange, WageBill, Employment, IntermediateProductivity, PriceIndex, TaxRates, Output)) do row
        total = 0.0
        @inbounds for i in eachindex(row.output.amount)
            total += (
                row.price.value[i] * row.sales.amount[i] +
                    row.price.value[i] * row.final_goods_stock_change.amount[i] -
                    (1.0 + τ_SIF) * row.wage_bill.amount[i] * row.employment.amount[i] * P_bar_h -
                    row.price_index.value[i] * row.output.amount[i] / row.intermediate_productivity.value[i] -
                    row.tax_rates.output[i] * row.price.value[i] * row.output.amount[i] -
                    row.tax_rates.capital[i] * row.price.value[i] * row.output.amount[i]
            )
        end
        total
    end
    push!(history.operating_surplus, op_surplus)

    # External
    _, cb_euribor = single(Ark.Query(world, (NominalInterestRate,)))
    push!(history.euribor, cb_euribor.rate)
    push!(history.gdp_deflator_growth_ea, rotw_pi_ea)

    real_gdp_ea = sum_value(world, EuroAreaGDP)
    push!(history.real_gdp_ea, real_gdp_ea)

    # Sectoral GVA
    nom_sector_gva = zeros(props.dimensions.sectors)
    real_sector_gva = zeros(props.dimensions.sectors)
    for g in 1:props.dimensions.sectors
        nom_gva_g = 0.0
        real_gva_g = 0.0
        for comps in Ark.Query(world, (PrincipalProduct, TaxRates, Price, Output, IntermediateProductivity, PriceIndex))
            row = query_row(comps)
            @inbounds for i in eachindex(row.principal_product.id)
                row.principal_product.id[i] == g || continue
                nom_gva_g += (
                    (1.0 - row.tax_rates.output[i]) * row.price.value[i] * row.output.amount[i] -
                        row.price_index.value[i] * row.output.amount[i] / row.intermediate_productivity.value[i]
                )
                real_gva_g += (
                    row.output.amount[i] * (
                        (1.0 - row.tax_rates.output[i]) - 1.0 / row.intermediate_productivity.value[i]
                    )
                )
            end
        end
        nom_sector_gva[g] = nom_gva_g
        real_sector_gva[g] = real_gva_g
    end
    push!(history.nominal_sector_gva, nom_sector_gva)
    push!(history.real_sector_gva, real_sector_gva)

    return nothing
end

function collect_data_init!(world::Ark.World, history::DataCollector, props::Properties)
    τ_VAT = props.tax_rates.value_added
    τ_CF = props.tax_rates.capital_formation
    τ_G = props.tax_rates.government_consumption
    τ_EXPORT = props.tax_rates.exports
    τ_SIF = props.social_insurance.employers_contribution
    ψ = props.household_params.consumption_share
    ψ_H = props.household_params.housing_investment_share

    total_income = sum_amount(world, NetDisposableIncome, with = (Household,))

    real_gdp = 0.0
    real_gva = 0.0
    nominal_gva = 0.0
    capitalformation_firms = 0.0
    wages = 0.0
    taxes_production = 0.0
    operating_surplus = 0.0
    nominal_sector_gva = zeros(props.dimensions.sectors)

    for comps in Ark.Query(
            world,
            (
                PrincipalProduct,
                TaxRates,
                Output,
                IntermediateProductivity,
                CapitalDeprecationRate,
                CapitalProductivity,
                AverageWageRate,
                Employment,
                LaborProductivity,
            ),
        )
        row = query_row(comps)
        @inbounds for i in eachindex(row.output.amount)
            real_gdp += row.output.amount[i] * (1.0 - 1.0 / row.intermediate_productivity.value[i])
            real_gva += row.output.amount[i] * (
                (1.0 - row.tax_rates.output[i]) - 1.0 / row.intermediate_productivity.value[i]
            )
            nominal_gva += row.output.amount[i] * (
                (1.0 - row.tax_rates.output[i]) - 1.0 / row.intermediate_productivity.value[i]
            )
            capitalformation_firms += (
                row.output.amount[i] *
                    row.capital_depreciation_rate.rate[i] /
                    row.capital_productivity.value[i]
            )
            wages += row.average_wage_rate.rate[i] * row.employment.amount[i]
            taxes_production += row.tax_rates.capital[i] * row.output.amount[i]
            operating_surplus += (
                row.output.amount[i] * (
                    1.0 - (
                        (1.0 + τ_SIF) *
                            row.average_wage_rate.rate[i] /
                            row.labor_productivity.value[i] +
                            1.0 / row.intermediate_productivity.value[i]
                    )
                ) -
                    row.tax_rates.capital[i] * row.output.amount[i] -
                    row.tax_rates.output[i] * row.output.amount[i]
            )

            nominal_sector_gva[row.principal_product.id[i]] += row.output.amount[i] * (
                (1.0 - row.tax_rates.output[i]) - 1.0 / row.intermediate_productivity.value[i]
            )
        end
    end

    gov_consumption = sum_amount(world, ConsumptionDemand, with = (Government,))

    exports = sum_amount(world, TotalExportDemand)
    imports = sum_amount(world, TotalImportSupply)
    inflation_ea = sum_rate(world, EuroAreaInflation)
    gdp_ea = sum_value(world, EuroAreaGDP)

    nominal_household_consumption = total_income * ψ
    nominal_government_consumption = (1.0 + τ_G) * gov_consumption
    nominal_capitalformation = capitalformation_firms + total_income * ψ_H
    nominal_fixed_capitalformation_dwellings = total_income * ψ_H
    nominal_exports = (1.0 + τ_EXPORT) * exports
    nominal_gdp =
        real_gdp +
        nominal_household_consumption / (1.0 / τ_VAT + 1.0) +
        τ_G * gov_consumption +
        nominal_fixed_capitalformation_dwellings / (1.0 / τ_CF + 1.0) +
        τ_EXPORT * exports

    push!(history.nominal_gdp, nominal_gdp)
    push!(history.real_gdp, nominal_gdp)
    push!(history.nominal_gva, nominal_gva)
    push!(history.real_gva, real_gva)
    push!(history.nominal_household_consumption, nominal_household_consumption)
    push!(history.real_household_consumption, nominal_household_consumption)
    push!(history.nominal_government_consumption, nominal_government_consumption)
    push!(history.real_government_consumption, nominal_government_consumption)
    push!(history.nominal_capitalformation, nominal_capitalformation)
    push!(history.real_capitalformation, nominal_capitalformation)
    push!(history.nominal_fixed_capitalformation, nominal_capitalformation)
    push!(history.real_fixed_capitalformation, nominal_capitalformation)
    push!(history.nominal_fixed_capitalformation_dwellings, nominal_fixed_capitalformation_dwellings)
    push!(history.real_fixed_capitalformation_dwellings, nominal_fixed_capitalformation_dwellings)
    push!(history.nominal_exports, nominal_exports)
    push!(history.real_exports, nominal_exports)
    push!(history.nominal_imports, imports)
    push!(history.real_imports, imports)
    push!(history.operating_surplus, operating_surplus)
    push!(history.compensation_employees, (1.0 + τ_SIF) * wages)
    push!(history.wages, wages)
    push!(history.taxes_production, taxes_production)
    push!(history.gdp_deflator_growth_ea, inflation_ea)
    push!(history.real_gdp_ea, gdp_ea)

    push!(history.euribor, sum_rate(world, NominalInterestRate))

    push!(history.nominal_sector_gva, nominal_sector_gva)
    push!(history.real_sector_gva, copy(nominal_sector_gva))

    return nothing
end
