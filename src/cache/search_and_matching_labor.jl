mutable struct HiringFirmsCache
    vacancies::Vector{Int64}
    active::Vector{Int64}
    firms::Vector{Ark.Entity}
    current_index::Int64
    nhiring::Int64
end

function HiringFirmsCache(size::Int64)
    return HiringFirmsCache(
        Vector{Int64}(undef, size), Vector{Int64}(undef, size),
        Vector{Ark.Entity}(undef, size), 1, 0,
    )
end

function emblace!(vacancies, entity, cache::HiringFirmsCache)
    cache.vacancies[cache.current_index] = vacancies
    if vacancies > 0
        cache.nhiring += 1
        cache.active[cache.nhiring] = cache.current_index
    end
    cache.firms[cache.current_index] = entity
    cache.current_index += 1
    return nothing
end

function reset_cache!(cache::HiringFirmsCache)
    cache.current_index = 1
    cache.nhiring = 0
    return nothing
end


mutable struct WorkersCache
    worker::Vector{Ark.Entity}
    active::Vector{Int64}
    unemployed_workers::Vector{Ark.Entity}
    n_unemployed::Int64
end

function WorkersCache(size::Int64)
    unemployed_workers = Ark.Entity[]
    sizehint!(unemployed_workers, size)
    return WorkersCache(
        Vector{Ark.Entity}(undef, size),
        Vector{Int64}(undef, size),
        unemployed_workers,
        0
    )
end

function emblace_unemployed!(entity::Ark.Entity, cache::WorkersCache)
    cache.n_unemployed += 1
    cache.active[cache.n_unemployed] = cache.n_unemployed
    cache.worker[cache.n_unemployed] = entity
    return nothing
end

function reset_cache!(cache::WorkersCache)
    empty!(cache.unemployed_workers)
    cache.n_unemployed = 0
    return nothing
end


struct FireEmployedWorkersCache
    remove_employment::Vector{Ark.Entity}
    employed_workers::Vector{Tuple{Ark.Entity, Ark.Entity}}
end

function FireEmployedWorkersCache(size::Int64)
    remove_employment = Ark.Entity[]
    employed_workers = Tuple{Ark.Entity, Ark.Entity}[]
    sizehint!(remove_employment, size)
    sizehint!(employed_workers, size)
    return FireEmployedWorkersCache(remove_employment, employed_workers)
end

function reset_cache!(cache::FireEmployedWorkersCache)
    empty!(cache.remove_employment)
    empty!(cache.employed_workers)
    return nothing
end


struct HireWorkersCache
    add_employment::Vector{Tuple{Ark.Entity, Ark.Entity}}
    hired_workers::Dict{Ark.Entity, Int64}
end

function HireWorkersCache(worker_size::Int64, firm_size::Int64)
    add_employment = Tuple{Ark.Entity, Ark.Entity}[]
    hired_workers = Dict{Ark.Entity, Int64}()
    sizehint!(add_employment, worker_size)
    sizehint!(hired_workers, firm_size)
    return HireWorkersCache(add_employment, hired_workers)
end

function reset_cache!(cache::HireWorkersCache)
    empty!(cache.add_employment)
    empty!(cache.hired_workers)
    return nothing
end
