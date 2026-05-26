abstract type AbstractActiveCache end

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

    (; firms_per_sector, sectors) = dimensions

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

function partition_sectors_by_firms(firms_per_sector, total_sectors, n_threads)
    if total_sectors <= n_threads
        return [g:g for g in 1:total_sectors]
    end

    total_firms = sum(firms_per_sector)
    target_per_thread = total_firms / n_threads

    partitions = Vector{UnitRange{Int64}}()

    current_start = 1
    current_sum = 0

    for g in 1:total_sectors
        current_sum += firms_per_sector[g]

        if current_sum >= target_per_thread && length(partitions) < n_threads - 1
            push!(partitions, current_start:g)
            current_start = g + 1
            current_sum = 0
        end
    end

    if current_start <= total_sectors
        push!(partitions, current_start:total_sectors)
    end

    return partitions
end
