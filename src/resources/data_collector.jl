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
        len = props.dimensions.maximum_periods + props.dimensions.interval_for_expectation_estimation
        num_sectors = props.dimensions.sectors
        new(
            Int64[], # collection_time
            zeros(len), # nominal_gdp
            zeros(len), # real_gdp
            zeros(len), # nominal_gva
            zeros(len), # real_gva
            zeros(len), # nominal_household_consumption
            zeros(len), # real_household_consumption
            zeros(len), # nominal_government_consumption
            zeros(len), # real_government_consumption
            zeros(len), # nominal_capitalformation
            zeros(len), # real_capitalformation
            zeros(len), # nominal_fixed_capitalformation
            zeros(len), # real_fixed_capitalformation
            zeros(len), # nominal_fixed_capitalformation_dwellings
            zeros(len), # real_fixed_capitalformation_dwellings
            zeros(len), # nominal_exports
            zeros(len), # real_exports
            zeros(len), # nominal_imports
            zeros(len), # real_imports
            zeros(len), # operating_surplus
            zeros(len), # compensation_employees
            zeros(len), # wages
            zeros(len), # taxes_production
            zeros(len), # gdp_deflator_growth_ea
            zeros(len), # real_gdp_ea
            zeros(len), # euribor
            [zeros(num_sectors) for _ in 1:len], # nominal_sector_gva
            [zeros(num_sectors) for _ in 1:len]  # real_sector_gva
        )
    end
end
