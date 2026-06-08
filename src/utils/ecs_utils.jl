using MacroTools

function _dub_query_call(ex)
    ex isa Expr && ex.head == :call || return false
    fn = first(ex.args)
    fn === :Query && return true
    fn isa Expr && fn.head == :. || return false
    length(fn.args) == 2 || return false
    return fn.args[1] === :Ark && fn.args[2] == QuoteNode(:Query)
end

function _dub_macrocall(ex)
    ex isa Expr && ex.head == :macrocall || return false
    isempty(ex.args) && return false
    macro_name = first(ex.args)
    macro_name === Symbol("@dub") && return true
    if macro_name isa Expr && macro_name.head == :. && length(macro_name.args) == 2
        return macro_name.args[2] == QuoteNode(Symbol("@dub"))
    end
    return false
end

function _dub_loop(loop, include_nested_queries)
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
    transformed_body = include_nested_queries ? _dub_nested_queries(body) : body
    body_args = transformed_body isa Expr && transformed_body.head == :block ? transformed_body.args : Any[transformed_body]

    return Expr(
        :for,
        Expr(:(=), comps, query),
        Expr(:block, Expr(:(=), row_var, Expr(:call, query_row_ref, comps)), body_args...),
    )
end

function _dub_nested_queries(ex)
    if ex isa Expr
        if _dub_macrocall(ex)
            loop = last(ex.args)
            return _dub_loop(loop, true)
        end
        if ex.head == :for && length(ex.args) == 2
            iter = ex.args[1]
            if iter isa Expr && iter.head == :(=) && length(iter.args) == 2
                row_var, query = iter.args
                row_var isa Symbol && _dub_query_call(query) && return _dub_loop(ex, true)
            end
        end
        return Expr(ex.head, map(_dub_nested_queries, ex.args)...)
    end
    return ex
end

macro dub(loop)
    return _dub_loop(loop, true) |> esc
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
