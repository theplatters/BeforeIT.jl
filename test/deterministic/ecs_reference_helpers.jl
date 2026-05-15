
function _query_rows(world, component_types; with = (), without = ())
    rows = NamedTuple[]
    for result in collect(Bit.Ark.Query(world, component_types, with = with, without = without))
        entities = result[1]
        components = result[2:end]
        for i in eachindex(entities)
            push!(rows, (entity = entities[i], components = map(c -> c[i], components)))
        end
    end
    sort!(rows; by = row -> row.entity)
    return rows
end

function _component_sum(world, component_type::Type; with = (), without = (), field::Symbol = :amount)
    total = 0.0
    for (_, values) in collect(Bit.Ark.Query(world, (component_type,), with = with, without = without))
        for i in eachindex(values)
            total += getfield(values[i], field)
        end
    end
    return total
end

function _component_mean(world, component_type::Type; with = (), without = (), field::Symbol = :amount, predicate = _ -> true)
    total = 0.0
    count = 0
    for (_, values) in collect(Bit.Ark.Query(world, (component_type,), with = with, without = without))
        for i in eachindex(values)
            value = getfield(values[i], field)
            predicate(value) || continue
            total += value
            count += 1
        end
    end
    return total / count
end

function _single_component_value(world, component_type::Type; with = (), field::Symbol = :amount)
    found = false
    value = nothing
    for (_, values) in collect(Bit.Ark.Query(world, (component_type,), with = with))
        value = getfield(values[1], field)
        found = true
        break
    end
    found || error("component $(component_type) not found")
    return value
end

function _active_household_reference_state(model)
    world = model.world
    rows = NamedTuple[]
    firm_entities = [row.entity for row in _query_rows(world, (Bit.Firm,))]
    worker_firm_index = Dict{Bit.Ark.Entity, Float64}()
    for (index, firm_entity) in pairs(firm_entities)
        for (worker_entities, _) in Bit.Ark.Query(world, (Bit.EmployedAt => firm_entity,))
            for worker_entity in worker_entities
                worker_firm_index[worker_entity] = Float64(index)
            end
        end
    end

    for row in _query_rows(
        world, 
        (Employed, NetDisposableIncome, Deposits, CapitalStock);
        with = (Household,),
    )
        employed, income, deposits, capital = row.components
        push!(
            rows, (
                entity = row.entity,
                w_h = employed.rate,
                O_h = worker_firm_index[row.entity],
                Y_h = income.amount,
                D_h = deposits.amount,
                K_h = capital.amount,
            )
        )
    end

    for row in _query_rows(
        world,
        (Unemployed, NetDisposableIncome, Deposits, CapitalStock);
        with = (Bit.Household,),
    )
        unemployed, income, deposits, capital = row.components
        push!(rows, (entity = row.entity, w_h = unemployed.unemployment_benefits, O_h = 0.0, Y_h = income.amount, D_h = deposits.amount, K_h = capital.amount))
    end

    sort!(rows; by = row -> row.entity)
    return (
        w_h = [row.w_h for row in rows],
        O_h = [row.O_h for row in rows],
        Y_h = [row.Y_h for row in rows],
        D_h = [row.D_h for row in rows],
        K_h = [row.K_h for row in rows],
    )
end

function _inactive_household_reference_state(model)
    world = model.world
    rows = _query_rows(
        world,
        (NetDisposableIncome, Deposits, CapitalStock);
        with = (Bit.Inactive,),
    )
    return (
        Y_h = [row.components[1].amount for row in rows],
        D_h = [row.components[2].amount for row in rows],
        K_h = [row.components[3].amount for row in rows],
    )
end

function _firm_owner_reference_state(model)
    world = model.world
    rows = _query_rows(
        world,
        (NetDisposableIncome, Deposits, CapitalStock);
        with = (Bit.Capitalist,),
    )
    return (
        Y_h = [row.components[1].amount for row in rows],
        D_h = [row.components[2].amount for row in rows],
        K_h = [row.components[3].amount for row in rows],
    )
end

function _bank_owner_reference_state(model)
    world = model.world
    rows = _query_rows(
        world,
        (NetDisposableIncome, Deposits, CapitalStock);
        with = (Bit.Banker,),
    )
    @assert length(rows) == 1
    return (
        Y_h = rows[1].components[1].amount,
        D_h = rows[1].components[2].amount,
        K_h = rows[1].components[3].amount,
    )
end

function _firm_reference_state(model)
    world = model.world
    rows = _query_rows(
        world,
        (PrincipalProduct, LaborProductivity, IntermediateProductivity,
         CapitalDeprecationRate, CapitalProductivity, OperatingMargins,
         TaxRates, AverageWageRate, Employment, Output, Price, GoodsDemand,
         Inventories, CapitalStock, Intermediates, LoansOutstanding, Deposits,
         Profits, Vacancies);
        with = (Firm,),
    )
    owners = _firm_owner_reference_state(model)
    return (
        D_h = owners.D_h,
        D_i = [row.components[17].amount for row in rows],
        G_i = [row.components[1].id for row in rows],
        K_h = owners.K_h,
        K_i = [row.components[14].amount for row in rows],
        L_i = [row.components[16].amount for row in rows],
        M_i = [row.components[15].amount for row in rows],
        N_i = [row.components[9].amount for row in rows],
        P_i = [row.components[11].value for row in rows],
        Pi_i = [row.components[18].amount for row in rows],
        Q_d_i = [row.components[12].amount for row in rows],
        S_i = [row.components[13].amount for row in rows],
        V_i = [row.components[19].amount - row.components[9].amount for row in rows],
        Y_h = owners.Y_h,
        Y_i = [row.components[10].amount for row in rows],
        alpha_bar_i = [row.components[2].value for row in rows],
        beta_i = [row.components[3].value for row in rows],
        delta_i = [row.components[4].rate for row in rows],
        kappa_i = [row.components[5].value for row in rows],
        pi_bar_i = [row.components[6].rate for row in rows],
        tau_K_i = [row.components[7].capital for row in rows],
        tau_Y_i = [row.components[7].output for row in rows],
        w_bar_i = [row.components[8].rate for row in rows],
    )
end

function _bank_reference_state(model)
    world = model.world
    return (
        D_k = _single_component_value(world, Bit.ResidualItems; with = (Bit.Bank,)),
        E_k = _single_component_value(world, Bit.Equity; with = (Bit.Bank,)),
        Pi_k = _single_component_value(world, Bit.Profits; with = (Bit.Bank,)),
        r = _single_component_value(world, Bit.LendingRate; with = (Bit.Bank,), field = :rate),
    )
end

function _all_household_reference_state(model)
    active = _active_household_reference_state(model)
    inactive = _inactive_household_reference_state(model)
    owners = _firm_owner_reference_state(model)
    banker = _bank_owner_reference_state(model)
    return (
        Y_h = vcat(active.Y_h, inactive.Y_h, owners.Y_h, [banker.Y_h]),
        D_h = vcat(active.D_h, inactive.D_h, owners.D_h, [banker.D_h]),
        K_h = vcat(active.K_h, inactive.K_h, owners.K_h, [banker.K_h]),
        O_h = active.O_h,
        w_h = active.w_h,
    )
end

_mat_vector(x::Number) = x
_mat_vector(x) = vec(x')
