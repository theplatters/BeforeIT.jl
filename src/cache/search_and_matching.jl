abstract type AbstractDemandCache end

mutable struct DemandCache{Kind} <: AbstractDemandCache
    vals::Matrix{Float64}
    nominal::Matrix{Float64}
    current_index::Int64
end

const DesiredIntermediatesCache = DemandCache{:intermediates}
const DesiredHouseholdConsumptionCache = DemandCache{:household_consumption}

function reserve_row!(entity, cache::T) where {T <: AbstractDemandCache}
    row = cache.current_index
    cache.current_index += 1
    return row
end

function reset_cache!(cache::T) where {T <: AbstractDemandCache}
    cache.current_index = 1
    cache.nominal .= 0.0
    return nothing
end

function (::Type{T})(values::Int64, sectors::Int64) where {T <: AbstractDemandCache}
    return T(Matrix{Float64}(undef, values, sectors), zeros(values, sectors), 1)
end


struct StockCache
    available_stocks::Vector{Vector{Float64}}
    stock_capacity::Vector{Vector{Float64}}
    prices::Vector{Vector{Float64}}
    weights::Vector{Vector{Float64}}
    weight_vectors::Vector{FixedSizeWeightVector}
    current_indices::Vector{Int64}
end

function StockCache(size::Int64, sectors::Int64, firms_per_sector)
    available_stocks = [Vector{Float64}(undef, firms_per_sector[g] + 1) for g in 1:sectors]
    stock_capacity = [Vector{Float64}(undef, firms_per_sector[g] + 1) for g in 1:sectors]
    prices = [Vector{Float64}(undef, firms_per_sector[g] + 1) for g in 1:sectors]
    weights = [Vector{Float64}(undef, firms_per_sector[g] + 1) for g in 1:sectors]
    weight_vectors = [FixedSizeWeightVector(firms_per_sector[g] + 1) for g in 1:sectors]
    current_indices = ones(Int64, sectors)

    return StockCache(
        available_stocks,
        stock_capacity,
        prices,
        weights,
        weight_vectors,
        current_indices,
    )
end

function emblace!(available, stock_capacity, price, sector, entity, cache::StockCache)
    idx = cache.current_indices[sector]
    cache.available_stocks[sector][idx] = available
    cache.stock_capacity[sector][idx] = stock_capacity
    cache.prices[sector][idx] = price
    cache.current_indices[sector] += 1
    return nothing
end


function reset_cache!(cache::StockCache)
    fill!(cache.current_indices, 1)
    return nothing
end


function finalize_stock_cache!(cache::StockCache, world::Ark.World)
    @inbounds for g in eachindex(cache.available_stocks)
        build_sampling_weights!(
            cache.weights[g],
            cache.prices[g],
            cache.available_stocks[g]
        )
    end
    return
end

function get_available_stocks(cache::StockCache, sector::Int64)
    return cache.available_stocks[sector]
end

function get_stock_capacity(cache::StockCache, sector::Int64)
    return cache.stock_capacity[sector]
end

function get_prices(cache::StockCache, sector::Int64)
    return cache.prices[sector]
end

function get_weights(cache::StockCache, sector::Int64)
    return cache.weights[sector]
end

function get_weight_vector(cache::StockCache, sector::Int64)
    weights = get_weights(cache, sector)
    if length(cache.weight_vectors[sector]) != length(weights)
        cache.weight_vectors[sector] = FixedSizeWeightVector(length(weights))
    end
    wv = cache.weight_vectors[sector]
    for (i, w) in enumerate(weights)
        wv[i] = w
    end
    return wv
end

function build_sampling_weights!(
        weights::AbstractVector{Float64},
        price::AbstractVector{Float64},
        stock::AbstractVector{Float64},
    )
    @assert length(weights) == length(price) == length(stock)
    price_sum = 0.0
    size_sum = 0.0
    @inbounds for i in eachindex(price, stock)
        if stock[i] > 0.0
            wp = exp(-2.0 * price[i])
            ws = stock[i]
            weights[i] = wp
            price_sum += wp
            size_sum += ws
        else
            weights[i] = 0.0
        end
    end

    inv_price_sum = price_sum > 0 ? inv(price_sum) : 0.0
    inv_size_sum = size_sum > 0 ? inv(size_sum) : 0.0
    @inbounds for i in eachindex(weights, price, stock)
        if weights[i] > 0.0
            weights[i] = weights[i] * inv_price_sum + stock[i] * inv_size_sum
        end
    end
    return weights
end

function choose_random_firm(cache::StockCache, sector, weights)
    return rand(weights)
end
