function snake_case_name(name::Symbol)
    s = string(name)
    s = replace(s, r"([A-Z]+)([A-Z][a-z])" => s"\1_\2")
    s = replace(s, r"([a-z\d])([A-Z])" => s"\1_\2")
    return Symbol(lowercase(s))
end

component_field_name(::Type{T}) where {T} = snake_case_name(nameof(T))
query_component_type(::Type{T}) where {T} = eltype(T)

@generated function query_component(row::NamedTuple{names}, ::Type{T}) where {names, T}
    name = component_field_name(T)
    name in names || error("component $T is not present in query row $names")
    return :(getfield(row, $(QuoteNode(name))))
end

@generated function query_row(comps::T) where {T <: Tuple}
    field_types = T.parameters
    names = Vector{Symbol}(undef, length(field_types))
    if !isempty(names)
        names[1] = :e
    end
    for i in 2:length(field_types)
        names[i] = component_field_name(query_component_type(field_types[i]))
    end
    return :(NamedTuple{$(QuoteNode(Tuple(names)))}(comps))
end

@inline function _sum_values(values)
    total = zero(eltype(values))
    @inbounds for i in eachindex(values)
        total += values[i]
    end
    return total
end

@inline function _sum_positive_values(values)
    total = zero(eltype(values))
    @inbounds for i in eachindex(values)
        value = values[i]
        if value > zero(value)
            total += value
        end
    end
    return total
end

@inline function _sum_negative_values(values)
    total = zero(eltype(values))
    @inbounds for i in eachindex(values)
        value = values[i]
        if value < zero(value)
            total -= value
        end
    end
    return total
end

function sum_component_field(world::Ark.World, ::Type{T}, field::Symbol; kwargs...) where {T}
    return sum_component_field(world, T, Val(field); kwargs...)
end

function sum_component_field(world::Ark.World, ::Type{T}, ::Val{field}; kwargs...) where {T, field}
    total = 0.0
    @dub for t in Ark.Query(world, (T,); kwargs...)
        total += _sum_values(getproperty(query_component(t, T), field))
    end
    return total
end

sum_amount(world::Ark.World, ::Type{T}; kwargs...) where {T} =
    sum_component_field(world, T, Val(:amount); kwargs...)

sum_rate(world::Ark.World, ::Type{T}; kwargs...) where {T} =
    sum_component_field(world, T, Val(:rate); kwargs...)

sum_value(world::Ark.World, ::Type{T}; kwargs...) where {T} =
    sum_component_field(world, T, Val(:value); kwargs...)

function sum_positive_amount(world::Ark.World, ::Type{T}; kwargs...) where {T}
    total = 0.0
    @dub for t in Ark.Query(world, (T,); kwargs...)
        amount = query_component(t, T).amount
        total += _sum_positive_values(amount)
    end
    return total
end

function sum_negative_amount(world::Ark.World, ::Type{T}; kwargs...) where {T}
    total = 0.0
    @dub for t in Ark.Query(world, (T,); kwargs...)
        amount = query_component(t, T).amount
        total += _sum_negative_values(amount)
    end
    return total
end

function sum_query(f, world::Ark.World, component_types; kwargs...)
    total = 0.0
    @dub for t in Ark.Query(world, component_types; kwargs...)
        total += f(t)
    end
    return total
end
