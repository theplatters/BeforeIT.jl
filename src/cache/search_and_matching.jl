struct RetailRealisationCache
    consumption_budget::Vector{Float64}
    investment_budget::Vector{Float64}
    final_demand_amount::Vector{Float64}
    government_consumption::Vector{Float64}
    government_price::Vector{Float64}
    foreign_consumption::Vector{Float64}
    export_price::Vector{Float64}
    household_consumption_price::Vector{Float64}
    household_investment_price::Vector{Float64}
end

function RetailRealisationCache(households::Int64, final_demands::Int64, sectors::Int64)
    return RetailRealisationCache(
        zeros(households),
        zeros(households),
        zeros(final_demands),
        zeros(sectors),
        zeros(sectors),
        zeros(sectors),
        zeros(sectors),
        zeros(sectors),
        zeros(sectors),
    )
end

function choose_random_firm(weights)
    return rand(weights)
end
