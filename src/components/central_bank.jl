@register struct NominalInterestRate <: AbstractComponent
    rate::FloatType
end

@register struct GovernmentBondInterestRate <: AbstractComponent
    rate::FloatType
end

@register struct GradualAdjustmentRate <: AbstractComponent
    rate::FloatType
end

@register struct EquilibriumInterestRate <: AbstractComponent
    rate::FloatType
end

@register struct InflationTargetingWeight <: AbstractComponent
    weight::FloatType
end

@register struct EconomicWeight <: AbstractComponent
    weight::FloatType
end

@register struct CentralBank <: AbstractComponent end
