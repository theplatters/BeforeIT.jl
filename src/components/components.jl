
abstract type AbstractComponent end

module Components

import Ark
import BeforeIT: AbstractComponent, FloatType, IntType

const _BIT_COMPONENTS = DataType[]

macro register(def)
    def isa Expr && def.head == :struct || error("expected a struct definition")

    name = def.args[2]

    if name isa Expr && name.head == :<:
        name = name.args[1]
    end

    name isa Symbol || error("parametric structs are not supported")

    return quote
        $def
        push!(_BIT_COMPONENTS, $name)
    end
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

const BIT_COMPONENTS = Tuple(Components._BIT_COMPONENTS)

for C in BIT_COMPONENTS
    @eval using .Components: $(nameof(C))
end