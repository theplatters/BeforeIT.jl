struct NetDisposableIncome <: AbstractComponent
    amount::FloatType
end

struct ExpectedIncome <: AbstractComponent
    amount::FloatType
end

struct Deposits <: AbstractComponent
    amount::FloatType
end

struct CapitalStock <: AbstractComponent
    amount::FloatType
end

struct ConsumptionBudget <: AbstractComponent
    amount::FloatType
end

struct InvestmentBudget <: AbstractComponent
    amount::FloatType
end

struct RealisedConsumption <: AbstractComponent
    amount::FloatType
end

struct RealisedInvestment <: AbstractComponent
    amount::FloatType
end

struct Household <: AbstractComponent end
