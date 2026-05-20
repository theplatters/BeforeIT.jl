abstract type AbstractComponent end

module Components

    export BIT_COMPONENTS

    using Ark
    import BeforeIT: AbstractComponent, FloatType, IntType

    const BIT_COMPONENTS = DataType[]

    macro register(type, def)
        def isa Expr && def.head == :struct || error("expected a struct definition")

        name = def.args[2]

        if name isa Expr && name.head == :<:
            name = name.args[1]
        end

        name isa Symbol || error("parametric structs are not supported")

        relation = :($Ark.Relation)

        comp_type = type == QuoteNode(:relation) ? Expr(:curly, relation, esc(name)) : esc(name)

        return quote
            $(esc(def))
            push!($Components.BIT_COMPONENTS, $comp_type)
        end
    end

    macro register(def)
        return esc(:(@register(:standard, $def)))
    end

    include("bank.jl")
    include("central_bank.jl")
    include("firms.jl")
    include("government.jl")
    include("households.jl")
    include("loans.jl")
    include("profits.jl")
    include("rest_of_world.jl")
    include("workers.jl")

end

using .Components

for C in BIT_COMPONENTS
    name = C <: Ark.Relation ? nameof(C.parameters[1]) : nameof(C)
    @eval using .Components: $name
end
