mutable struct HiringFirmsCache
    vacancies::Vector{Int64}
    active::Vector{Int64}
    employment::Vector{Int64}
    firms::Vector{Ark.Entity}
    current_index::Int64
    nhiring::Int64
end

function HiringFirmsCache(size::Int64)
    return HiringFirmsCache(
        Vector{Int64}(undef, size),
        Vector{Int64}(undef, size),
        Vector{Int64}(undef, size),
        Vector{Ark.Entity}(undef, size),
        1,
        0,
    )
end

function emblace!(vacancies, employed, entity, cache::HiringFirmsCache)
    cache.vacancies[cache.current_index] = vacancies
    cache.employment[cache.current_index] = employed
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
    employed::Vector{Bool}
    newly_employed::Vector{Bool}
    employed_at::Vector{Ark.Entity}
    worker::Vector{Ark.Entity}
    active::Vector{Int64}
    current_index::Int64
    n_unemployed::Int64
end

function WorkersCache(size::Int64)
    return WorkersCache(
        Vector{Bool}(undef, size),
        Vector{Bool}(undef, size),
        Vector{Ark.Entity}(undef, size),
        Vector{Ark.Entity}(undef, size),
        Vector{Int64}(undef, size),
        1,
        0
    )
end

function emblace_unemployed!(entity::Ark.Entity, cache::WorkersCache)
    cache.employed[cache.current_index] = false

    cache.n_unemployed += 1
    cache.active[cache.n_unemployed] = cache.current_index
    cache.worker[cache.current_index] = entity

    cache.current_index += 1
    return nothing
end

function emblace_employed!(entity::Ark.Entity, employed_at::Ark.Entity, cache::WorkersCache)
    cache.employed[cache.current_index] = true
    cache.employed_at[cache.current_index] = employed_at
    cache.worker[cache.current_index] = entity
    cache.current_index += 1
    return nothing
end

function reset_cache!(cache::WorkersCache)
    cache.current_index = 1
    cache.n_unemployed = 0
    return nothing
end
