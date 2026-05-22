mutable struct HiringFirmsCache
    vacancies::Vector{Int64}
    active::Vector{Int64}
    firms::Vector{Ark.Entity}
    current_index::Int64
    nhiring::Int64
end

function HiringFirmsCache(size::Int64)
    return HiringFirmsCache(
        Vector{Int64}(undef, size),
        Vector{Int64}(undef, size),
        Vector{Ark.Entity}(undef, size),
        1,
        0,
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
    n_unemployed::Int64
end

function WorkersCache(size::Int64)
    return WorkersCache(
        Vector{Ark.Entity}(undef, size),
        Vector{Int64}(undef, size),
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
    cache.n_unemployed = 0
    return nothing
end
