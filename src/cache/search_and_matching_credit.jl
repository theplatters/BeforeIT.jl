
mutable struct CreditMatchingCache
    active_rows::Vector{Int}
end

function CreditMatchingCache(size::Int)
    return CreditMatchingCache(
        Vector{Int}(undef, size),
    )
end
