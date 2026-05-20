using BenchmarkTools

function process_benches(suite::BenchmarkGroup)::Vector{Row}
    data = Vector{Row}()
    sorted_keys = sort(collect(keys(suite)))

    for name in sorted_keys
        bench = suite[name]
        mean_secs = median(map(s -> s.time, bench.samples))

        total_allocs = round(Int, median(map(s -> s.allocs, bench.samples)))
        total_bytes = round(Int, median(map(s -> s.bytes, bench.samples)))
        push!(data, Row(name, mean_secs, total_allocs, total_bytes))
    end

    return data
end
