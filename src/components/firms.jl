abstract type FirmComponent <: AbstractComponent end

@register struct PrincipalProduct <: FirmComponent #G_i
    id::IntType
end

@register struct LaborProductivity <: FirmComponent #alpha_bar_i
    value::FloatType
end

@register struct IntermediateProductivity <: FirmComponent #beta_i
    value::FloatType
end

@register struct CapitalProductivity <: FirmComponent #kappa_i
    value::FloatType
end

@register struct FirmProperties
    intermediate_productivity::FloatType
    capital_productivity::FloatType
    labor_productivity::FloatType
    capital_deprecation_rate::FloatType
end

@register struct CapitalDeprecationRate <: FirmComponent #delta_i
    rate::FloatType
end

@register struct OperatingMargins <: FirmComponent  #pi_bar_i
    rate::FloatType
end

@register struct WageBill <: FirmComponent #w_i
    amount::FloatType
end

@register struct AverageWageRate <: FirmComponent #w_bar_i
    rate::FloatType
end

@register struct TaxRates <: FirmComponent #tau_Y
    output::FloatType
    capital::FloatType
end

@register struct Price <: FirmComponent #P_i
    value::FloatType
end

@register struct PriceIndex <: FirmComponent #P_bar_i
    value::FloatType
end

@register struct CFPriceIndex <: FirmComponent #P_CF_i
    value::FloatType
end

@register struct Employment <: FirmComponent #N_i
    amount::IntType
end

@register struct Vacancies <: FirmComponent #V_i
    amount::IntType
end

@register struct DesiredEmployment <: FirmComponent #N_d_i
    amount::IntType
end

@register struct Output <: FirmComponent #Y_i
    amount::FloatType
end

@register struct Sales <: FirmComponent #Q_i
    amount::FloatType
end

@register struct GoodsDemand <: FirmComponent #Q_d_i
    amount::FloatType
end

@register struct Inventories <: FirmComponent #S_i
    amount::FloatType
end

@register struct Intermediates <: FirmComponent #M_i
    amount::FloatType
end

@register struct Investment <: FirmComponent  #I_i
    amount::FloatType
end

@register struct Equity <: FirmComponent #E_i
    amount::FloatType
end

@register struct FinalGoodsStockChange <: FirmComponent #DS_i
    amount::FloatType
end

@register struct MaterialsStockChange <: FirmComponent #DM_i
    amount::FloatType
end

@register struct TargetLoans <: FirmComponent #DL_d_i
    amount::FloatType
end

@register struct ExpectedCapital <: FirmComponent #K_e_i
    amount::FloatType
end

@register struct ExpectedLoans <: FirmComponent #L_e_i
    amount::FloatType
end

@register struct ExpectedSales <: FirmComponent #Q_s_i
    amount::FloatType
end

@register struct DesiredInvestment <: FirmComponent #I_d_i
    amount::FloatType
end

@register struct DesiredMaterials <: FirmComponent #DM_d_i
    amount::FloatType
end

@register struct Owner <: Ark.Relationship
end

@register struct Capitalist <: FirmComponent end

@register struct Firm <: FirmComponent end
