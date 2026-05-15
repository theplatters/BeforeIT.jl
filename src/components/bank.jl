
struct ResidualItems <: AbstractComponent
    amount::FloatType
end

struct LendingRate <: AbstractComponent
    rate::FloatType
end

struct Banker <: AbstractComponent end

struct Bank <: AbstractComponent end
