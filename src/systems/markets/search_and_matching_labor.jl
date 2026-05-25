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
    remove_employment = Vector{Ark.Entity}()
    employed_workers = Tuple{Ark.Entity, Ark.Entity}[]

    for (worker_e, employed, employed_at) in Ark.Query(world, (Employed, EmployedAt))
        for j in eachindex(worker_e)
            push!(employed_workers, (worker_e[j], employed_at[j].entity))
        end
    end

    sort!(employed_workers; by = first)
    shuffle!(employed_workers)
    for (worker_e, firm_e) in employed_workers
        vacancies, employment = Ark.get_components(world, firm_e, (Vacancies, Employment))
        vacancies.amount >= 0 && continue
        push!(remove_employment, worker_e)
        Ark.set_components!(world, firm_e, 
            (Vacancies(vacancies.amount + 1), Employment(employment.amount - 1))
        )
    end

    for now_unemployed in remove_employment
        unemployment_benefit, = Ark.get_components(world, now_unemployed, (Employed,))
        Ark.exchange_components!(world, now_unemployed,
            remove = (Employed, EmployedAt),
            add = (Unemployed(unemployment_benefit.rate),)
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

    while cache.nhiring > 0 && next_worker <= worker_cache.n_unemployed
        shuffle!(view(cache.active, 1:cache.nhiring))

        new_nhiring = 0
        for i in 1:cache.nhiring
            next_worker > worker_cache.n_unemployed && break

            firm_index = cache.active[i]
            worker_index = worker_cache.active[next_worker]
            next_worker += 1

            worker_e = worker_cache.worker[worker_index]
            firm_e = cache.firms[firm_index]
            push!(add_employment, (worker_e, firm_e))
            hired_workers[firm_e] = get(hired_workers, firm_e, 0) + 1
            cache.vacancies[firm_index] -= 1

            if cache.vacancies[firm_index] > 0
                new_nhiring += 1
                cache.active[new_nhiring] = firm_index
            end
        end

        cache.nhiring = new_nhiring
    end

    worker_cache.n_unemployed -= next_worker - 1

    for (worker_e, firm_e) in add_employment
        Ark.exchange_components!(
            world, worker_e,
            remove = (Unemployed,),
            add = (Employed(0.0), EmployedAt(firm_e) => firm_e)
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
