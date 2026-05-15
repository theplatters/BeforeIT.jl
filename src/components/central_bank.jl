struct NominalInterestRate <: AbstractComponent
    rate::FloatType
end

struct GovernmentBondInterestRate <: AbstractComponent
    rate::FloatType
end

struct GradualAdjustmentRate <: AbstractComponent
    rate::FloatType
end

struct EquilibriumInterestRate <: AbstractComponent
    rate::FloatType
end

struct InflationTargetingWeight <: AbstractComponent
    weight::FloatType
end

struct EconomicWeight <: AbstractComponent
    weight::FloatType
end

struct CentralBank <: AbstractComponent end
