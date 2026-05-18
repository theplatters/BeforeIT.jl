
@register struct ResidualItems <: AbstractComponent
    amount::FloatType
end

@register struct LendingRate <: AbstractComponent
    rate::FloatType
end

@register struct Banker <: AbstractComponent end

@register struct Bank <: AbstractComponent end
