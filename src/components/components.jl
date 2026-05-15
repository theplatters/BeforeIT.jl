
const COMPONENTS_VEC = Type[]

include("bank.jl")
include("central_bank.jl")
include("firms.jl")
include("government.jl")
include("households.jl")
include("loans.jl")
include("profits.jl")
include("rest_of_world.jl")
include("workers.jl")

# Convert to Tuple for Ark
const COMPONENTS = Tuple(COMPONENTS_VEC)
