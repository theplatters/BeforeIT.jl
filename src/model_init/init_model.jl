abstract type AbstractModel end
struct ECSModel{CS <: Tuple, CT <: Tuple, ST <: Tuple, N, M} <: AbstractModel
    world::Ark.World{CS, CT, ST, N, M}
end

const Model = ECSModel

function ECSModel(parameters::Dict{String, Any}, init_conditions::Dict{String, Any})
    return ECSModel(Properties(parameters, init_conditions))
end

function ECSModel(parameters::Dict{String, Any}, init_conditions::InitialConditions)
    return ECSModel(parameters, initial_conditions_dict(init_conditions))
end

function ECSModel(properties::Properties)
    world = Ark.World(Components.COMPONENTS...)

    setup_firms!(world, properties)
    setup_workers!(world, properties)
    setup_bank!(world, properties)
    setup_central_bank!(world, properties)
    setup_government!(world, properties)
    setup_rotw!(world, properties)
    setup_aggregates!(world, properties)

    seed_initial_employment!(world, properties)
    initialize_household_incomes_and_balance_sheets!(world, properties)
    normalize_deposits_and_capital_stocks!(world)
    add_deposits_to_bank!(world)
    collect_data!(world)

    return ECSModel(world)
end

function seed_initial_employment!(world::Ark.World, properties::Properties)
    unemployed_workers = Ark.Entity[]
    for (worker_e, _) in Ark.Query(world, (Components.Unemployed,))
        append!(unemployed_workers, worker_e)
    end
    sort!(unemployed_workers)

    initial_assignments = Tuple{Ark.Entity, Ark.Entity, Float64}[]
    worker_index = 1
    firm_rows = Tuple{Ark.Entity, Int, Float64}[]
    for (firm_e, employment, average_wages) in Ark.Query(world, (Components.Employment, Components.AverageWageRate))
        for i in eachindex(firm_e)
            push!(firm_rows, (firm_e[i], employment[i].amount, average_wages[i].rate))
        end
    end
    sort!(firm_rows; by = first)

    for (firm_e, employment, wage_rate) in firm_rows
        for _ in 1:employment
                worker_index > length(unemployed_workers) && return nothing
                push!(initial_assignments, (unemployed_workers[worker_index], firm_e, wage_rate))
                worker_index += 1
        end
    end

    for (worker_e, firm_e, wage_rate) in initial_assignments
        Ark.exchange_components!(
            world,
            worker_e,
            remove = (Components.Unemployed,),
            add = (Components.Employed(wage_rate), Components.EmployedAt() => firm_e),
        )
    end

    return nothing
end

function initialize_household_incomes_and_balance_sheets!(world::Ark.World, properties::Properties)
    set_households_income!(world)

    household_debt_ratio = properties.initial_conditions.households.debt
    household_capital_ratio = properties.initial_conditions.households.capital
    for (_, income, deposits, capital) in Ark.Query(
            world,
            (
                Components.NetDisposableIncome,
                Components.Deposits,
                Components.CapitalStock,
            ),
            with = (Components.Household,),
        )
        deposits.amount .= household_debt_ratio .* income.amount
        capital.amount .= household_capital_ratio .* income.amount
    end

    return nothing
end

function normalize_deposits_and_capital_stocks!(world)
    total_disposable_income = @sum_over (income.amount for income in Ark.Query(world, (Components.NetDisposableIncome,)))


    for (_, capital, deposits) in Ark.Query(world, (Components.CapitalStock, Components.Deposits), with = (Components.Household,))
        capital.amount .= capital.amount ./ total_disposable_income
        deposits.amount .= deposits.amount ./ total_disposable_income
    end

    return nothing
end

function add_deposits_to_bank!(world)
    total_deposits = @sum_over (deposits.amount for deposits in Ark.Query(world, (Components.Deposits,)))
    total_loans = @sum_over (loans.amount for loans in Ark.Query(world, (Components.LoansOutstanding,)))

    for (_, equity, residual_items) in Ark.Query(world, (Components.Equity, Components.ResidualItems), with = (Components.Bank,))
        residual_items.amount .= equity.amount .- total_loans .+ total_deposits
    end

    return
end

function properties(m::ECSModel)
    return Ark.get_resource(m.world, Properties)
end

function Base.getproperty(m::ECSModel, name::Symbol)
    if name === :data
        return Ark.get_resource(m.world, DataCollector)
    elseif name === :properties
        return Ark.get_resource(m.world, Properties)
    else
        return getfield(m, name)
    end
end
