import Ark


model = Bit.ECSModel(Bit.STEADY_STATE2010Q1)

world = model.world
properties = Bit.properties(model)


@testset "Population accounting" begin
    employed_count = Ark.count_entities(Ark.Query(world, (Bit.Employed,)))
    inactive_count = Ark.count_entities(Ark.Query(world, (Bit.Inactive,)))
    unemployed_count = Ark.count_entities(Ark.Query(world, (Bit.Unemployed,)))
    capitalist_count = Ark.count_entities(Ark.Query(world, (Bit.Capitalist,)))
    firm_count = Ark.count_entities(Ark.Query(world, (Bit.Output,)))

    @test inactive_count == properties.population.inactive
    @test employed_count + unemployed_count == properties.population.active - properties.dimensions.total_firms - 1
    @test capitalist_count == properties.dimensions.total_firms
    @test firm_count == properties.dimensions.total_firms
end

@testset "Firm initialization invariants" begin
    for (e, _, output, sales, demand, price, inventories, vacancies, investment, equity) in Ark.Query(
            world,
            (
                Bit.PrincipalProduct,
                Bit.Output,
                Bit.Sales,
                Bit.GoodsDemand,
                Bit.Price,
                Bit.Inventories,
                Bit.Vacancies,
                Bit.Investment,
                Bit.Equity,
            )
        )
        @test all(output.amount .>= 0.0)
        @test all(sales.amount .== output.amount)
        @test all(demand.amount .== output.amount)
        @test all(price.value .== 1.0)
        @test all(inventories.amount .== 0.0)
        @test all(investment.amount .== 0.0)
        @test all(equity.amount .== 0.0)
        @test all(vacancies.amount .>= 0)
    end
end

@testset "Firm accounting identities" begin
    omega = properties.initial_conditions.firms.capacity_utilization

    for (_, _, output, capital, intermediates, employment, vacancies, labor_prod, capital_prod, material_prod) in Ark.Query(
            world,
            (
                Bit.PrincipalProduct,
                Bit.Output,
                Bit.CapitalStock,
                Bit.Intermediates,
                Bit.Employment,
                Bit.Vacancies,
                Bit.LaborProductivity,
                Bit.CapitalProductivity,
                Bit.IntermediateProductivity,
            )
        )
        @test all(isapprox.(output.amount, labor_prod.value .* employment.amount, atol = 1.0e-7))
        @test all(isapprox.(capital.amount, output.amount ./ (omega .* capital_prod.value), atol = 1.0e-7))
        @test all(isapprox.(intermediates.amount, output.amount ./ (omega .* material_prod.value), atol = 1.0e-7))
        @test all(vacancies.amount .== employment.amount)
    end
end

@testset "Household initialization" begin
    # Helper parameters from properties
    unemployment_benefit_rate = properties.social_insurance.unemployment_benefit
    subsidies_other = properties.initial_conditions.government.subsidies_other
    subsidies_inactive = properties.initial_conditions.government.subsidies_inactive

    debt = properties.initial_conditions.households.debt
    capital = properties.initial_conditions.households.capital
    unemployment_benefit = properties.initial_conditions.households.unemployment_benefit
    total_disposable_income = sum(sum(income.amount) for (_, income) in Ark.Query(world, (Bit.NetDisposableIncome,)))

    expected_unemployment_benefits = unemployment_benefit / unemployment_benefit_rate
    expected_unemployed_income = Bit.unemployed_worker_income(
        expected_unemployment_benefits,
        unemployment_benefit_rate,
        subsidies_other,
        1.0,
        0.0,
    )
    expected_unemployed_deposits = debt * expected_unemployed_income / total_disposable_income
    expected_unemployed_capital = capital * expected_unemployed_income / total_disposable_income
    expected_inactive_income = subsidies_other + subsidies_inactive

    # 1. Test Employable (Unemployed) Households
    unemployed_query = Ark.Query(
        world,
        (
            Bit.Household,
            Bit.Unemployed,
            Bit.NetDisposableIncome,
            Bit.Deposits,
            Bit.ExpectedIncome,
            Bit.CapitalStock,
            Bit.ConsumptionBudget,
            Bit.InvestmentBudget,
        )
    )

    for (_, _, unemployed, income, deposits, expected_income, capital_stock, c_budget, i_budget) in unemployed_query
        @test all(isapprox.(unemployed.unemployment_benefits, expected_unemployment_benefits, atol = 1.0e-7))
        @test all(isapprox.(income.amount, expected_unemployed_income, atol = 1.0e-7))
        @test all(isapprox.(deposits.amount, expected_unemployed_deposits, atol = 1.0e-7))
        @test all(iszero, expected_income.amount)
        @test all(isapprox.(capital_stock.amount, expected_unemployed_capital, atol = 1.0e-7))
        @test all(iszero, c_budget.amount)
        @test all(iszero, i_budget.amount)
    end

    # 2. Test Inactive Households
    inactive_query = Ark.Query(
        world,
        (
            Bit.Household,
            Bit.Inactive,
            Bit.NetDisposableIncome,
            Bit.Deposits,
            Bit.ExpectedIncome,
            Bit.CapitalStock,
            Bit.ConsumptionBudget,
            Bit.InvestmentBudget,
        )
    )

    for (_, _, _, income, deposits, expected_income, capital_stock, c_budget, i_budget) in inactive_query
        @test all(isapprox.(income.amount, expected_inactive_income, atol = 1.0e-7))
        @test all(iszero, expected_income.amount)
        @test all(iszero, c_budget.amount)
        @test all(iszero, i_budget.amount)
    end

    # 3. Disjointness Check: Ensure no Household is both Inactive and Unemployed
    overlap_query = Ark.Query(
        world,
        (Bit.Household, Bit.Inactive, Bit.Unemployed)
    )
    @test Ark.count_entities(overlap_query) == 0
end


@testset "Rest-of-world initialization" begin
    # Helper parameters from properties
    L = properties.dimensions.foreign_consumers
    G = properties.dimensions.sectors
    T_prime = properties.dimensions.interval_for_expectation_estimation
    external = properties.initial_conditions.external

    # 1. Test Main ROTW Aggregate Entity
    rotw_main_query = Ark.Query(
        world,
        (
            Bit.EuroAreaGDP,
            Bit.EuroAreaGrowth,
            Bit.EuroAreaInflation,
            Bit.NetForeignPosition,
            Bit.ForeignConsumption,
            Bit.TotalExportDemand,
            Bit.TotalImportSupply,
        )
    )

    @test Ark.count_entities(rotw_main_query) == 1

    local main_rotw_entity
    for (e, gdp, growth, inflation, nfp, fc, export_demand, import_supply) in rotw_main_query
        # Extract the single entity ID (e is an array of entity IDs in this chunk)
        main_rotw_entity = e[1]

        @test all(isapprox.(gdp.value, external.foreign_output, atol = 1.0e-7))
        @test all(iszero, growth.rate)
        @test all(isapprox.(inflation.rate, external.foreign_inflation, atol = 1.0e-7))
        @test all(isapprox.(nfp.amount, external.debt, atol = 1.0e-7))
        @test all(iszero, fc.amount)
        @test all(isapprox.(export_demand.amount, external.exports[T_prime], atol = 1.0e-7))
        @test all(isapprox.(import_supply.amount, external.imports[T_prime], atol = 1.0e-7))
    end

    # 2. Test Foreign Consumers
    foreign_consumers_query = Ark.Query(
        world,
        (
            Bit.ForeignConsumptionDemand,
            Bit.RestOfWorldEntity,
        )
    )

    @test Ark.count_entities(foreign_consumers_query) == L

    for (_, fc_demand, _) in foreign_consumers_query
        @test all(iszero, fc_demand.amount)
    end

    # 3. Test Foreign Sectors
    foreign_sectors_query = Ark.Query(
        world,
        (
            Bit.ForeignSector,
            Bit.PrincipalProduct,
            Bit.ImportSupply,
            Bit.ImportSales,
            Bit.ImportDemand,
            Bit.ImportPrice,
            Bit.ExportPriceInflation,
        )
    )

    @test Ark.count_entities(foreign_sectors_query) == G

    sector_indices = Int[]
    for (_, _, pp, isupply, isales, idemand, iprice, epi) in foreign_sectors_query
        append!(sector_indices, pp.id)

        @test all(iszero, isupply.amount)
        @test all(iszero, isales.amount)
        @test all(iszero, idemand.amount)
        @test all(iszero, iprice.value)
        @test all(iszero, epi.value)
    end

    # Ensure sectors are correctly enumerated 1 through G
    @test sort(sector_indices) == collect(1:G)
end


@testset "Macroeconomic resource initialization" begin
end

@testset "Sector aggregate initialization" begin
end
