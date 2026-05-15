using Test
import Ark

# Assuming the OOP firm systems are included, e.g., include("old_actions/firms.jl")

include("old_actions/firms.jl")

@testset "Firm Systems Parity with Automated Setup" begin

    @testset "set_firms_expectations_and_decisions!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_P_i = fill(1.0, I)
        test_Q_d_i = fill(10.0, I)
        test_K_i = fill(10.0, I)
        test_Pi_i = fill(5.0, I)
        test_L_i = fill(5.0, I)
        test_D_i = fill(5.0, I)
        test_w_bar_i = fill(1.0, I)
        test_delta_i = fill(0.05, I)
        test_beta_i = fill(1.0, I)
        test_alpha_bar_i = fill(1.0, I)
        test_kappa_i = fill(1.0, I)
        test_G_i = fill(1, I)

        mock_model = build_mock_model(
            properties;
            firms_P_i = test_P_i,
            firms_Q_d_i = test_Q_d_i,
            firms_K_i = test_K_i,
            firms_Pi_i = test_Pi_i,
            firms_L_i = test_L_i,
            firms_D_i = test_D_i,
            firms_w_bar_i = test_w_bar_i,
            firms_delta_i = test_delta_i,
            firms_beta_i = test_beta_i,
            firms_alpha_bar_i = test_alpha_bar_i,
            firms_kappa_i = test_kappa_i,
            firms_G_i = test_G_i
        )

        mock_model.agg.gamma_e = 0.02
        mock_model.agg.pi_e = 0.05
        mock_model.agg.P_bar_CF = 1.0
        mock_model.agg.P_bar_HH = 1.0
        mock_model.agg.P_bar_g = fill(1.0, properties.dimensions.sectors)

        # ECS Setup
        expectations = Ark.get_resource(world, Bit.Expectations)
        expectations.output_growth = 0.02
        expectations.inflation = 0.05

        price_indices = Ark.get_resource(world, Bit.PriceIndices)
        price_indices.capital_goods = 1.0
        price_indices.household_consumption = 1.0
        price_indices.sector .= 1.0

        for (e, P, Q_d, K, Pi, L, D, w_bar, delta, beta, alpha_bar, kappa, G) in Ark.Query(
                world, (
                    Bit.Price, Bit.GoodsDemand, Bit.CapitalStock,
                    Bit.Profits, Bit.LoansOutstanding, Bit.Deposits,
                    Bit.AverageWageRate, Bit.CapitalDeprecationRate,
                    Bit.IntermediateProductivity, Bit.LaborProductivity,
                    Bit.CapitalProductivity, Bit.PrincipalProduct,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                P[i] = Bit.Price(test_P_i[i])
                Q_d[i] = Bit.GoodsDemand(test_Q_d_i[i])
                K[i] = Bit.CapitalStock(test_K_i[i])
                Pi[i] = Bit.Profits(test_Pi_i[i])
                L[i] = Bit.LoansOutstanding(test_L_i[i])
                D[i] = Bit.Deposits(test_D_i[i])
                w_bar[i] = Bit.AverageWageRate(test_w_bar_i[i])
                delta[i] = Bit.CapitalDeprecationRate(test_delta_i[i])
                beta[i] = Bit.IntermediateProductivity(test_beta_i[i])
                alpha_bar[i] = Bit.LaborProductivity(test_alpha_bar_i[i])
                kappa[i] = Bit.CapitalProductivity(test_kappa_i[i])
                G[i] = Bit.PrincipalProduct(test_G_i[i])
            end
        end

        set_firms_expectations_and_decisions!(mock_model)
        Bit.set_firms_expectations_and_decisions!(world)

        # Verify
        for (e, Q_s, I_d, DM_d, N_d, Pi_e, DL_d, K_e, L_e, P) in Ark.Query(
                world, (
                    Bit.ExpectedSales, Bit.DesiredInvestment,
                    Bit.DesiredMaterials, Bit.DesiredEmployment,
                    Bit.ExpectedProfits, Bit.TargetLoans,
                    Bit.ExpectedCapital, Bit.ExpectedLoans,
                    Bit.Price,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                @test isapprox(Q_s[i].amount, mock_model.firms.Q_s_i[i], atol = 1.0e-7)
                @test isapprox(I_d[i].amount, mock_model.firms.I_d_i[i], atol = 1.0e-7)
                @test isapprox(DM_d[i].amount, mock_model.firms.DM_d_i[i], atol = 1.0e-7)
                @test N_d[i].amount == mock_model.firms.N_d_i[i]
                @test isapprox(Pi_e[i].amount, mock_model.firms.Pi_e_i[i], atol = 1.0e-7)
                @test isapprox(DL_d[i].amount, mock_model.firms.DL_d_i[i], atol = 1.0e-7)
                @test isapprox(K_e[i].amount, mock_model.firms.K_e_i[i], atol = 1.0e-7)
                @test isapprox(L_e[i].amount, mock_model.firms.L_e_i[i], atol = 1.0e-7)
                @test isapprox(P[i].value, mock_model.firms.P_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "set_firms_wages!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_Q_s_i = fill(15.0, I)
        test_w_bar_i = fill(1.0, I)
        test_K_i = fill(10.0, I)
        test_M_i = fill(10.0, I)
        test_N_i = fill(5, I)
        test_kappa_i = fill(1.0, I)
        test_beta_i = fill(1.0, I)
        test_alpha_bar_i = fill(1.0, I)

        mock_model = build_mock_model(
            properties;
            firms_Q_s_i = test_Q_s_i,
            firms_w_bar_i = test_w_bar_i,
            firms_K_i = test_K_i,
            firms_M_i = test_M_i,
            firms_N_i = test_N_i,
            firms_kappa_i = test_kappa_i,
            firms_beta_i = test_beta_i,
            firms_alpha_bar_i = test_alpha_bar_i
        )

        for (e, Q_s, w_bar, K, M, N, kappa, beta, alpha_bar) in Ark.Query(
                world, (
                    Bit.ExpectedSales, Bit.AverageWageRate, Bit.CapitalStock,
                    Bit.Intermediates, Bit.Employment, Bit.CapitalProductivity,
                    Bit.IntermediateProductivity, Bit.LaborProductivity,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                Q_s[i] = Bit.ExpectedSales(test_Q_s_i[i])
                w_bar[i] = Bit.AverageWageRate(test_w_bar_i[i])
                K[i] = Bit.CapitalStock(test_K_i[i])
                M[i] = Bit.Intermediates(test_M_i[i])
                N[i] = Bit.Employment(test_N_i[i])
                kappa[i] = Bit.CapitalProductivity(test_kappa_i[i])
                beta[i] = Bit.IntermediateProductivity(test_beta_i[i])
                alpha_bar[i] = Bit.LaborProductivity(test_alpha_bar_i[i])
            end
        end

        set_firms_wages!(mock_model)
        Bit.set_firms_wages!(world)

        for (e, w) in Ark.Query(world, (Bit.WageBill,), with = (Bit.Firm,))
            for i in eachindex(e)
                @test isapprox(w[i].amount, mock_model.firms.w_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "set_firms_production!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_Q_s_i = fill(15.0, I)
        test_K_i = fill(10.0, I)
        test_M_i = fill(10.0, I)
        test_N_i = fill(5, I)
        test_kappa_i = fill(1.0, I)
        test_beta_i = fill(1.0, I)
        test_alpha_bar_i = fill(1.0, I)

        mock_model = build_mock_model(
            properties;
            firms_Q_s_i = test_Q_s_i,
            firms_K_i = test_K_i,
            firms_M_i = test_M_i,
            firms_N_i = test_N_i,
            firms_kappa_i = test_kappa_i,
            firms_beta_i = test_beta_i,
            firms_alpha_bar_i = test_alpha_bar_i
        )

        for (e, Q_s, K, M, N, kappa, beta, alpha_bar) in Ark.Query(
                world, (
                    Bit.ExpectedSales, Bit.CapitalStock, Bit.Intermediates,
                    Bit.Employment, Bit.CapitalProductivity,
                    Bit.IntermediateProductivity, Bit.LaborProductivity,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                Q_s[i] = Bit.ExpectedSales(test_Q_s_i[i])
                K[i] = Bit.CapitalStock(test_K_i[i])
                M[i] = Bit.Intermediates(test_M_i[i])
                N[i] = Bit.Employment(test_N_i[i])
                kappa[i] = Bit.CapitalProductivity(test_kappa_i[i])
                beta[i] = Bit.IntermediateProductivity(test_beta_i[i])
                alpha_bar[i] = Bit.LaborProductivity(test_alpha_bar_i[i])
            end
        end

        set_firms_production!(mock_model)
        Bit.set_firms_production!(world)

        for (e, Y) in Ark.Query(world, (Bit.Output,), with = (Bit.CapitalStock,))
            for i in eachindex(e)
                @test isapprox(Y[i].amount, mock_model.firms.Y_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "set_firms_profits!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_P_i = fill(1.5, I)
        test_Q_i = fill(8.0, I)
        test_DS_i = fill(1.0, I)
        test_D_i = fill(5.0, I)
        test_w_i = fill(1.0, I)
        test_N_i = fill(5, I)
        test_beta_i = fill(1.0, I)
        test_P_bar_i = fill(1.0, I)
        test_Y_i = fill(10.0, I)
        test_delta_i = fill(0.05, I)
        test_kappa_i = fill(1.0, I)
        test_P_CF_i = fill(1.0, I)
        test_tau_Y_i = fill(0.1, I)
        test_tau_K_i = fill(0.1, I)
        test_L_i = fill(5.0, I)

        test_D_i[1] = -2.0 # Test negative deposit logic

        mock_model = build_mock_model(
            properties;
            firms_P_i = test_P_i,
            firms_Q_i = test_Q_i,
            firms_DS_i = test_DS_i,
            firms_D_i = test_D_i,
            firms_w_i = test_w_i,
            firms_N_i = test_N_i,
            firms_beta_i = test_beta_i,
            firms_P_bar_i = test_P_bar_i,
            firms_Y_i = test_Y_i,
            firms_delta_i = test_delta_i,
            firms_kappa_i = test_kappa_i,
            firms_P_CF_i = test_P_CF_i,
            firms_tau_Y_i = test_tau_Y_i,
            firms_tau_K_i = test_tau_K_i,
            firms_L_i = test_L_i
        )

        mock_model.agg.P_bar_HH = 1.0
        mock_model.bank.r = 0.05
        mock_model.cb.r_bar = 0.02

        price_indices = Ark.get_resource(world, Bit.PriceIndices)
        price_indices.household_consumption = 1.0

        for (e, r) in Ark.Query(world, (Bit.LendingRate,))
            r[1] = Bit.LendingRate(0.05)
        end
        for (e, r_bar) in Ark.Query(world, (Bit.NominalInterestRate,))
            r_bar[1] = Bit.NominalInterestRate(0.02)
        end

        for (e, P, Q, DS, D, w, N, beta, P_bar, Y, delta, kappa, P_CF, tau, L) in Ark.Query(
                world, (
                    Bit.Price, Bit.Sales, Bit.FinalGoodsStockChange,
                    Bit.Deposits, Bit.WageBill, Bit.Employment,
                    Bit.IntermediateProductivity, Bit.PriceIndex, Bit.Output,
                    Bit.CapitalDeprecationRate, Bit.CapitalProductivity,
                    Bit.CFPriceIndex, Bit.TaxRates,
                    Bit.LoansOutstanding,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                P[i] = Bit.Price(test_P_i[i])
                Q[i] = Bit.Sales(test_Q_i[i])
                DS[i] = Bit.FinalGoodsStockChange(test_DS_i[i])
                D[i] = Bit.Deposits(test_D_i[i])
                w[i] = Bit.WageBill(test_w_i[i])
                N[i] = Bit.Employment(test_N_i[i])
                beta[i] = Bit.IntermediateProductivity(test_beta_i[i])
                P_bar[i] = Bit.PriceIndex(test_P_bar_i[i])
                Y[i] = Bit.Output(test_Y_i[i])
                delta[i] = Bit.CapitalDeprecationRate(test_delta_i[i])
                kappa[i] = Bit.CapitalProductivity(test_kappa_i[i])
                P_CF[i] = Bit.CFPriceIndex(test_P_CF_i[i])
                tau[i] = Bit.TaxRates(test_tau_Y_i[i], test_tau_K_i[i])
                L[i] = Bit.LoansOutstanding(test_L_i[i])
            end
        end

        set_firms_profits!(mock_model)
        Bit.set_firms_profits!(world)

        for (e, Pi) in Ark.Query(world, (Bit.Profits,), with = (Bit.Firm,))
            for i in eachindex(e)
                @test isapprox(Pi[i].amount, mock_model.firms.Pi_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "set_firms_deposits!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_P_i = fill(1.5, I)
        test_Q_i = fill(8.0, I)
        test_w_i = fill(1.0, I)
        test_N_i = fill(5, I)
        test_DM_i = fill(2.0, I)
        test_P_bar_i = fill(1.0, I)
        test_tau_Y_i = fill(0.1, I)
        test_tau_K_i = fill(0.1, I)
        test_Y_i = fill(10.0, I)
        test_Pi_i = fill(5.0, I)
        test_L_i = fill(5.0, I)
        test_D_i = fill(5.0, I)
        test_P_CF_i = fill(1.0, I)
        test_I_i = fill(2.0, I)
        test_DL_i = fill(1.0, I)

        test_D_i[2] = -2.0 # Test negative deposit logic

        mock_model = build_mock_model(
            properties;
            firms_P_i = test_P_i,
            firms_Q_i = test_Q_i,
            firms_w_i = test_w_i,
            firms_N_i = test_N_i,
            firms_DM_i = test_DM_i,
            firms_P_bar_i = test_P_bar_i,
            firms_tau_Y_i = test_tau_Y_i,
            firms_tau_K_i = test_tau_K_i,
            firms_Y_i = test_Y_i,
            firms_Pi_i = test_Pi_i,
            firms_L_i = test_L_i,
            firms_D_i = test_D_i,
            firms_P_CF_i = test_P_CF_i,
            firms_I_i = test_I_i,
            firms_DL_i = test_DL_i
        )

        mock_model.agg.P_bar_HH = 1.0
        mock_model.bank.r = 0.05
        mock_model.cb.r_bar = 0.02

        price_indices = Ark.get_resource(world, Bit.PriceIndices)
        price_indices.household_consumption = 1.0

        for (e, r) in Ark.Query(world, (Bit.LendingRate,))
            r[1] = Bit.LendingRate(0.05)
        end
        for (e, r_bar) in Ark.Query(world, (Bit.NominalInterestRate,))
            r_bar[1] = Bit.NominalInterestRate(0.02)
        end

        for (e, P, Q, w, N, DM, P_bar, tau, Y, Pi, L, D, P_CF, I, DL) in Ark.Query(
                world, (
                    Bit.Price, Bit.Sales, Bit.WageBill,
                    Bit.Employment, Bit.MaterialsStockChange, Bit.PriceIndex,
                    Bit.TaxRates, Bit.Output,
                    Bit.Profits, Bit.LoansOutstanding, Bit.Deposits,
                    Bit.CFPriceIndex, Bit.Investment, Bit.LoanFlow,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                P[i] = Bit.Price(test_P_i[i])
                Q[i] = Bit.Sales(test_Q_i[i])
                w[i] = Bit.WageBill(test_w_i[i])
                N[i] = Bit.Employment(test_N_i[i])
                DM[i] = Bit.MaterialsStockChange(test_DM_i[i])
                P_bar[i] = Bit.PriceIndex(test_P_bar_i[i])
                tau[i] = Bit.TaxRates(test_tau_Y_i[i], test_tau_K_i[i])
                Y[i] = Bit.Output(test_Y_i[i])
                Pi[i] = Bit.Profits(test_Pi_i[i])
                L[i] = Bit.LoansOutstanding(test_L_i[i])
                D[i] = Bit.Deposits(test_D_i[i])
                P_CF[i] = Bit.CFPriceIndex(test_P_CF_i[i])
                I[i] = Bit.Investment(test_I_i[i])
                DL[i] = Bit.LoanFlow(test_DL_i[i])
            end
        end

        set_firms_deposits!(mock_model)
        Bit.set_firms_deposits!(world)

        for (e, D) in Ark.Query(world, (Bit.Deposits,), with = (Bit.Firm,))
            for i in eachindex(e)
                @test isapprox(D[i].amount, mock_model.firms.D_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "set_firms_equity!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_D_i = fill(10.0, I)
        test_M_i = fill(5.0, I)
        test_G_i = fill(1, I)
        test_P_i = fill(1.2, I)
        test_S_i = fill(3.0, I)
        test_K_i = fill(20.0, I)
        test_L_i = fill(8.0, I)

        mock_model = build_mock_model(
            properties;
            firms_D_i = test_D_i,
            firms_M_i = test_M_i,
            firms_G_i = test_G_i,
            firms_P_i = test_P_i,
            firms_S_i = test_S_i,
            firms_K_i = test_K_i,
            firms_L_i = test_L_i
        )

        mock_model.agg.P_bar_g = fill(1.0, properties.dimensions.sectors)
        mock_model.agg.P_bar_CF = 1.0

        price_indices = Ark.get_resource(world, Bit.PriceIndices)
        price_indices.sector .= 1.0
        price_indices.capital_goods = 1.0

        for (e, D, M, G, P, S, K, L) in Ark.Query(
                world, (
                    Bit.Deposits, Bit.Intermediates, Bit.PrincipalProduct,
                    Bit.Price, Bit.Inventories, Bit.CapitalStock,
                    Bit.LoansOutstanding,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                D[i] = Bit.Deposits(test_D_i[i])
                M[i] = Bit.Intermediates(test_M_i[i])
                G[i] = Bit.PrincipalProduct(test_G_i[i])
                P[i] = Bit.Price(test_P_i[i])
                S[i] = Bit.Inventories(test_S_i[i])
                K[i] = Bit.CapitalStock(test_K_i[i])
                L[i] = Bit.LoansOutstanding(test_L_i[i])
            end
        end

        set_firms_equity!(mock_model)
        Bit.set_firms_equity!(world)

        for (e, E) in Ark.Query(world, (Bit.Equity,), with = (Bit.Firm,))
            for i in eachindex(e)
                @test isapprox(E[i].amount, mock_model.firms.E_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "set_firms_loans!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_L_i = fill(20.0, I)
        test_DL_i = fill(5.0, I)

        mock_model = build_mock_model(
            properties;
            firms_L_i = test_L_i,
            firms_DL_i = test_DL_i
        )

        set_mock_components!(
            world,
            firms_L_i = test_L_i,
            firms_DL_i = test_DL_i
        )
        set_firms_loans!(mock_model)
        Bit.set_firms_loans!(world)

        for (e, L) in Ark.Query(world, (Bit.LoansOutstanding,), with = (Bit.Firm,))
            for i in eachindex(e)
                @test isapprox(L[i].amount, mock_model.firms.L_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "set_firms_stocks!" begin
        properties = Bit.STEADY_STATE2010Q1
        world = Bit.ECSModel(properties).world
        I = properties.dimensions.total_firms

        test_K_i = fill(20.0, I)
        test_delta_i = fill(0.05, I)
        test_kappa_i = fill(1.0, I)
        test_Y_i = fill(10.0, I)
        test_I_i = fill(2.0, I)
        test_M_i = fill(5.0, I)
        test_beta_i = fill(1.0, I)
        test_DM_i = fill(3.0, I)
        test_Q_i = fill(8.0, I)
        test_S_i = fill(2.0, I)

        mock_model = build_mock_model(
            properties;
            firms_K_i = test_K_i,
            firms_delta_i = test_delta_i,
            firms_kappa_i = test_kappa_i,
            firms_Y_i = test_Y_i,
            firms_I_i = test_I_i,
            firms_M_i = test_M_i,
            firms_beta_i = test_beta_i,
            firms_DM_i = test_DM_i,
            firms_Q_i = test_Q_i,
            firms_S_i = test_S_i
        )

        for (e, K, delta, kappa, Y, I_comp, M, beta, DM, Q, S) in Ark.Query(
                world, (
                    Bit.CapitalStock, Bit.CapitalDeprecationRate,
                    Bit.CapitalProductivity, Bit.Output, Bit.Investment,
                    Bit.Intermediates, Bit.IntermediateProductivity,
                    Bit.MaterialsStockChange, Bit.Sales, Bit.Inventories,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                K[i] = Bit.CapitalStock(test_K_i[i])
                delta[i] = Bit.CapitalDeprecationRate(test_delta_i[i])
                kappa[i] = Bit.CapitalProductivity(test_kappa_i[i])
                Y[i] = Bit.Output(test_Y_i[i])
                I_comp[i] = Bit.Investment(test_I_i[i])
                M[i] = Bit.Intermediates(test_M_i[i])
                beta[i] = Bit.IntermediateProductivity(test_beta_i[i])
                DM[i] = Bit.MaterialsStockChange(test_DM_i[i])
                Q[i] = Bit.Sales(test_Q_i[i])
                S[i] = Bit.Inventories(test_S_i[i])
            end
        end

        set_firms_stocks!(mock_model)
        Bit.set_firms_stocks!(world)

        for (e, K, M, DS, S) in Ark.Query(
                world, (
                    Bit.CapitalStock, Bit.Intermediates,
                    Bit.FinalGoodsStockChange, Bit.Inventories,
                ), with = (Bit.Firm,)
            )
            for i in eachindex(e)
                @test isapprox(K[i].amount, mock_model.firms.K_i[i], atol = 1.0e-7)
                @test isapprox(M[i].amount, mock_model.firms.M_i[i], atol = 1.0e-7)
                @test isapprox(DS[i].amount, mock_model.firms.DS_i[i], atol = 1.0e-7)
                @test isapprox(S[i].amount, mock_model.firms.S_i[i], atol = 1.0e-7)
            end
        end
    end

    @testset "firm_production helper" begin
        Q_s_i = [1.0, 2.0, 0.0]
        N_i = [1.0, 2.0, 3.0]
        alpha_i = [1.0, 2.0, 3.0]
        K_i = [1.0, 2.0, 3.0]
        kappa_i = [1.0, 0.0, 3.0]
        M_i = [1.0, 2.0, 3.0]
        beta_i = [1.0, 2.0, 3.0]

        Y_i = Bit.firm_production.(Q_s_i, N_i, alpha_i, K_i, kappa_i, M_i, beta_i)
        @test Y_i == [1.0, 0.0, 0.0]
    end

end
