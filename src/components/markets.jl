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

@register struct FirstPassIntermediateDemand <: AbstractComponent
    amount::Vector{Float64}
end

@register struct FirstPassFinalDemand <: AbstractComponent
    amount::Vector{Float64}
end

@register struct MarketSupplyPool <: AbstractComponent
    amount::Vector{Float64}
end

@register struct MarketCapacityPool <: AbstractComponent
    amount::Vector{Float64}
end

@register struct MarketPricePool <: AbstractComponent
    value::Vector{Float64}
end

@register struct MarketWeights <: AbstractComponent
    value::Vector{Float64}
end

@register struct ActiveBuyers <: AbstractComponent
    ids::Vector{Int}
end


@register struct MarketWeightVector <: AbstractComponent
    value::FixedSizeWeightVector
end

@register :relation struct Market <: AbstractComponent
end
