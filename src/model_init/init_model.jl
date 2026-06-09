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
    world = Ark.World(Tuple(BIT_COMPONENTS)...; initial_capacity = 16)

    markets = setup_markets!(world, properties)
    setup_firms!(world, properties, markets)
    setup_workers!(world, properties)
    setup_bank!(world, properties)
    setup_central_bank!(world, properties)
    setup_government!(world, properties)
    setup_rotw!(world, properties, markets)
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
    @dub for t in Ark.Query(world, (Unemployed,))
        append!(unemployed_workers, t.e)
    end
    sort!(unemployed_workers)

    initial_assignments = Tuple{Ark.Entity, Ark.Entity, Float64}[]
    worker_index = 1
    firm_rows = Tuple{Ark.Entity, Int, Float64}[]
    @dub for t in Ark.Query(world, (Employment, AverageWageRate))
        for i in eachindex(t.e)
            push!(firm_rows, (t.e[i], t.employment[i].amount, t.average_wage_rate[i].rate))
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
            remove = (Unemployed,),
            add = (Employed(wage_rate), EmployedAt(firm_e) => firm_e),
        )
    end

    return nothing
end

function initialize_household_incomes_and_balance_sheets!(world::Ark.World, properties::Properties)
    set_households_income!(world)

    household_debt_ratio = properties.initial_conditions.households.debt
    household_capital_ratio = properties.initial_conditions.households.capital
    @dub for t in Ark.Query(
        world, (NetDisposableIncome, Deposits, CapitalStock), with = (Household,),
    )
        t.deposits.amount .= household_debt_ratio .* t.net_disposable_income.amount
        t.capital_stock.amount .= household_capital_ratio .* t.net_disposable_income.amount
    end

    return nothing
end

function normalize_deposits_and_capital_stocks!(world)
    total_disposable_income = sum_amount(world, NetDisposableIncome)

    @dub for t in Ark.Query(world, (CapitalStock, Deposits), with = (Household,))
        t.capital_stock.amount .= t.capital_stock.amount ./ total_disposable_income
        t.deposits.amount .= t.deposits.amount ./ total_disposable_income
    end

    return nothing
end

function add_deposits_to_bank!(world)
    total_deposits = sum_amount(world, Deposits)
    total_loans = sum_amount(world, LoansOutstanding)

    @dub for t in Ark.Query(world, (Equity, ResidualItems), with = (Bank,))
        t.residual_items.amount .= t.equity.amount .- total_loans .+ total_deposits
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
