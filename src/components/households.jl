@register struct NetDisposableIncome <: AbstractComponent
    amount::FloatType
end

@register struct ExpectedIncome <: AbstractComponent
    amount::FloatType
end

@register struct Deposits <: AbstractComponent
    amount::FloatType
end

@register struct CapitalStock <: AbstractComponent
    amount::FloatType
end

@register struct ConsumptionBudget <: AbstractComponent
    amount::FloatType
end

@register struct InvestmentBudget <: AbstractComponent
    amount::FloatType
end

@register struct RealisedConsumption <: AbstractComponent
    amount::FloatType
end

@register struct RealisedInvestment <: AbstractComponent
    amount::FloatType
end

@register struct Household <: AbstractComponent end
