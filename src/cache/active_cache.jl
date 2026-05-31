struct SerialActiveCache
    active::Vector{Int}
end


function SerialActiveCache(intermediate_cache, consumption_cache)
    max_npotential_buyers = max(size(intermediate_cache.vals, 1), size(consumption_cache.vals, 1))
    return SerialActiveCache(Vector{Int64}(undef, max_npotential_buyers))
end

struct ParallelActiveCache
    active::Vector{Tuple{Vector{Int}, Vector{Int}}}
end

function ParallelActiveCache(intermediate_cache, consumption_cache, dimensions)

    sectors = dimensions.sectors

    t_active_buffer = [
        (
                sector_range,
                Vector{Int64}(
                    undef,
                    max(size(intermediate_cache.vals[:, sector_range], 1), size(consumption_cache.vals[:, sector_range], 1))
                ),
            ) for sector_range in Iterators.partition(1:sectors, cld(sectors, Threads.nthreads()))
    ]
    return ParallelActiveCache(t_active_buffer)
end
