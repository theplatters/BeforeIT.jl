# src/resources/data_collector.jl

mutable struct DataCollector
    collection_time::Vector{Int64}
    nominal_gdp::Vector{Float64}
    real_gdp::Vector{Float64}
    nominal_gva::Vector{Float64}
    real_gva::Vector{Float64}
    nominal_household_consumption::Vector{Float64}
    real_household_consumption::Vector{Float64}
    nominal_government_consumption::Vector{Float64}
    real_government_consumption::Vector{Float64}
    nominal_capitalformation::Vector{Float64}
    real_capitalformation::Vector{Float64}
    nominal_fixed_capitalformation::Vector{Float64}
    real_fixed_capitalformation::Vector{Float64}
    nominal_fixed_capitalformation_dwellings::Vector{Float64}
    real_fixed_capitalformation_dwellings::Vector{Float64}
    nominal_exports::Vector{Float64}
    real_exports::Vector{Float64}
    nominal_imports::Vector{Float64}
    real_imports::Vector{Float64}
    operating_surplus::Vector{Float64}
    compensation_employees::Vector{Float64}
    wages::Vector{Float64}
    taxes_production::Vector{Float64}
    gdp_deflator_growth_ea::Vector{Float64}
    real_gdp_ea::Vector{Float64}
    euribor::Vector{Float64}
    nominal_sector_gva::Vector{Vector{Float64}}
    real_sector_gva::Vector{Vector{Float64}}

    function DataCollector(props::Properties)
        new(
            Int64[], # collection_time
            Float64[], # nominal_gdp
            Float64[], # real_gdp
            Float64[], # nominal_gva
            Float64[], # real_gva
            Float64[], # nominal_household_consumption
            Float64[], # real_household_consumption
            Float64[], # nominal_government_consumption
            Float64[], # real_government_consumption
            Float64[], # nominal_capitalformation
            Float64[], # real_capitalformation
            Float64[], # nominal_fixed_capitalformation
            Float64[], # real_fixed_capitalformation
            Float64[], # nominal_fixed_capitalformation_dwellings
            Float64[], # real_fixed_capitalformation_dwellings
            Float64[], # nominal_exports
            Float64[], # real_exports
            Float64[], # nominal_imports
            Float64[], # real_imports
            Float64[], # operating_surplus
            Float64[], # compensation_employees
            Float64[], # wages
            Float64[], # taxes_production
            Float64[], # gdp_deflator_growth_ea
            Float64[], # real_gdp_ea
            Float64[], # euribor
            Vector{Float64}[], # nominal_sector_gva
            Vector{Float64}[]  # real_sector_gva
        )
    end
end
