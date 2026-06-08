component_field_name(::Type{Ark.Relation{T}}) where {T} = component_field_name(T)
component_field_name(::Type{ActiveBuyers}) = :active_buyers
component_field_name(::Type{AverageWageRate}) = :average_wage_rate
component_field_name(::Type{Bank}) = :bank
component_field_name(::Type{Banker}) = :banker
component_field_name(::Type{CapitalDeprecationRate}) = :capital_depreciation_rate
component_field_name(::Type{CapitalProductivity}) = :capital_productivity
component_field_name(::Type{CapitalStock}) = :capital_stock
component_field_name(::Type{Capitalist}) = :capitalist
component_field_name(::Type{CentralBank}) = :central_bank
component_field_name(::Type{CFPriceIndex}) = :cf_price_index
component_field_name(::Type{ConsumptionBudget}) = :consumption_budget
component_field_name(::Type{ConsumptionDemand}) = :consumption_demand
component_field_name(::Type{ConsumptionShock}) = :consumption_shock
component_field_name(::Type{Deposits}) = :deposits
component_field_name(::Type{DesiredEmployment}) = :desired_employment
component_field_name(::Type{DesiredInvestment}) = :desired_investment
component_field_name(::Type{DesiredMaterials}) = :desired_materials
component_field_name(::Type{Employed}) = :employed
component_field_name(::Type{EmployedAt}) = :employed_at
component_field_name(::Type{Employment}) = :employment
component_field_name(::Type{Equity}) = :equity
component_field_name(::Type{EuroAreaGDP}) = :euro_area_gdp
component_field_name(::Type{EuroAreaGrowth}) = :euro_area_growth
component_field_name(::Type{EuroAreaInflation}) = :euro_area_inflation
component_field_name(::Type{ExpectedCapital}) = :expected_capital
component_field_name(::Type{ExpectedIncome}) = :expected_income
component_field_name(::Type{ExpectedLoans}) = :expected_loans
component_field_name(::Type{ExpectedProfits}) = :expected_profits
component_field_name(::Type{ExpectedSales}) = :expected_sales
component_field_name(::Type{ExportPriceInflation}) = :export_price_inflation
component_field_name(::Type{FinalDemandCacheIndex}) = :final_demand_cache_index
component_field_name(::Type{FinalGoodsStockChange}) = :final_goods_stock_change
component_field_name(::Type{FinalMarketDemandBook}) = :final_market_demand_book
component_field_name(::Type{FinalMarketDemandClearing}) = :final_market_demand_clearing
component_field_name(::Type{Firm}) = :firm
component_field_name(::Type{FirstPassFinalDemand}) = :first_pass_final_demand
component_field_name(::Type{FirstPassIntermediateDemand}) = :first_pass_intermediate_demand
component_field_name(::Type{ForeignConsumption}) = :foreign_consumption
component_field_name(::Type{ForeignConsumptionDemand}) = :foreign_consumption_demand
component_field_name(::Type{ForeignSector}) = :foreign_sector
component_field_name(::Type{GoodsDemand}) = :goods_demand
component_field_name(::Type{Government}) = :government
component_field_name(::Type{GovernmentDebt}) = :government_debt
component_field_name(::Type{GovernmentRevenues}) = :government_revenues
component_field_name(::Type{Household}) = :household
component_field_name(::Type{ImportDemand}) = :import_demand
component_field_name(::Type{ImportPrice}) = :import_price
component_field_name(::Type{ImportSales}) = :import_sales
component_field_name(::Type{ImportSupply}) = :import_supply
component_field_name(::Type{Inactive}) = :inactive
component_field_name(::Type{IntermediateMarketDemandBook}) = :intermediate_market_demand_book
component_field_name(::Type{IntermediateMarketDemandClearing}) = :intermediate_market_demand_clearing
component_field_name(::Type{IntermediateProductivity}) = :intermediate_productivity
component_field_name(::Type{IntermediaryDemandCacheIndex}) = :intermediary_demand_cache_index
component_field_name(::Type{Intermediates}) = :intermediates
component_field_name(::Type{InterestRateShock}) = :interest_rate_shock
component_field_name(::Type{Inventories}) = :inventories
component_field_name(::Type{Investment}) = :investment
component_field_name(::Type{InvestmentBudget}) = :investment_budget
component_field_name(::Type{LaborProductivity}) = :labor_productivity
component_field_name(::Type{LendingRate}) = :lending_rate
component_field_name(::Type{LoanFlow}) = :loan_flow
component_field_name(::Type{LoansOutstanding}) = :loans_outstanding
component_field_name(::Type{LocalGovernment}) = :local_government
component_field_name(::Type{Market}) = :market
component_field_name(::Type{MarketCapacityPool}) = :market_capacity_pool
component_field_name(::Type{MarketPricePool}) = :market_price_pool
component_field_name(::Type{MarketSupplyPool}) = :market_supply_pool
component_field_name(::Type{MarketWeights}) = :market_weights
component_field_name(::Type{MarketWeightVector}) = :market_weight_vector
component_field_name(::Type{MaterialsStockChange}) = :materials_stock_change
component_field_name(::Type{NetDisposableIncome}) = :net_disposable_income
component_field_name(::Type{NetForeignPosition}) = :net_foreign_position
component_field_name(::Type{NominalInterestRate}) = :nominal_interest_rate
component_field_name(::Type{OperatingMargins}) = :operating_margins
component_field_name(::Type{Output}) = :output
component_field_name(::Type{Owner}) = :owner
component_field_name(::Type{Price}) = :price
component_field_name(::Type{PriceIndex}) = :price_index
component_field_name(::Type{PriceInflationGovernmentGoods}) = :price_inflation_government_goods
component_field_name(::Type{PrincipalProduct}) = :principal_product
component_field_name(::Type{ProductivityShock}) = :productivity_shock
component_field_name(::Type{Profits}) = :profits
component_field_name(::Type{RealisedConsumption}) = :realised_consumption
component_field_name(::Type{RealisedInvestment}) = :realised_investment
component_field_name(::Type{ResidualItems}) = :residual_items
component_field_name(::Type{RestOfWorldEntity}) = :rest_of_world_entity
component_field_name(::Type{Sales}) = :sales
component_field_name(::Type{Shock}) = :shock
component_field_name(::Type{SocialBenefitsInactive}) = :social_benefits_inactive
component_field_name(::Type{SocialBenefitsOther}) = :social_benefits_other
component_field_name(::Type{StockCacheIndex}) = :stock_cache_index
component_field_name(::Type{TargetLoans}) = :target_loans
component_field_name(::Type{TaxRates}) = :tax_rates
component_field_name(::Type{TotalExportDemand}) = :total_export_demand
component_field_name(::Type{TotalImportSupply}) = :total_import_supply
component_field_name(::Type{Unemployed}) = :unemployed
component_field_name(::Type{Vacancies}) = :vacancies
component_field_name(::Type{WageBill}) = :wage_bill

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
