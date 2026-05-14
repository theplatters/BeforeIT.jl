function search_and_matching_labor!(world::Ark.World)
    calculate_initial_vacancies!(world)
    fire_employed_workers!(world)
    build_hiring_firms_cache!(world)
    build_worker_cache!(world)
    hire_workers!(world)
    return nothing
end

function calculate_initial_vacancies!(world::Ark.World)
    for (_, vacancies, desired_employment, employment) in Ark.Query(world, (Components.Vacancies, Components.DesiredEmployment, Components.Employment))
        vacancies.amount .= desired_employment.amount - employment.amount
    end
    return nothing
end

function build_hiring_firms_cache!(world)
    cache = Ark.get_resource(world, HiringFirmsCache)
    reset_cache!(cache)

    for (e, desired_employment, employment) in Ark.Query(world, (Components.DesiredEmployment, Components.Employment))
        for i in eachindex(e)
            BeforeIT.emblace!(desired_employment[i].amount - employment[i].amount, employment[i].amount, e[i], cache)
        end
    end

    return nothing
end

function build_worker_cache!(world)

    cache = Ark.get_resource(world, WorkersCache)
    BeforeIT.reset_cache!(cache)

    for (worker_e, _) in Ark.Query(world, (Components.Unemployed,))
        for i in eachindex(worker_e)
            BeforeIT.emblace_unemployed!(worker_e[i], cache)
        end
    end

    for (firm_e, _employment) in Ark.Query(world, (Components.Employment,))
        for i in eachindex(firm_e)
            for (worker_e, _) in Ark.Query(world, (Components.EmployedAt => firm_e[i],))
                for j in eachindex(worker_e)
                    BeforeIT.emblace_employed!(worker_e[j], firm_e[i], cache)
                end
            end
        end
    end

    return nothing
end

function fire_employed_workers!(world::Ark.World)
    f = Ark.Filter(world, (Components.Employed,), with = (Components.EmployedAt,))
    Ark.shuffle_entities!(f)
    remove_employment = Vector{Ark.Entity}()
    for (firm_e, vacancies, employment) in Ark.Query(world, (Components.Vacancies, Components.Employment))
        for i in eachindex(firm_e)
            for (worker_e, _) in Ark.Query(world, (Components.EmployedAt => firm_e[i],))
                for j in eachindex(worker_e)
                    vacancies[i].amount >= 0 && break
                    push!(remove_employment, worker_e[j])
                    vacancies[i] = Components.Vacancies(vacancies[i].amount + 1)
                    employment[i] = Components.Employment(employment[i].amount - 1)
                end
            end
        end
    end

    for now_unemployed in remove_employment
        Ark.exchange_components!(
            world, now_unemployed,
            remove = (Components.Employed, Components.EmployedAt),
            add = (Components.Unemployed(0.0),)
        )
    end

    return nothing
end

function hire_workers!(world::Ark.World)

    cache = Ark.get_resource(world, HiringFirmsCache)
    worker_cache = Ark.get_resource(world, WorkersCache)

    add_employment = Dict{Ark.Entity, Ark.Entity}()
    hired_workers = Dict{Ark.Entity, Int}()


    shuffle!(view(worker_cache.active, 1:worker_cache.n_unemployed))
    while cache.nhiring > 0 && worker_cache.n_unemployed > 0
        shuffle!(view(cache.active, 1:cache.nhiring))
        i = 1

        while i <= cache.nhiring && worker_cache.n_unemployed > 0

            firm_index = cache.active[i]
            worker_e = worker_cache.worker[worker_cache.active[worker_cache.n_unemployed]]
            firm_e = cache.firms[firm_index]
            add_employment[worker_e] = firm_e
            hired_workers[firm_e] = get(hired_workers, firm_e, 0) + 1
            worker_cache.n_unemployed -= 1
            cache.vacancies[firm_index] -= 1

            if iszero(cache.vacancies[firm_index])
                cache.active[i] = cache.active[cache.nhiring]
                cache.nhiring -= 1
            else
                i += 1
            end
        end
    end

    for (worker_e, firm_e) in add_employment
        Ark.exchange_components!(
            world, worker_e,
            remove = (Components.Unemployed,),
            add = (Components.Employed(0.0), Components.EmployedAt() => firm_e)
        )
    end

    for (firm_e, employment) in Ark.Query(world, (Components.Employment,))
        for i in eachindex(firm_e)
            hired = get(hired_workers, firm_e[i], 0)
            hired == 0 && continue
            employment[i] = Components.Employment(employment[i].amount + hired)
        end
    end


    return nothing
end
