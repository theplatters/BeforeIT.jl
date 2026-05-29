using MacroTools

macro sum_over(generator)
    # Parse: expr for var in Query(world, component)
    @capture(generator, expr_ for var_ in query_call_) ||
        error("Syntax: @sum_over(expr for var in Query(world, ComponentType))")

    @capture(query_call, query_type_(world_, component_type_)) ||
        error("Expected Query(world, ComponentType)")
    e = gensym(:e)
    vals = gensym(:vals)
    i = gensym(:i)

    # Replace var with vals[i] in expr
    new_expr = MacroTools.postwalk(expr) do x
        x === var ? :($vals[$i]) : x
    end

    return quote
        let total = 0.0
            for ($e, $vals) in $query_type($world, $component_type)
                for $i in eachindex($e)
                    total += $new_expr
                end
            end
            total
        end
    end |> esc
end

@inline function single(q::Ark.Query)
    firstv = iterate(q)
    if firstv === nothing
        throw(ArgumentError("query must contain exactly one matching table"))
    end

    row, state = firstv
    secondv = iterate(q, state)
    if secondv !== nothing
        Ark.close!(q)
        throw(ArgumentError("query must contain exactly one matching table"))
    end

    return first.(row)
end

properties(w::Ark.World) = Ark.get_resource(w, Properties)
expectations(w::Ark.World) = Ark.get_resource(w, Expectations)
price_indices(w::Ark.World) = Ark.get_resource(w, PriceIndices)
epsilons(w::Ark.World) = Ark.get_resource(w, Epsilons)
