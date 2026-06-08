using MacroTools

macro dub(loop)
    loop isa Expr && loop.head == :for ||
        error("Syntax: @dub for t in query ... end")
    length(loop.args) == 2 ||
        error("Syntax: @dub for t in query ... end")

    iter = loop.args[1]
    body = loop.args[2]

    iter isa Expr && iter.head == :(=) && length(iter.args) == 2 ||
        error("Syntax: @dub for t in query ... end")

    row_var, query = iter.args
    row_var isa Symbol ||
        error("Syntax: @dub for t in query ... end")

    comps = gensym(Symbol("_", row_var))
    query_row_ref = GlobalRef(@__MODULE__, :query_row)
    body_args = body isa Expr && body.head == :block ? body.args : Any[body]

    return Expr(
        :for,
        Expr(:(=), comps, query),
        Expr(:block, :($row_var = $query_row_ref($comps)), body_args...),
    ) |> esc
end

macro sum_over(generator)
    # Parse: expr for var in Query(world, component)
    @capture(generator, expr_ for var_ in query_call_) ||
        error("Syntax: @sum_over(expr for var in Query(world, ComponentType))")

    @capture(query_call, query_type_(world_, component_type_)) ||
        error("Expected Query(world, ComponentType)")
    e = gensym(:e)
    vals = gensym(:vals)
    comps = gensym(:comps)
    row = gensym(:row)
    i = gensym(:i)

    # Replace var with vals[i] in expr
    new_expr = MacroTools.postwalk(expr) do x
        x === var ? :($vals[$i]) : x
    end

    return quote
        let total = 0.0
            for $comps in $query_type($world, $component_type)
                $row = query_row($comps)
                $e = $row.e
                $vals = query_component($row, first($component_type))
                for $i in eachindex($e)
                    total += $new_expr
                end
            end
            total
        end
    end |> esc
end

@inline function single(q::Ark.Query)
    return first.(only(q))
end

properties(w::Ark.World) = Ark.get_resource(w, Properties)
expectations(w::Ark.World) = Ark.get_resource(w, Expectations)
price_indices(w::Ark.World) = Ark.get_resource(w, PriceIndices)
epsilons(w::Ark.World) = Ark.get_resource(w, Epsilons)
