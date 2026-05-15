
@testset "one epoch deterministic" begin
    model = Bit.Model(Bit.AUSTRIA2010Q1.parameters, Bit.AUSTRIA2010Q1.initial_conditions)
    world = model.world

    initial_cb_equity = _single_component_value(world, Bit.Components.Equity; with = (Bit.Components.CentralBank,))
    initial_gov_debt = _single_component_value(world, Bit.Components.GovernmentDebt; with = (Bit.Components.Government,))

    Bit.finance_insolvent_firms!(world)

    Bit.set_growth_inflation_expectations!(world)
    expectations = Bit.Ark.get_resource(world, Bit.Expectations)
    @test isapprox(expectations.gross_domestic_product, 134929.5631)
    @test isapprox(expectations.output_growth, 0.0021822; rtol = 1.0e-4)

    Bit.set_epsilon!(world)
    Bit.set_growth_inflation_EA!(world)
    @test isapprox(_single_component_value(world, Bit.Components.EuroAreaGrowth; field = :rate), 0.0016278; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.Components.EuroAreaGDP; field = :value), 2358680.8201; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.Components.EuroAreaInflation; field = :rate), 0.0033723; rtol = 1.0e-5)

    Bit.set_central_bank_rate!(world)
    @test isapprox(_single_component_value(world, Bit.Components.NominalInterestRate; with = (Bit.Components.CentralBank,), field = :rate), 0.0017616; rtol = 1.0e-4)

    Bit.set_bank_rate!(world)
    @test isapprox(_single_component_value(world, Bit.Components.LendingRate; with = (Bit.Components.Bank,), field = :rate), 0.028476; rtol = 1.0e-4)

    Bit.set_firms_expectations_and_decisions!(world)
    @test isapprox(_component_mean(world, Bit.Components.ExpectedSales; with = (Bit.Components.Firm,)), 220.0311; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.DesiredInvestment; with = (Bit.Components.Firm,)), 21.6029; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.DesiredMaterials; with = (Bit.Components.Firm,)), 110.8158; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.DesiredEmployment; with = (Bit.Components.Firm,)), 6.2436; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.ExpectedProfits; with = (Bit.Components.Firm,)), 17.5269; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.TargetLoans; with = (Bit.Components.Firm,)), 6.3063; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.ExpectedCapital; with = (Bit.Components.Firm,)), 1265.3191; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.ExpectedLoans; with = (Bit.Components.Firm,)), 360.694; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.Price; with = (Bit.Components.Firm,), field = :value), 1.0031; rtol = 1.0e-4)

    Bit.search_and_matching_credit!(world)
    @test isapprox(_component_mean(world, Bit.Components.LoanFlow; with = (Bit.Components.Firm,), predicate = x -> x > 0.0), 95.9791; rtol = 1.0e-6)

    Bit.search_and_matching_labor!(world)
    Bit.set_firms_wages!(world)
    Bit.set_firms_production!(world)
    @test isapprox(_component_mean(world, Bit.Components.WageBill; with = (Bit.Components.Firm,)), 6.6122; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.Output; with = (Bit.Components.Firm,)), 220.0311; rtol = 1.0e-6)

    Bit.update_workers_wages!(world)
    active_worker_wages = Float64[]
    for (_, employed) in Bit.Ark.Query(world, (Bit.Components.Employed,), with = (Bit.Components.Household,))
        append!(active_worker_wages, employed.rate)
    end
    for (_, unemployed) in Bit.Ark.Query(world, (Bit.Components.Unemployed,), with = (Bit.Components.Household,))
        append!(active_worker_wages, unemployed.unemployment_benefits)
    end
    @test isapprox(sum(active_worker_wages) / length(active_worker_wages), 7.5221; rtol = 1.0e-5)

    Bit.set_gov_social_benefits!(world)
    @test isapprox(_single_component_value(world, Bit.Components.SocialBenefitsOther; with = (Bit.Components.Government,)), 0.59157; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.Components.SocialBenefitsInactive; with = (Bit.Components.Government,)), 2.2434; rtol = 1.0e-4)

    Bit.set_bank_expected_profits!(world)
    @test isapprox(_single_component_value(world, Bit.Components.ExpectedProfits; with = (Bit.Components.Bank,)), 6510.4793; rtol = 1.0e-5)

    Bit.set_households_expected_income!(world)
    Bit.set_households_budget!(world)
    @test isapprox(_component_sum(world, Bit.Components.ConsumptionBudget; with = (Bit.Components.Household,)), 35538.3159; rtol = 1.0e-9, atol = 1.0e-6)
    @test isapprox(_component_sum(world, Bit.Components.InvestmentBudget; with = (Bit.Components.Household,)), 2950.5957; rtol = 1.0e-6, atol = 1.0e-6)

    Bit.set_gov_expenditure!(world)
    @test isapprox(_single_component_value(world, Bit.Components.ConsumptionDemand; with = (Bit.Components.Government,)), 14783.2494; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.ConsumptionDemand; with = (Bit.Components.LocalGovernment,)), 95.0572; rtol = 1.0e-6, atol = 1.0e-6)

    Bit.set_rotw_import_export!(world)
    @test isapprox(_single_component_value(world, Bit.Components.TotalExportDemand), 34246.8702; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.ForeignConsumptionDemand), 110.1048; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_single_component_value(world, Bit.Components.TotalImportSupply), 33214.9736; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.ImportSupply; with = (Bit.Components.ForeignSector,)), 535.7254; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.ImportPrice; with = (Bit.Components.ForeignSector,), field = :value), 1.0031; rtol = 1.0e-4, atol = 1.0e-6)

    Bit.search_and_matching!(world)
    @test isapprox(_component_sum(world, Bit.Components.RealisedConsumption; with = (Bit.Components.Household,)), 35136.4805; rtol = 1.0e-4, atol = 1.0e-4)
    @test isapprox(_component_sum(world, Bit.Components.RealisedInvestment; with = (Bit.Components.Household,)), 2699.6511; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_sum(world, Bit.Components.CapitalStock; with = (Bit.Components.Household,)), 408076.5511; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.GoodsDemand; with = (Bit.Components.Firm,)), 220.092; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.Sales; with = (Bit.Components.Firm,)), 216.6644; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.ImportDemand; with = (Bit.Components.ForeignSector,)), 527.2969; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.ImportSales; with = (Bit.Components.ForeignSector,)), 527.2969; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.Investment; with = (Bit.Components.Firm,)), 21.6029; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.MaterialsStockChange; with = (Bit.Components.Firm,)), 110.7829; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.CFPriceIndex; with = (Bit.Components.Firm,), field = :value), 1.0031; rtol = 1.0e-4)
    @test isapprox(_component_mean(world, Bit.Components.PriceIndex; with = (Bit.Components.Firm,), field = :value), 1.0031; rtol = 1.0e-4)
    @test isapprox(_single_component_value(world, Bit.Components.RealisedConsumption; with = (Bit.Components.Government,)), 14370.3493; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.Components.PriceInflationGovernmentGoods; with = (Bit.Components.Government,), field = :value), 1.0031; rtol = 1.0e-4)

    Bit.set_inflation_priceindex!(world)
    Bit.set_sector_specific_priceindex!(world)
    Bit.set_capital_formation_priceindex!(world)
    Bit.set_households_priceindex!(world)
    Bit.set_firms_stocks!(world)
    @test isapprox(_component_mean(world, Bit.Components.CapitalStock; with = (Bit.Components.Firm,)), 1261.4216; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.Intermediates; with = (Bit.Components.Firm,)), 130.0548; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Components.FinalGoodsStockChange; with = (Bit.Components.Firm,)), 3.3667; atol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Components.Inventories; with = (Bit.Components.Firm,)), 3.3667; atol = 1.0e-5)

    Bit.set_firms_profits!(world)
    @test isapprox(_component_mean(world, Bit.Components.Profits; with = (Bit.Components.Firm,)), 17.5491; rtol = 1.0e-2)

    Bit.set_bank_profits!(world)
    @test isapprox(_single_component_value(world, Bit.Components.Profits; with = (Bit.Components.Bank,)), 6486.6381; rtol = 1.0e-5)

    Bit.set_bank_equity!(world)
    @test isapprox(_single_component_value(world, Bit.Components.Equity; with = (Bit.Components.Bank,)), 90742.39; rtol = 1.0e-5)

    Bit.set_households_income!(world)
    Bit.set_households_deposit!(world)
    @test isapprox(_component_sum(world, Bit.Components.NetDisposableIncome; with = (Bit.Components.Household,)), 45032.3263; rtol = 1.0e-2)
    @test isapprox(_component_sum(world, Bit.Components.Deposits; with = (Bit.Components.Household,)), 221816.6764; rtol = 1.0e-3)

    Bit.set_central_bank_equity!(world)
    @test isapprox(_single_component_value(world, Bit.Components.Equity; with = (Bit.Components.CentralBank,)) - initial_cb_equity, 1866.3821; rtol = 1.0e-5)

    Bit.set_gov_revenues!(world)
    @test isapprox(_single_component_value(world, Bit.Components.GovernmentRevenues; with = (Bit.Components.Government,)), 28783.0089; rtol = 1.0e-2)

    Bit.set_gov_loans!(world)
    @test isapprox(_single_component_value(world, Bit.Components.GovernmentDebt; with = (Bit.Components.Government,)) - initial_gov_debt, 3140.6916; rtol = 1.0e-2)
    @test isapprox(_single_component_value(world, Bit.Components.GovernmentDebt; with = (Bit.Components.Government,)), 235751.5916; rtol = 1.0e-4)

    firm_deposits_before = _query_rows(world, (Bit.Components.Deposits,); with = (Bit.Components.Firm,))
    Bit.set_firms_deposits!(world)
    deposit_change = 0.0
    firm_deposits_after = _query_rows(world, (Bit.Components.Deposits,); with = (Bit.Components.Firm,))
    for i in eachindex(firm_deposits_after)
        deposit_change += firm_deposits_after[i].components[1].amount - firm_deposits_before[i].components[1].amount
    end
    @test isapprox(deposit_change / length(firm_deposits_after), -14.8245; rtol = 1.0e-2)
    @test isapprox(_component_mean(world, Bit.Components.Deposits; with = (Bit.Components.Firm,)), 71.7925; rtol = 1.0e-3)

    Bit.set_firms_loans!(world)
    @test isapprox(_component_mean(world, Bit.Components.LoansOutstanding; with = (Bit.Components.Firm,)), 367.0003; rtol = 1.0e-5)

    Bit.set_firms_equity!(world)
    @test isapprox(_component_mean(world, Bit.Components.Equity; with = (Bit.Components.Firm,)), 1103.945; rtol = 1.0e-2)

    @test isapprox(_single_component_value(world, Bit.Components.Equity; with = (Bit.Components.CentralBank,)), 108046.2821; rtol = 1.0e-2)

    Bit.set_rotw_deposits!(world)
    @test isapprox(_single_component_value(world, Bit.Components.NetForeignPosition), -644.0817; rtol = 1.0e-5)

    Bit.set_bank_deposits!(world)
    @test isapprox(_single_component_value(world, Bit.Components.ResidualItems; with = (Bit.Components.Bank,)), 128349.3912; rtol = 1.0e-3)
end
