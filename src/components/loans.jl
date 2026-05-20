@register struct LoansOutstanding <: AbstractComponent #L_i
    amount::FloatType
end

@register struct LoanFlow <: AbstractComponent  #DL_i
    amount::FloatType
end
