using BenchmarkTools

function process_benches(suite::BenchmarkGroup)::Vector{Row}
    data = Vector{Row}()
    sorted_keys = sort(collect(keys(suite)))

    for name in sorted_keys
        bench = suite[name]
        m = median(bench)

        time_ns = m.time * 10^6
        total_allocs = round(Int, m.allocs)
        total_bytes = round(Int, m.bytes)
        push!(data, Row(name, time_ns, total_allocs, total_bytes))
    end

    return data
end
