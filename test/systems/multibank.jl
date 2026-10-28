using Test
import Ark
import JLD2
using Random

function multibank_model(n_banks; seed = 1)
    dir = joinpath(pkgdir(Bit), "data", "austria")
    parameters = JLD2.load(joinpath(dir, "parameters", "2010Q1.jld2"))
    initial_conditions = JLD2.load(joinpath(dir, "initial_conditions", "2010Q1.jld2"))
    parameters["n_banks"] = n_banks
    Random.seed!(seed)
    return Bit.Model(parameters, initial_conditions)
end

count_with(world, with) = sum((length(e) for (e,) in Ark.Query(world, (), with = with)); init = 0)

bank_sum(world, C, bank) = Bit.sum_amount(world, C, with = (Bit.BankAccount => bank,))

function bank_amounts(world, C)
    amounts = Float64[]
    for (_, c) in Ark.Query(world, (C,), with = (Bit.Bank,))
        append!(amounts, (x.amount for x in c))
    end
    return amounts
end

@testset "Multiple banks" begin
    n_banks = 3

    @testset "initialisation" begin
        model = multibank_model(n_banks)
        world = model.world
        properties = Bit.properties(world)
        banks = Bit.bank_entities(world)

        @test properties.population.banks == n_banks
        @test length(banks) == n_banks
        @test count_with(world, (Bit.Banker,)) == n_banks

        # every account holder belongs to exactly one bank
        holders = count_with(world, (Bit.Deposits,))
        @test count_with(world, (Bit.Deposits, Bit.BankAccount)) == holders
        @test sum(count_with(world, (Bit.Deposits, Bit.BankAccount => b)) for b in banks) == holders
        @test all(count_with(world, (Bit.Firm, Bit.BankAccount => b)) > 0 for b in banks)

        # firm owners bank with their firm, bankers with their own bank
        for (firms, owners) in Ark.Query(world, (Bit.Owner,), with = (Bit.Firm,))
            for (firm, owner) in zip(firms, owners)
                @test Ark.get_relations(world, firm, (Bit.BankAccount,)) ==
                    Ark.get_relations(world, owner.entity, (Bit.BankAccount,))
            end
        end
        for (bank_es, owners) in Ark.Query(world, (Bit.Owner,), with = (Bit.Bank,))
            for (bank, owner) in zip(bank_es, owners)
                @test Ark.get_relations(world, owner.entity, (Bit.BankAccount,)) == (bank,)
            end
        end

        # sector equity is split equally and adds up to the single-bank value
        equity = bank_amounts(world, Bit.Equity)
        @test all(equity .≈ equity[1])
        @test sum(equity) ≈ properties.initial_conditions.banking.equity_ratio

        # households, foreign consumers and local governments have distinct demand slots
        indices = Int[]
        for (_, idx) in Ark.Query(world, (Bit.FinalDemandCacheIndex,))
            append!(indices, idx.id)
        end
        @test allunique(indices)
        @test maximum(indices) == properties.population.total +
            properties.dimensions.foreign_consumers + properties.dimensions.local_governments
    end

    @testset "balance sheets" begin
        model = multibank_model(n_banks)
        Bit.run!(model, 5)
        world = model.world
        banks = Bit.bank_entities(world)

        for (bank_es, equity, residual) in Ark.Query(world, (Bit.Equity, Bit.ResidualItems), with = (Bit.Bank,))
            for (bank, E_k, D_k) in zip(bank_es, equity, residual)
                @test D_k.amount ≈
                    E_k.amount - bank_sum(world, Bit.LoansOutstanding, bank) + bank_sum(world, Bit.Deposits, bank)
            end
        end

        # per-bank books add up to the economy-wide totals
        @test sum(bank_sum(world, Bit.Deposits, b) for b in banks) ≈ Bit.sum_amount(world, Bit.Deposits)
        @test sum(bank_sum(world, Bit.LoansOutstanding, b) for b in banks) ≈ Bit.sum_amount(world, Bit.LoansOutstanding)

        # collected per-bank series match the bank entities
        data = model.data
        @test length(data.equity_per_bank) == length(data.collection_time)
        @test data.equity_per_bank[end] ≈ bank_amounts(world, Bit.Equity)
        @test data.reserves_per_bank[end] ≈ bank_amounts(world, Bit.ResidualItems)
        @test data.credit_stock_per_bank[end] ≈ [bank_sum(world, Bit.LoansOutstanding, b) for b in banks]
    end

    @testset "credit is rationed per bank" begin
        model = multibank_model(n_banks)
        Bit.run!(model, 2)
        world = model.world
        ζ = Bit.properties(world).banking_params.capital_requirement

        Bit.search_and_matching_credit!(world)

        for (bank_es, equity) in Ark.Query(world, (Bit.Equity,), with = (Bit.Bank,))
            for (bank, E_k) in zip(bank_es, equity)
                new_loans = bank_sum(world, Bit.LoanFlow, bank)
                capacity = E_k.amount / ζ - bank_sum(world, Bit.ExpectedLoans, bank)
                @test new_loans <= max(0.0, capacity) + 1.0e-8
            end
        end
    end

    @testset "accounting identities" begin
        model = multibank_model(n_banks)
        Bit.run!(model, 10)
        world = model.world
        history = model.data

        @test isapprox(
            sum(history.nominal_gva .- history.compensation_employees .- history.operating_surplus .- history.taxes_production),
            0.0, atol = 1.0e-8,
        )
        # The initial period is derived from the single-bank calibration: every extra banker
        # household adds one `sb_other` transfer that it does not account for, so only the
        # simulated periods are checked.
        simulated = 2:length(history.collection_time)
        @test isapprox(
            sum(
                history.nominal_gdp[simulated] .- history.nominal_household_consumption[simulated] .-
                    history.nominal_government_consumption[simulated] .- history.nominal_capitalformation[simulated] .-
                    history.nominal_exports[simulated] .+ history.nominal_imports[simulated]
            ),
            0.0, atol = 1.0e-8,
        )

        # the central bank balance sheet holds with the banking sector summed over banks
        cb_equity = Bit.single(Ark.Query(world, (Bit.Equity,), with = (Bit.CentralBank,)))[2].amount
        foreign_position = Bit.single(Ark.Query(world, (Bit.NetForeignPosition,)))[2].amount
        government_debt = Bit.single(Ark.Query(world, (Bit.GovernmentDebt,), with = (Bit.Government,)))[2].amount
        reserves = sum(bank_amounts(world, Bit.ResidualItems))
        @test isapprox(cb_equity + foreign_position - government_debt + reserves, 0.0, atol = 1.0e-6)
    end
end
