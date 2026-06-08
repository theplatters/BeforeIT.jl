@testset "ECS utils" begin
    rows = [
        (
            [:firm_a, :firm_b],
            [Bit.Output(2.0), Bit.Output(3.0)],
            [Bit.Price(5.0), Bit.Price(7.0)],
            [Bit.TaxRates(0.1, 0.2), Bit.TaxRates(0.3, 0.4)],
        ),
    ]

    products = 0.0
    seen_entities = Symbol[]
    Bit.@dub for t in rows
        append!(seen_entities, t.e)
        @inbounds for i in eachindex(t.e)
            products += t.output[i].amount * t.price[i].value * t.tax_rates[i].output
        end
    end

    @test seen_entities == [:firm_a, :firm_b]
    @test products == 2.0 * 5.0 * 0.1 + 3.0 * 7.0 * 0.3

    function query_row_call_count(ex)
        if ex isa Expr
            count = ex.head == :call &&
                first(ex.args) isa GlobalRef &&
                first(ex.args).name === :query_row ? 1 : 0
            for arg in ex.args
                count += query_row_call_count(arg)
            end
            return count
        end
        return 0
    end

    expanded = @macroexpand Bit.@dub for t in Ark.Query(world, (Bit.Output,))
        for t2 in Ark.Query(world, (Bit.Price,))
            nothing
        end
    end

    @test query_row_call_count(expanded) == 2
end
