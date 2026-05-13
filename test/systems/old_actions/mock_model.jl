# --- Mock Definitions for OOP Parity Testing ---

Base.@kwdef mutable struct MockWorkers
    Y_h::Vector{Float64} = Float64[]
    D_h::Vector{Float64} = Float64[]
    K_h::Vector{Float64} = Float64[]
    w_h::Vector{Float64} = Float64[]
    O_h::Vector{Int} = Int[]
    C_d_h::Vector{Float64} = Float64[]
    I_d_h::Vector{Float64} = Float64[]
    C_h::Vector{Float64} = Float64[]
    I_h::Vector{Float64} = Float64[]
end

Base.@kwdef mutable struct MockFirms
    G_i::Vector{Int} = Int[]
    alpha_bar_i::Vector{Float64} = Float64[]
    beta_i::Vector{Float64} = Float64[]
    kappa_i::Vector{Float64} = Float64[]
    w_i::Vector{Float64} = Float64[]
    w_bar_i::Vector{Float64} = Float64[]
    delta_i::Vector{Float64} = Float64[]
    tau_Y_i::Vector{Float64} = Float64[]
    tau_K_i::Vector{Float64} = Float64[]
    N_i::Vector{Int} = Int[]
    Y_i::Vector{Float64} = Float64[]
    Q_i::Vector{Float64} = Float64[]
    Q_d_i::Vector{Float64} = Float64[]
    P_i::Vector{Float64} = Float64[]
    S_i::Vector{Float64} = Float64[]
    K_i::Vector{Float64} = Float64[]
    M_i::Vector{Float64} = Float64[]
    L_i::Vector{Float64} = Float64[]
    pi_bar_i::Vector{Float64} = Float64[]
    D_i::Vector{Float64} = Float64[]
    Pi_i::Vector{Float64} = Float64[]
    V_i::Vector{Int} = Int[]
    I_i::Vector{Float64} = Float64[]
    E_i::Vector{Float64} = Float64[]
    P_bar_i::Vector{Float64} = Float64[]
    P_CF_i::Vector{Float64} = Float64[]
    DS_i::Vector{Float64} = Float64[]
    DM_i::Vector{Float64} = Float64[]
    DL_i::Vector{Float64} = Float64[]
    DL_d_i::Vector{Float64} = Float64[]
    K_e_i::Vector{Float64} = Float64[]
    L_e_i::Vector{Float64} = Float64[]
    Q_s_i::Vector{Float64} = Float64[]
    I_d_i::Vector{Float64} = Float64[]
    DM_d_i::Vector{Float64} = Float64[]
    N_d_i::Vector{Int} = Int[]
    Pi_e_i::Vector{Float64} = Float64[]
    # Household fields (firms' owners)
    Y_h::Vector{Float64} = Float64[]
    C_d_h::Vector{Float64} = Float64[]
    I_d_h::Vector{Float64} = Float64[]
    C_h::Vector{Float64} = Float64[]
    I_h::Vector{Float64} = Float64[]
    K_h::Vector{Float64} = Float64[]
    D_h::Vector{Float64} = Float64[]
end

Base.@kwdef mutable struct MockBank
    E_k::Float64 = 0.0
    Pi_k::Float64 = 0.0
    Pi_e_k::Float64 = 0.0
    D_k::Float64 = 0.0
    r::Float64 = 0.0
    # Household fields (bank's owner)
    Y_h::Float64 = 0.0
    C_d_h::Float64 = 0.0
    I_d_h::Float64 = 0.0
    C_h::Float64 = 0.0
    I_h::Float64 = 0.0
    K_h::Float64 = 0.0
    D_h::Float64 = 0.0
end

Base.@kwdef mutable struct MockCentralBank
    r_bar::Float64 = 0.0
    r_G::Float64 = 0.0
    rho::Float64 = 0.0
    r_star::Float64 = 0.0
    pi_star::Float64 = 0.0
    xi_pi::Float64 = 0.0
    xi_gamma::Float64 = 0.0
    E_CB::Float64 = 0.0
end

Base.@kwdef mutable struct MockGovernment
    alpha_G::Float64 = 0.0
    beta_G::Float64 = 0.0
    sigma_G::Float64 = 0.0
    Y_G::Float64 = 0.0
    C_G::Float64 = 0.0
    L_G::Float64 = 0.0
    sb_inact::Float64 = 0.0
    sb_other::Float64 = 0.0
    C_d_j::Vector{Float64} = Float64[]
    C_j::Float64 = 0.0
    P_j::Float64 = 0.0
end

Base.@kwdef mutable struct MockRestOfTheWorld
    alpha_E::Float64 = 0.0
    beta_E::Float64 = 0.0
    sigma_E::Float64 = 0.0
    alpha_I::Float64 = 0.0
    beta_I::Float64 = 0.0
    sigma_I::Float64 = 0.0
    Y_EA::Float64 = 0.0
    gamma_EA::Float64 = 0.0
    pi_EA::Float64 = 0.0
    alpha_pi_EA::Float64 = 0.0
    beta_pi_EA::Float64 = 0.0
    sigma_pi_EA::Float64 = 0.0
    alpha_Y_EA::Float64 = 0.0
    beta_Y_EA::Float64 = 0.0
    sigma_Y_EA::Float64 = 0.0
    D_RoW::Float64 = 0.0
    Y_I::Float64 = 0.0
    C_E::Float64 = 0.0
    C_d_l::Vector{Float64} = Float64[]
    C_l::Float64 = 0.0
    Y_m::Vector{Float64} = Float64[]
    Q_m::Vector{Float64} = Float64[]
    Q_d_m::Vector{Float64} = Float64[]
    P_m::Vector{Float64} = Float64[]
    P_l::Float64 = 0.0
end

Base.@kwdef mutable struct MockAggregates
    Y::Vector{Float64} = Float64[]
    pi_::Vector{Float64} = Float64[]
    P_bar::Float64 = 0.0
    P_bar_g::Vector{Float64} = Float64[]
    P_bar_HH::Float64 = 0.0
    P_bar_CF::Float64 = 0.0
    P_bar_h::Float64 = 0.0
    P_bar_CF_h::Float64 = 0.0
    Y_e::Float64 = 0.0
    gamma_e::Float64 = 0.0
    pi_e::Float64 = 0.0
    epsilon_Y_EA::Float64 = 0.0
    epsilon_E::Float64 = 0.0
    epsilon_I::Float64 = 0.0
    t::Int = 0
end


Base.@kwdef mutable struct MockProperties
    # Banking
    mu::Float64 = 0.0
    theta_DIV::Float64 = 0.0
    zeta_b::Float64 = 0.0
    # Taxes
    tau_FIRM::Float64 = 0.0
    tau_INC::Float64 = 0.0
    tau_SIW::Float64 = 0.0
    tau_SIF::Float64 = 0.0
    # Social
    sb_other::Float64 = 0.0
    theta_UB::Float64 = 0.0
    theta::Float64 = 0.0
    a_sg::Matrix{Float64} = zeros(62, 62)
    b_CF_g::Vector{Float64} = zeros(62)
    b_HH_g::Vector{Float64} = zeros(62)
    b_CFH_g::Vector{Float64} = zeros(62)
    c_E_g::Vector{Float64} = zeros(62)
    c_G_g::Vector{Float64} = zeros(62)

    # Dimensions
    T_prime::Int = 0
    I::Int = 0
    H_act::Int = 0
end


Base.@kwdef mutable struct MockModel
    w_act::MockWorkers = MockWorkers()
    w_inact::MockWorkers = MockWorkers()
    firms::MockFirms = MockFirms()
    bank::MockBank = MockBank()
    cb::MockCentralBank = MockCentralBank()
    gov::MockGovernment = MockGovernment()
    rotw::MockRestOfTheWorld = MockRestOfTheWorld()
    agg::MockAggregates = MockAggregates()
    prop::MockProperties = MockProperties()
    data::Any = nothing # Ignore data collection for unit tests
end

# Helper to replicate the old eachfirm iterator
eachfirm(model::MockModel) = 1:length(model.firms.L_i)
Base.length(f::MockFirms) = length(f.L_i)
Base.length(w::MockWorkers) = length(w.D_h)

"""
    build_mock_model(prop::Properties; kwargs...)

Translates a `Properties` object into a `MockModel` for OOP parity testing.
Automatically sizes arrays based on dimensions in `prop`.
Use `kwargs` to override specific arrays or values for targeted testing.
"""
function build_mock_model(prop::Bit.Properties; overrides...)
    I = prop.dimensions.total_firms
    H_act = prop.population.active
    H_inact = prop.population.inactive

    mock_prop = MockProperties(
        mu = prop.banking_params.risk_premium,
        theta_DIV = prop.banking_params.dividend_payout_ratio,
        zeta_b = prop.banking_params.new_firm_loan_ratio,
        tau_FIRM = prop.tax_rates.corporate,
        tau_INC = prop.tax_rates.income,
        tau_SIW = prop.social_insurance.employees_contribution,
        tau_SIF = prop.social_insurance.employers_contribution,
        sb_other = prop.initial_conditions.government.subsidies_other,
        theta_UB = prop.social_insurance.unemployment_benefit,
        theta = prop.banking_params.debt_installment_rate,
        a_sg = prop.product_coeffs.technology_matrix,
        b_CF_g = prop.product_coeffs.capital_formation,
        b_HH_g = prop.product_coeffs.household_consumption,
        b_CFH_g = prop.product_coeffs.household_investment,
        c_E_g = prop.product_coeffs.exports,
        c_G_g = prop.product_coeffs.government_consumption,
        T_prime = prop.dimensions.interval_for_expectation_estimation,
        I = I,
        H_act = H_act
    )

    cb = MockCentralBank(
        r_bar = prop.initial_conditions.banking.policy_rate,
        E_CB = prop.initial_conditions.banking.central_bank_equity
    )

    bank = MockBank(
        E_k = prop.initial_conditions.banking.equity_ratio,
        r = cb.r_bar + mock_prop.mu
    )

    firms = MockFirms(
        G_i = fill(1, I),
        alpha_bar_i = fill(1.0, I),
        beta_i = fill(1.0, I),
        kappa_i = fill(1.0, I),
        w_i = fill(0.0, I),
        w_bar_i = fill(0.0, I),
        delta_i = fill(0.0, I),
        tau_Y_i = fill(0.0, I),
        tau_K_i = fill(0.0, I),
        N_i = fill(0, I),
        Y_i = fill(0.0, I),
        Q_i = fill(0.0, I),
        Q_d_i = fill(0.0, I),
        P_i = fill(1.0, I),
        S_i = fill(0.0, I),
        K_i = fill(0.0, I),
        M_i = fill(0.0, I),
        L_i = fill(0.0, I),
        pi_bar_i = fill(0.0, I),
        D_i = fill(0.0, I),
        Pi_i = fill(0.0, I),
        V_i = fill(0, I),
        I_i = fill(0.0, I),
        E_i = fill(0.0, I),
        P_bar_i = fill(1.0, I),
        P_CF_i = fill(1.0, I),
        DS_i = fill(0.0, I),
        DM_i = fill(0.0, I),
        DL_i = fill(0.0, I),
        DL_d_i = fill(0.0, I),
        K_e_i = fill(0.0, I),
        L_e_i = fill(0.0, I),
        Q_s_i = fill(0.0, I),
        I_d_i = fill(0.0, I),
        DM_d_i = fill(0.0, I),
        N_d_i = fill(0, I),
        Pi_e_i = fill(0.0, I),
        Y_h = fill(0.0, I),
        C_d_h = fill(0.0, I),
        I_d_h = fill(0.0, I),
        C_h = fill(0.0, I),
        I_h = fill(0.0, I),
        K_h = fill(0.0, I),
        D_h = fill(0.0, I)
    )

    w_act = MockWorkers(
        w_h = fill(0.0, H_act),
        O_h = fill(0, H_act),
        C_d_h = fill(0.0, H_act),
        I_d_h = fill(0.0, H_act),
        C_h = fill(0.0, H_act),
        I_h = fill(0.0, H_act),
        D_h = fill(0.0, H_act),
        K_h = fill(0.0, H_act),
        Y_h = fill(0.0, H_act)
    )
    w_inact = MockWorkers(
        w_h = fill(0.0, H_inact),
        O_h = fill(0, H_inact),
        C_d_h = fill(0.0, H_inact),
        I_d_h = fill(0.0, H_inact),
        C_h = fill(0.0, H_inact),
        I_h = fill(0.0, H_inact),
        D_h = fill(0.0, H_inact),
        K_h = fill(0.0, H_inact),
        Y_h = fill(0.0, H_inact)
    )

    rotw = MockRestOfTheWorld(
        C_d_l = fill(0.0, prop.dimensions.foreign_consumers),
        Y_m = fill(0.0, prop.dimensions.sectors),
        Q_m = fill(0.0, prop.dimensions.sectors),
        Q_d_m = fill(0.0, prop.dimensions.sectors),
        P_m = fill(1.0, prop.dimensions.sectors)
    )

    gov = MockGovernment(
        C_d_j = fill(0.0, prop.dimensions.local_governments)
    )

    agg = MockAggregates(
        pi_e = prop.initial_conditions.economy.inflation[end],
        gamma_e = 0.0, P_bar_CF = 1.0,
        P_bar_g = fill(1.0, prop.dimensions.sectors),
        Y = copy(prop.initial_conditions.economy.total_output), t = 1
    )

    model = MockModel(
        prop = mock_prop, cb = cb, bank = bank,
        firms = firms, w_act = w_act, w_inact = w_inact,
        agg = agg, rotw = rotw, gov = gov
    )

    for (k, v) in overrides
        k_str = string(k)
        if startswith(k_str, "firms_")
            setfield!(model.firms, Symbol(replace(k_str, "firms_" => "")), v)
        elseif startswith(k_str, "bank_")
            setfield!(model.bank, Symbol(replace(k_str, "bank_" => "")), v)
        elseif startswith(k_str, "agg_")
            setfield!(model.agg, Symbol(replace(k_str, "agg_" => "")), v)
        elseif startswith(k_str, "w_act_")
            setfield!(model.w_act, Symbol(replace(k_str, "w_act_" => "")), v)
        elseif startswith(k_str, "w_inact_")
            setfield!(model.w_inact, Symbol(replace(k_str, "w_inact_" => "")), v)
        elseif startswith(k_str, "gov_")
            setfield!(model.gov, Symbol(replace(k_str, "gov_" => "")), v)
        elseif startswith(k_str, "rotw_")
            setfield!(model.rotw, Symbol(replace(k_str, "rotw_" => "")), v)
        else
            setfield!(model, k, v)
        end
    end

    return model
end

"""
    set_mock_components!(world::Ark.World; overrides...)

Takes the same keyword arguments as `build_mock_model` and applies them to 
the corresponding ECS components in the `world`.
Arrays (like `firms_L_i`) are applied sequentially to firm entities.
Scalars (like `bank_E_k`) are applied to the single bank entity.
"""
function set_mock_components!(world::Ark.World; overrides...)
    # Group mappings by the entity tag they apply to
    firm_mappings = Dict(
        :firms_L_i => Bit.Components.LoansOutstanding,
        :firms_DL_i => Bit.Components.LoanFlow,
        :firms_D_i => Bit.Components.Deposits,
        :firms_E_i => Bit.Components.Equity,
        :firms_K_i => Bit.Components.CapitalStock,
        :firms_Y_i => Bit.Components.Output,
        :firms_G_i => Bit.Components.PrincipalProduct,
        :firms_I_d_i => Bit.Components.DesiredInvestment,
        :firms_DM_d_i => Bit.Components.DesiredMaterials,
        :firms_S_i => Bit.Components.Inventories,
        :firms_P_i => Bit.Components.Price,
        :firms_alpha_bar_i => Bit.Components.LaborProductivity,
        :firms_beta_i => Bit.Components.IntermediateProductivity,
        :firms_kappa_i => Bit.Components.CapitalProductivity,
        :firms_delta_i => Bit.Components.CapitalDeprecationRate
    )

    bank_mappings = Dict(
        :bank_E_k => Bit.Components.Equity,
        :bank_r => Bit.Components.LendingRate,
        :bank_Pi_k => Bit.Components.Profits,
        :bank_Pi_e_k => Bit.Components.ExpectedProfits,
        :bank_D_k => Bit.Components.ResidualItems,
        :bank_C_d_h => Bit.Components.ConsumptionBudget,
        :bank_I_d_h => Bit.Components.InvestmentBudget
    )

    # Household mappings (split by their specific roles in the ECS)
    w_act_mappings = Dict(
        :w_act_D_h => Bit.Components.Deposits,
        :w_act_C_d_h => Bit.Components.ConsumptionBudget,
        :w_act_I_d_h => Bit.Components.InvestmentBudget
    )
    w_inact_mappings = Dict(
        :w_inact_D_h => Bit.Components.Deposits,
        :w_inact_C_d_h => Bit.Components.ConsumptionBudget,
        :w_inact_I_d_h => Bit.Components.InvestmentBudget
    )
    capitalist_mappings = Dict(
        :firms_D_h => Bit.Components.Deposits,
        :firms_C_d_h => Bit.Components.ConsumptionBudget,
        :firms_I_d_h => Bit.Components.InvestmentBudget
    )
    banker_mappings = Dict(
        :bank_D_h => Bit.Components.Deposits,
        :bank_C_d_h => Bit.Components.ConsumptionBudget,
        :bank_I_d_h => Bit.Components.InvestmentBudget
    )

    rotw_mappings = Dict(
        :rotw_C_d_l => Bit.Components.ForeignConsumptionDemand,
        :rotw_Y_m => Bit.Components.ImportSupply,
        :rotw_P_m => Bit.Components.ImportPrice
    )
    gov_mappings = Dict(:gov_C_d_j => Bit.Components.ConsumptionDemand)

    for (k, v) in overrides
        if haskey(firm_mappings, k)
            CompType = firm_mappings[k]
            idx = 1
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.Firm,))
                for i in eachindex(e)
                    comp[i] = CompType(v[idx])
                    idx += 1
                end
            end

        elseif haskey(w_act_mappings, k)
            CompType = w_act_mappings[k]
            idx = 1
            for (e, comp) in Ark.Query(
                    world,
                    (CompType,),
                    with = (Bit.Components.Household,),
                    without = (Bit.Components.Inactive, Bit.Components.Capitalist, Bit.Components.Banker)
                )
                for i in eachindex(e)
                    comp[i] = CompType(v[idx])
                    idx += 1
                end
            end

        elseif haskey(w_inact_mappings, k)
            CompType = w_inact_mappings[k]
            idx = 1
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.Inactive,))
                for i in eachindex(e)
                    comp[i] = CompType(v[idx])
                    idx += 1
                end
            end

        elseif haskey(capitalist_mappings, k)
            CompType = capitalist_mappings[k]
            idx = 1
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.Capitalist,))
                for i in eachindex(e)
                    comp[i] = CompType(v[idx])
                    idx += 1
                end
            end

        elseif haskey(banker_mappings, k)
            CompType = banker_mappings[k]
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.Banker,))
                comp[1] = CompType(v)
            end

        elseif haskey(bank_mappings, k)
            CompType = bank_mappings[k]
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.Bank,))
                comp[1] = CompType(v)
            end

        elseif k == :rotw_C_d_l
            CompType = Bit.Components.ForeignConsumptionDemand
            idx = 1
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.RestOfWorldEntity,))
                for i in eachindex(e)
                    comp[i] = CompType(v[idx])
                    idx += 1
                end
            end

        elseif k == :rotw_Y_m || k == :rotw_P_m
            CompType = rotw_mappings[k]
            idx = 1
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.ForeignSector,))
                for i in eachindex(e)
                    comp[i] = CompType(v[idx])
                    idx += 1
                end
            end

        elseif haskey(gov_mappings, k)
            CompType = gov_mappings[k]
            idx = 1
            for (e, comp) in Ark.Query(world, (CompType,), with = (Bit.Components.LocalGovernment,))
                for i in eachindex(e)
                    comp[i] = CompType(v[idx])
                    idx += 1
                end
            end

        else
            @warn "Override key `$k` not mapped in `set_mock_components!`"
        end
    end
    return nothing
end
