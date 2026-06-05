@register struct FinalMarketDemandBook <: AbstractComponent
    amount::Vector{Float64}
end

@register struct FinalMarketDemandClearing <: AbstractComponent
    amount::Vector{Float64}
end

@register struct IntermediateMarketDemandBook <: AbstractComponent
    amount::Vector{Float64}
end

@register struct IntermediateMarketDemandClearing <: AbstractComponent
    amount::Vector{Float64}
end

@register struct MarketSupplyPool <: AbstractComponent
    amount::Vector{Float64}
end

@register struct MarketCapacityPool <: AbstractComponent
    amount::Vector{Float64}
end

@register struct MarketPricePool <: AbstractComponent
    amount::Vector{Float64}
end
