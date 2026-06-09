struct CreditMatchingCache
    active_firms::Vector{Ark.Entity}
end

function CreditMatchingCache(size::Int)
    return CreditMatchingCache(Vector{Ark.Entity}(undef, size))
end
