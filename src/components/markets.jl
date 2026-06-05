@register struct MarketDemandBook <: AbstractComponent
    amount::Vector{Float64}
end

@register struct MarketDemandClearing <: AbstractComponent
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
