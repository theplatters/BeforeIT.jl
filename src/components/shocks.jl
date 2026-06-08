abstract type AbstractShock <: AbstractComponent end

@register struct Shock <: AbstractShock end

@register struct InterestRateShock <: AbstractShock
    rate::FloatType
    final_time::Int
end

@register struct ProductivityShock <: AbstractShock
    productivity_multiplier::Float64    # productivity multiplier
end

@register struct ConsumptionShock <: AbstractShock
    consumption_multiplier::Float64    # productivity multiplier
    final_time::Int
end
