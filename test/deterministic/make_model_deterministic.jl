import BeforeIT as Bit

using Test
using Random
using Distributions

function Random.randn()
    return 0.0
end

function Random.rand(sp::Bit.WeightVectors.FixedSizeWeightVector)
    return findfirst(i -> !iszero(sp[i]), 1:length(sp))
end

function Random.rand(n::UnitRange)
    return 1
end

function Random.rand(n::Normal)
    return 0.0
end

function Bit.randpl(n::Int, alpha::Float64, N::Int)
    # return a vector of n numbers that sum to N
    to_return = [Int(round(N / n + 1.0e-7)) for _ in 1:n]
    return to_return
end

function Bit.epsilon(C::Matrix{Float64})
    return (0.0, 0.0, 0.0)
end

function Random.shuffle!(v::AbstractVector)
    # do nothing
end

function Bit.Ark.shuffle_entities!(::Bit.Ark.Filter)
    # do nothing
end
