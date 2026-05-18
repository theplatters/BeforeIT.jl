abstract type GovernmentComponent <: AbstractComponent end

@register struct GovernmentRevenues <: GovernmentComponent #Y_G
    amount::FloatType
end

@register struct SocialBenefitsInactive <: GovernmentComponent #sb_inact
    amount::FloatType
end

@register struct SocialBenefitsOther <: GovernmentComponent #sb_other
    amount::FloatType
end

@register struct PriceInflationGovernmentGoods <: GovernmentComponent #P_j
    value::FloatType
end

@register struct GovernmentDebt <: GovernmentComponent #L_G
    amount::FloatType
end

@register struct ConsumptionDemand <: GovernmentComponent #C_G
    amount::FloatType
end

@register struct LocalGovernment <: Ark.Relationship end

@register struct Government <: GovernmentComponent end
