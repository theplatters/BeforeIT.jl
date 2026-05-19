@register struct Employed <: AbstractComponent
    rate::FloatType
end

@register :relation struct EmployedAt end

@register struct Inactive <: AbstractComponent end

@register struct Unemployed <: AbstractComponent
    unemployment_benefits::FloatType
end
