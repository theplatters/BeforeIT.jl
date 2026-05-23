function search_and_matching_labor!(world::Ark.World)
    calculate_initial_vacancies!(world)
    fire_employed_workers!(world)
    build_hiring_firms_cache!(world)
    build_worker_cache!(world)
    hire_workers!(world)
    return nothing
end

function calculate_initial_vacancies!(world::Ark.World)
    for (e, vacancies, desired_employment, employment) in Ark.Query(world, (Vacancies, DesiredEmployment, Employment))
        for i in eachindex(e)
            vacancies[i] = Vacancies(desired_employment[i].amount - employment[i].amount)
        end
    end
    return nothing
end

function build_hiring_firms_cache!(world)
    cache = Ark.get_resource(world, HiringFirmsCache)
    reset_cache!(cache)

    rows = Tuple{Ark.Entity, Int}[]
    for (e, desired_employment, employment) in Ark.Query(world, (DesiredEmployment, Employment))
        for i in eachindex(e)
            push!(rows, (e[i], desired_employment[i].amount - employment[i].amount))
        end
    end

    sort!(rows; by = first)
    for (entity, vacancies) in rows
        BeforeIT.emblace!(vacancies, entity, cache)
    end

    return nothing
end

function build_worker_cache!(world)

    cache = Ark.get_resource(world, WorkersCache)
    BeforeIT.reset_cache!(cache)

    unemployed_workers = Ark.Entity[]
    for (worker_e, _) in Ark.Query(world, (Unemployed,))
        append!(unemployed_workers, worker_e)
    end

    sort!(unemployed_workers)
    for worker_e in unemployed_workers
        BeforeIT.emblace_unemployed!(worker_e, cache)
    end

    return nothing
end

function fire_employed_workers!(world::Ark.World)
    employed_workers = Tuple{Ark.Entity, Ark.Entity, Float64}[]
    firm_state = Dict{Ark.Entity, Tuple{Vacancies, Employment}}()

    for (firm_e, vacancies, employment) in Ark.Query(world, (Vacancies, Employment))
        for i in eachindex(firm_e)
            firm_state[firm_e[i]] = (vacancies[i], employment[i])
            for (worker_e, employed) in Ark.Query(world, (Employed,), with = (EmployedAt => firm_e[i],))
                for j in eachindex(worker_e)
                    push!(employed_workers, (worker_e[j], firm_e[i], employed[j].rate))
                end
            end
        end
    end

    sort!(employed_workers; by = first)
    shuffle!(employed_workers)
    remove_employment = Vector{Ark.Entity}()
    unemployment_benefits = Dict{Ark.Entity, Float64}()
    for (worker_e, firm_e, wage_rate) in employed_workers
        vacancies, employment = firm_state[firm_e]
        vacancies.amount >= 0 && continue
        push!(remove_employment, worker_e)
        unemployment_benefits[worker_e] = wage_rate
        vacancies = Vacancies(vacancies.amount + 1)
        employment = Employment(employment.amount - 1)
    end

    for now_unemployed in remove_employment
        Ark.exchange_components!(
            world, now_unemployed,
            remove = (Employed, EmployedAt),
            add = (Unemployed(unemployment_benefits[now_unemployed]),)
        )
    end

    return nothing
end

function hire_workers!(world::Ark.World)

    cache = Ark.get_resource(world, HiringFirmsCache)
    worker_cache = Ark.get_resource(world, WorkersCache)

    add_employment = Tuple{Ark.Entity, Ark.Entity}[]
    hired_workers = Dict{Ark.Entity, Int}()


    shuffle!(view(worker_cache.active, 1:worker_cache.n_unemployed))
    next_worker = 1
    hired_count = 0
    while cache.nhiring > 0 && next_worker <= worker_cache.n_unemployed
        shuffle!(view(cache.active, 1:cache.nhiring))
        i = 1

        while i <= cache.nhiring && next_worker <= worker_cache.n_unemployed

            firm_index = cache.active[i]
            worker_index = worker_cache.active[next_worker]
            next_worker += 1
            hired_count += 1
            worker_e = worker_cache.worker[worker_index]
            firm_e = cache.firms[firm_index]
            push!(add_employment, (worker_e, firm_e))
            hired_workers[firm_e] = get(hired_workers, firm_e, 0) + 1

            cache.vacancies[firm_index] -= 1

            if iszero(cache.vacancies[firm_index])
                if i < cache.nhiring
                    cache.active[i:(cache.nhiring - 1)] = cache.active[(i + 1):cache.nhiring]
                end
                cache.nhiring -= 1
            else
                i += 1
            end
        end
    end

    remaining_unemployed = worker_cache.n_unemployed - hired_count
    if remaining_unemployed > 0 && hired_count > 0
        copyto!(worker_cache.active, 1, worker_cache.active, hired_count + 1, remaining_unemployed)
    end
    worker_cache.n_unemployed = remaining_unemployed

    for (worker_e, firm_e) in add_employment
        Ark.exchange_components!(
            world, worker_e,
            remove = (Unemployed,),
            add = (Employed(0.0), EmployedAt() => firm_e)
        )
    end

    for (firm_e, employment) in Ark.Query(world, (Employment,))
        for i in eachindex(firm_e)
            hired = get(hired_workers, firm_e[i], 0)
            hired == 0 && continue
            employment[i] = Employment(employment[i].amount + hired)
        end
    end


    return nothing
end
