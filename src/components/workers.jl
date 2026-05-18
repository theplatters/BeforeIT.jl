@register struct Employed <: AbstractComponent
    rate::FloatType
end

@register struct EmployedAt <: Ark.Relationship end

@register struct Inactive <: AbstractComponent end

@register struct Unemployed <: AbstractComponent
    unemployment_benefits::FloatType
end
