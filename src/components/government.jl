abstract type GovernmentComponent <: AbstractComponent end

struct GovernmentRevenues <: GovernmentComponent #Y_G
    amount::FloatType
end

struct SocialBenefitsInactive <: GovernmentComponent #sb_inact
    amount::FloatType
end

struct SocialBenefitsOther <: GovernmentComponent #sb_other
    amount::FloatType
end

struct PriceInflationGovernmentGoods <: GovernmentComponent #P_j
    value::FloatType
end

struct GovernmentDebt <: GovernmentComponent #L_G
    amount::FloatType
end

struct ConsumptionDemand <: GovernmentComponent #C_G
    amount::FloatType
end

struct LocalGovernment <: Ark.Relationship end

struct Government <: GovernmentComponent end
