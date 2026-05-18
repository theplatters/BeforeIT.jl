@testset "one epoch deterministic" begin
    model = Bit.Model(Bit.AUSTRIA2010Q1.parameters, Bit.AUSTRIA2010Q1.initial_conditions)
    world = model.world

    initial_cb_equity = _single_component_value(world, Bit.Equity; with = (Bit.CentralBank,))
    initial_gov_debt = _single_component_value(world, Bit.GovernmentDebt; with = (Bit.Government,))

    Bit.finance_insolvent_firms!(world)

    Bit.set_growth_inflation_expectations!(world)
    expectations = Bit.Ark.get_resource(world, Bit.Expectations)
    @test isapprox(expectations.gross_domestic_product, 134929.5631)
    @test isapprox(expectations.output_growth, 0.0021822; rtol = 1.0e-4)

    Bit.set_epsilon!(world)
    Bit.set_growth_inflation_EA!(world)
    @test isapprox(_single_component_value(world, Bit.EuroAreaGrowth; field = :rate), 0.0016278; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.EuroAreaGDP; field = :value), 2358680.8201; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.EuroAreaInflation; field = :rate), 0.0033723; rtol = 1.0e-5)

    Bit.set_central_bank_rate!(world)
    @test isapprox(_single_component_value(world, Bit.NominalInterestRate; with = (Bit.CentralBank,), field = :rate), 0.0017616; rtol = 1.0e-4)

    Bit.set_bank_rate!(world)
    @test isapprox(_single_component_value(world, Bit.LendingRate; with = (Bit.Bank,), field = :rate), 0.028476; rtol = 1.0e-4)

    Bit.set_firms_expectations_and_decisions!(world)
    @test isapprox(_component_mean(world, Bit.ExpectedSales; with = (Bit.Firm,)), 220.0311; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.DesiredInvestment; with = (Bit.Firm,)), 21.6029; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.DesiredMaterials; with = (Bit.Firm,)), 110.8158; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.DesiredEmployment; with = (Bit.Firm,)), 6.2436; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.ExpectedProfits; with = (Bit.Firm,)), 17.5269; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.TargetLoans; with = (Bit.Firm,)), 6.3063; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.ExpectedCapital; with = (Bit.Firm,)), 1265.3191; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.ExpectedLoans; with = (Bit.Firm,)), 360.694; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Price; with = (Bit.Firm,), field = :value), 1.0031; rtol = 1.0e-4)

    Bit.search_and_matching_credit!(world)
    @test isapprox(_component_mean(world, Bit.LoanFlow; with = (Bit.Firm,), predicate = x -> x > 0.0), 95.9791; rtol = 1.0e-6)

    Bit.search_and_matching_labor!(world)
    Bit.set_firms_wages!(world)
    Bit.set_firms_production!(world)
    @test isapprox(_component_mean(world, Bit.WageBill; with = (Bit.Firm,)), 6.6122; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Output; with = (Bit.Firm,)), 220.0311; rtol = 1.0e-6)

    Bit.update_workers_wages!(world)
    active_worker_wages = Float64[]
    for (_, employed) in Bit.Ark.Query(world, (Bit.Employed,), with = (Bit.Household,))
        append!(active_worker_wages, employed.rate)
    end
    for (_, unemployed) in Bit.Ark.Query(world, (Bit.Unemployed,), with = (Bit.Household,))
        append!(active_worker_wages, unemployed.unemployment_benefits)
    end
    @test isapprox(sum(active_worker_wages) / length(active_worker_wages), 7.5221; rtol = 1.0e-5)

    Bit.set_gov_social_benefits!(world)
    @test isapprox(_single_component_value(world, Bit.SocialBenefitsOther; with = (Bit.Government,)), 0.59157; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.SocialBenefitsInactive; with = (Bit.Government,)), 2.2434; rtol = 1.0e-4)

    Bit.set_bank_expected_profits!(world)
    @test isapprox(_single_component_value(world, Bit.ExpectedProfits; with = (Bit.Bank,)), 6510.4793; rtol = 1.0e-5)

    Bit.set_households_expected_income!(world)
    Bit.set_households_budget!(world)
    @test isapprox(_component_sum(world, Bit.ConsumptionBudget; with = (Bit.Household,)), 35538.3159; rtol = 1.0e-9, atol = 1.0e-6)
    @test isapprox(_component_sum(world, Bit.InvestmentBudget; with = (Bit.Household,)), 2950.5957; rtol = 1.0e-6, atol = 1.0e-6)

    Bit.set_gov_expenditure!(world)
    @test isapprox(_single_component_value(world, Bit.ConsumptionDemand; with = (Bit.Government,)), 14783.2494; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.ConsumptionDemand; with = (Bit.LocalGovernment,)), 95.0572; rtol = 1.0e-6, atol = 1.0e-6)

    Bit.set_rotw_import_export!(world)
    @test isapprox(_single_component_value(world, Bit.TotalExportDemand), 34246.8702; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.ForeignConsumptionDemand), 110.1048; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_single_component_value(world, Bit.TotalImportSupply), 33214.9736; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.ImportSupply; with = (Bit.ForeignSector,)), 535.7254; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.ImportPrice; with = (Bit.ForeignSector,), field = :value), 1.0031; rtol = 1.0e-4, atol = 1.0e-6)

    Bit.search_and_matching!(world)
    @test isapprox(_component_sum(world, Bit.RealisedConsumption; with = (Bit.Household,)), 35136.4805; rtol = 1.0e-4, atol = 1.0e-4)
    @test isapprox(_component_sum(world, Bit.RealisedInvestment; with = (Bit.Household,)), 2699.6511; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_sum(world, Bit.CapitalStock; with = (Bit.Household,)), 408076.5511; rtol = 1.0e-6, atol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.GoodsDemand; with = (Bit.Firm,)), 220.092; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Sales; with = (Bit.Firm,)), 216.6644; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.ImportDemand; with = (Bit.ForeignSector,)), 527.2969; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.ImportSales; with = (Bit.ForeignSector,)), 527.2969; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Investment; with = (Bit.Firm,)), 21.6029; rtol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.MaterialsStockChange; with = (Bit.Firm,)), 110.7829; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.CFPriceIndex; with = (Bit.Firm,), field = :value), 1.0031; rtol = 1.0e-4)
    @test isapprox(_component_mean(world, Bit.PriceIndex; with = (Bit.Firm,), field = :value), 1.0031; rtol = 1.0e-4)
    @test isapprox(_single_component_value(world, Bit.RealisedConsumption; with = (Bit.Government,)), 14370.3493; rtol = 1.0e-5)
    @test isapprox(_single_component_value(world, Bit.PriceInflationGovernmentGoods; with = (Bit.Government,), field = :value), 1.0031; rtol = 1.0e-4)

    Bit.set_inflation_priceindex!(world)
    Bit.set_sector_specific_priceindex!(world)
    Bit.set_capital_formation_priceindex!(world)
    Bit.set_households_priceindex!(world)
    Bit.set_firms_stocks!(world)
    @test isapprox(_component_mean(world, Bit.CapitalStock; with = (Bit.Firm,)), 1261.4216; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.Intermediates; with = (Bit.Firm,)), 130.0548; rtol = 1.0e-6)
    @test isapprox(_component_mean(world, Bit.FinalGoodsStockChange; with = (Bit.Firm,)), 3.3667; atol = 1.0e-5)
    @test isapprox(_component_mean(world, Bit.Inventories; with = (Bit.Firm,)), 3.3667; atol = 1.0e-5)

    Bit.set_firms_profits!(world)
    @test isapprox(_component_mean(world, Bit.Profits; with = (Bit.Firm,)), 17.5491; rtol = 1.0e-2)

    Bit.set_bank_profits!(world)
    @test isapprox(_single_component_value(world, Bit.Profits; with = (Bit.Bank,)), 6486.6381; rtol = 1.0e-5)

    Bit.set_bank_equity!(world)
    @test isapprox(_single_component_value(world, Bit.Equity; with = (Bit.Bank,)), 90742.39; rtol = 1.0e-5)

    Bit.set_households_income!(world)
    Bit.set_households_deposit!(world)
    @test isapprox(_component_sum(world, Bit.NetDisposableIncome; with = (Bit.Household,)), 45032.3263; rtol = 1.0e-2)
    @test isapprox(_component_sum(world, Bit.Deposits; with = (Bit.Household,)), 221816.6764; rtol = 1.0e-3)

    Bit.set_central_bank_equity!(world)
    @test isapprox(_single_component_value(world, Bit.Equity; with = (Bit.CentralBank,)) - initial_cb_equity, 1866.3821; rtol = 1.0e-5)

    Bit.set_gov_revenues!(world)
    @test isapprox(_single_component_value(world, Bit.GovernmentRevenues; with = (Bit.Government,)), 28783.0089; rtol = 1.0e-2)

    Bit.set_gov_loans!(world)
    @test isapprox(_single_component_value(world, Bit.GovernmentDebt; with = (Bit.Government,)) - initial_gov_debt, 3140.6916; rtol = 1.0e-2)
    @test isapprox(_single_component_value(world, Bit.GovernmentDebt; with = (Bit.Government,)), 235751.5916; rtol = 1.0e-4)

    firm_deposits_before = _query_rows(world, (Bit.Deposits,); with = (Bit.Firm,))
    Bit.set_firms_deposits!(world)
    deposit_change = 0.0
    firm_deposits_after = _query_rows(world, (Bit.Deposits,); with = (Bit.Firm,))
    for i in eachindex(firm_deposits_after)
        deposit_change += firm_deposits_after[i].components[1].amount - firm_deposits_before[i].components[1].amount
    end
    @test isapprox(deposit_change / length(firm_deposits_after), -14.8245; rtol = 1.0e-2)
    @test isapprox(_component_mean(world, Bit.Deposits; with = (Bit.Firm,)), 71.7925; rtol = 1.0e-3)

    Bit.set_firms_loans!(world)
    @test isapprox(_component_mean(world, Bit.LoansOutstanding; with = (Bit.Firm,)), 367.0003; rtol = 1.0e-5)

    Bit.set_firms_equity!(world)
    @test isapprox(_component_mean(world, Bit.Equity; with = (Bit.Firm,)), 1103.945; rtol = 1.0e-2)

    @test isapprox(_single_component_value(world, Bit.Equity; with = (Bit.CentralBank,)), 108046.2821; rtol = 1.0e-2)

    Bit.set_rotw_deposits!(world)
    @test isapprox(_single_component_value(world, Bit.NetForeignPosition), -644.0817; rtol = 1.0e-5)

    Bit.set_bank_deposits!(world)
    @test isapprox(_single_component_value(world, Bit.ResidualItems; with = (Bit.Bank,)), 128349.3912; rtol = 1.0e-3)
end
