abstract type FirmComponent <: AbstractComponent end

struct PrincipalProduct <: FirmComponent #G_i
    id::IntType
end

struct LaborProductivity <: FirmComponent #alpha_bar_i
    value::FloatType
end

struct IntermediateProductivity <: FirmComponent #beta_i
    value::FloatType
end

struct CapitalProductivity <: FirmComponent #kappa_i
    value::FloatType
end

struct FirmProperties
    intermediate_productivity::FloatType
    capital_productivity::FloatType
    labor_productivity::FloatType
    capital_deprecation_rate::FloatType
end

struct CapitalDeprecationRate <: FirmComponent #delta_i
    rate::FloatType
end

struct OperatingMargins <: FirmComponent  #pi_bar_i
    rate::FloatType
end

struct WageBill <: FirmComponent #w_i
    amount::FloatType
end

struct AverageWageRate <: FirmComponent #w_bar_i
    rate::FloatType
end

struct TaxRates <: FirmComponent #tau_Y
    output::FloatType
    capital::FloatType
end

struct Price <: FirmComponent #P_i
    value::FloatType
end

struct PriceIndex <: FirmComponent #P_bar_i
    value::FloatType
end

struct CFPriceIndex <: FirmComponent #P_CF_i
    value::FloatType
end

struct Employment <: FirmComponent #N_i
    amount::IntType
end

struct Vacancies <: FirmComponent #V_i
    amount::IntType
end

struct DesiredEmployment <: FirmComponent #N_d_i
    amount::IntType
end

struct Output <: FirmComponent #Y_i
    amount::FloatType
end

struct Sales <: FirmComponent #Q_i
    amount::FloatType
end

struct GoodsDemand <: FirmComponent #Q_d_i
    amount::FloatType
end

struct Inventories <: FirmComponent #S_i
    amount::FloatType
end

struct Intermediates <: FirmComponent #M_i
    amount::FloatType
end

struct Investment <: FirmComponent  #I_i
    amount::FloatType
end

struct Equity <: FirmComponent #E_i
    amount::FloatType
end

struct FinalGoodsStockChange <: FirmComponent #DS_i
    amount::FloatType
end

struct MaterialsStockChange <: FirmComponent #DM_i
    amount::FloatType
end

struct TargetLoans <: FirmComponent #DL_d_i
    amount::FloatType
end

struct ExpectedCapital <: FirmComponent #K_e_i
    amount::FloatType
end

struct ExpectedLoans <: FirmComponent #L_e_i
    amount::FloatType
end

struct ExpectedSales <: FirmComponent #Q_s_i
    amount::FloatType
end

struct DesiredInvestment <: FirmComponent #I_d_i
    amount::FloatType
end

struct DesiredMaterials <: FirmComponent #DM_d_i
    amount::FloatType
end

struct Owner <: Ark.Relationship
end

struct Capitalist <: FirmComponent end

struct Firm <: FirmComponent end
