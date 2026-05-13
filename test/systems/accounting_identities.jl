using Test
import Ark
using Random

function sum_component_amount(world, component; with)
    total = 0.0
    for (_, values) in Ark.Query(world, (component,), with = with)
        total += sum(value.amount for value in values)
    end
    return total
end

function single_component_amount(world, component; with)
    return Bit.single(Ark.Query(world, (component,), with = with))[2].amount
end

@testset "Accounting Identities" begin
    Random.seed!(1)

    model = Bit.ECSModel(Bit.AUSTRIA2010Q1)
    Bit.step!(model)

    world = model.world
    history = Ark.get_resource(world, Bit.DataCollector)

    income_and_production = sum(
        history.nominal_gva .-
            history.compensation_employees .-
            history.operating_surplus .-
            history.taxes_production,
    )
    @test isapprox(income_and_production, 0.0, atol = 1.0e-8)

    gdp_and_expenditure = sum(
        history.nominal_gdp .-
            history.nominal_household_consumption .-
            history.nominal_government_consumption .-
            history.nominal_capitalformation .-
            history.nominal_exports .+
            history.nominal_imports,
    )
    @test isapprox(gdp_and_expenditure, 0.0, atol = 1.0e-8)

    gdp_and_expenditure_real = sum(
        history.real_gdp .-
            history.real_household_consumption .-
            history.real_government_consumption .-
            history.real_capitalformation .-
            history.real_exports .+
            history.real_imports,
    )
    @test isapprox(gdp_and_expenditure_real, 0.0, atol = 1.0e-8)

    cb_balance =
        single_component_amount(world, Bit.Components.Equity; with = (Bit.Components.CentralBank,)) +
        Bit.single(Ark.Query(world, (Bit.Components.NetForeignPosition,)))[2].amount -
        single_component_amount(world, Bit.Components.GovernmentDebt; with = (Bit.Components.Government,)) +
        single_component_amount(world, Bit.Components.ResidualItems; with = (Bit.Components.Bank,))
    @test isapprox(cb_balance, 0.0, atol = 1.0e-7)

    bank_balance =
        sum_component_amount(world, Bit.Components.Deposits; with = ()) +
        single_component_amount(world, Bit.Components.Equity; with = (Bit.Components.Bank,)) -
        sum_component_amount(world, Bit.Components.LoansOutstanding; with = ()) -
        single_component_amount(world, Bit.Components.ResidualItems; with = (Bit.Components.Bank,))
    @test isapprox(bank_balance, 0.0, atol = 1.0e-7)
end
