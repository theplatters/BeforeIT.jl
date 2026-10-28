@register struct ResidualItems <: AbstractComponent
    amount::FloatType
end

@register struct LendingRate <: AbstractComponent
    rate::FloatType
end

@register struct Banker <: AbstractComponent end

@register struct Bank <: AbstractComponent end

# Relation from a firm or household to the bank holding its deposits and loans.
@register :relation struct BankAccount end
