using Test
import Ark

@testset "Estimations Helper Tests" begin
    @testset "set_inflation_priceindex!" begin
        world = Bit.ECSModel(Bit.STEADY_STATE2010Q1).world
        macro_state = Ark.get_resource(world, Bit.MacroeconomicState)
        price_indices = Ark.get_resource(world, Bit.PriceIndices)
        time_index = Ark.get_resource(world, Bit.TimeIndex)
        interval = Ark.get_resource(world, Bit.Properties).dimensions.interval_for_expectation_estimation

        firm_index = 0
        for (_, prices, output) in Ark.Query(world, (Bit.Components.Price, Bit.Components.Output), with = (Bit.Components.Firm,))
            for index in eachindex(prices.value)
                firm_index += 1
                prices.value[index] = firm_index <= 3 ? Float64(firm_index) : 0.0
                output.amount[index] = firm_index <= 3 ? Float64(firm_index) : 0.0
            end
        end

        price_indices.aggregate = 2.0
        initial_history_length = length(macro_state.inflation_history)

        Bit.set_inflation_priceindex!(world)

        expected_price_index = 14 / 6
        expected_aggregate_index = expected_price_index
        expected_inflation = log(expected_price_index / 2.0)

        @test isapprox(price_indices.aggregate, expected_aggregate_index, atol = 1.0e-10)
        @test length(macro_state.inflation_history) == initial_history_length + 1
        @test isapprox(macro_state.inflation_history[interval + time_index.step], expected_inflation, atol = 1.0e-10)
    end

    @testset "set_sector_specific_priceindex!" begin
        world = Bit.ECSModel(Bit.STEADY_STATE2010Q1).world
        price_indices = Ark.get_resource(world, Bit.PriceIndices)

        firm_index = 0
        for (_, principal_product, prices, sales) in Ark.Query(
                world,
                (Bit.Components.PrincipalProduct, Bit.Components.Price, Bit.Components.Sales),
                with = (Bit.Components.Firm,)
            )
            for index in eachindex(principal_product.id)
                firm_index += 1
                principal_product.id[index] = firm_index <= 3 ? 1 : principal_product.id[index]
                prices.value[index] = firm_index <= 3 ? Float64(firm_index) : 0.0
                sales.amount[index] = firm_index <= 3 ? Float64(firm_index) : 0.0
            end
        end

        import_index = 0
        for (_, principal_product, prices, sales) in Ark.Query(
                world,
                (Bit.Components.PrincipalProduct, Bit.Components.ImportPrice, Bit.Components.ImportSales),
                with = (Bit.Components.ForeignSector,)
            )
            for index in eachindex(principal_product.id)
                import_index += 1
                principal_product.id[index] = import_index == 1 ? 1 : principal_product.id[index]
                prices.value[index] = import_index == 1 ? 2.0 : 0.0
                sales.amount[index] = import_index == 1 ? 1.0 : 0.0
            end
        end

        Bit.set_sector_specific_priceindex!(world)

        @test isapprox(price_indices.sector[1], 16 / 7, atol = 1.0e-10)
    end
end
