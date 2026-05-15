struct Employed <: AbstractComponent
    rate::FloatType
end

struct EmployedAt <: Ark.Relationship end

struct Inactive <: AbstractComponent end

struct Unemployed <: AbstractComponent
    unemployment_benefits::FloatType
end
