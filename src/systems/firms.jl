@inline function precompute_sector_production_costs!(
        sector_production_cost::AbstractVector, technology_matrix::AbstractMatrix,
        sector_prices::AbstractVector,
    )
    mul!(sector_production_cost, transpose(technology_matrix), sector_prices)
    return nothing
end

@inline function expected_sales_amount(demand::Float64, growth::Float64)
    return (1.0 + growth) * demand
end

@inline function desired_investment_amount(
        depreciation_rate::Float64, capital_productivity::Float64,
        expected_sales::Float64,
    )
    return depreciation_rate / capital_productivity * expected_sales
end

@inline function desired_materials_amount(capital_productivity::Float64, expected_sales::Float64)
    return expected_sales / capital_productivity
end

@inline function desired_employment_amount(labor_productivity::Float64, expected_sales::Float64)
    return max(1, round(Int64, expected_sales / labor_productivity))
end

@inline function entity_creation_order(entity)
    return parse(Int, match(r"Entity\((\d+),", string(entity)).captures[1])
end

@inline function expected_profit_amount(current_profit::Float64, growth::Float64, inflation::Float64)
    return current_profit * (1.0 + growth) * (1.0 + inflation)
end

@inline function expected_deposits_amount(
        expected_profit::Float64, current_loans::Float64,
        debt_installment_rate::Float64, corporate_tax::Float64,
        dividend_payout_ratio::Float64,
    )
    positive_profit = max(0.0, expected_profit)

    return expected_profit -
        debt_installment_rate * current_loans -
        corporate_tax * positive_profit -
        dividend_payout_ratio * (1.0 - corporate_tax) * positive_profit
end

@inline function expected_capital_amount(
        capital_goods_price_index::Float64, inflation::Float64,
        capital_stock::Float64,
    )
    return capital_goods_price_index * (1.0 + inflation) * capital_stock
end

@inline function expected_loans_amount(current_loans::Float64, debt_installment_rate::Float64)
    return (1.0 - debt_installment_rate) * current_loans
end

@inline function target_loans_amount(expected_deposits::Float64, deposits::Float64)
    return max(0.0, -expected_deposits - deposits)
end

@inline function labor_cost_component(wage, labor_productivity, employer_contribution, household_price, inv_price)
    return (1.0 + employer_contribution) * wage / labor_productivity * (household_price * inv_price - 1.0)
end
@inline function material_cost_component(intermediate_productivity, sector_production_cost, inv_price)
    return inv(intermediate_productivity) * (sector_production_cost * inv_price - 1.0)
end
@inline function capital_cost_component(depreciation_rate, capital_productivity, capital_goods_price, inv_price)
    return depreciation_rate / capital_productivity * (capital_goods_price * inv_price - 1.0)
end

@inline function compute_firm_cost_push_inflation(
        wage::Float64, employer_contribution::Float64,
        household_price::Float64, depreciation_rate::Float64,
        intermediate_productivity::Float64, labor_productivity::Float64,
        capital_productivity::Float64, capital_goods_price::Float64,
        sector_production_cost::Float64, inv_price::Float64,
    )
    labor_cost = labor_cost_component(
        wage, labor_productivity, employer_contribution, household_price, inv_price
    )

    material_cost = material_cost_component(
        intermediate_productivity, sector_production_cost, inv_price
    )

    capital_cost = capital_cost_component(
        depreciation_rate, capital_productivity, capital_goods_price, inv_price
    )

    return labor_cost + material_cost + capital_cost
end

@inline function compute_firm_expectation_scalars(
        demand::Float64, capital_stock::Float64,
        current_profit::Float64, current_loans::Float64,
        current_deposits::Float64, growth::Float64,
        inflation::Float64, labor_productivity::Float64,
        capital_productivity::Float64, intermediate_productivity::Float64,
        capital_goods_price::Float64, debt_installment_rate::Float64,
        dividend_payout_ratio::Float64, corporate_tax::Float64,
    )
    expected_sales = expected_sales_amount(demand, growth)

    capacity_constraint_sales = min(expected_sales, capital_stock * capital_productivity)

    desired_materials = desired_materials_amount(intermediate_productivity, capacity_constraint_sales)

    desired_employment = desired_employment_amount(labor_productivity, capacity_constraint_sales)

    expected_profit = expected_profit_amount(current_profit, growth, inflation)

    expected_deposits = expected_deposits_amount(
        expected_profit, current_loans, debt_installment_rate,
        corporate_tax, dividend_payout_ratio,
    )

    expected_capital = expected_capital_amount(capital_goods_price, inflation, capital_stock)

    expected_loans = expected_loans_amount(current_loans, debt_installment_rate)

    target_loans = target_loans_amount(expected_deposits, current_deposits)

    return (
        expected_sales, desired_materials, desired_employment, expected_profit,
        expected_capital, expected_loans, target_loans,
    )
end

const FIRM_EXPECTATION_COMPONENTS = (
    PrincipalProduct, Price, AverageWageRate, CapitalDeprecationRate,
    IntermediateProductivity, LaborProductivity, CapitalProductivity,
    GoodsDemand, CapitalStock, Profits, LoansOutstanding, Deposits,
    DesiredInvestment, DesiredMaterials, DesiredEmployment, ExpectedProfits,
    ExpectedCapital, ExpectedLoans, ExpectedSales, TargetLoans,
)

function set_firms_expectations_and_decisions!(world::Ark.World)
    expectations = Ark.get_resource(world, Expectations)
    price_indices = Ark.get_resource(world, PriceIndices)
    properties = Ark.get_resource(world, Properties)
    firm_cache = Ark.get_resource(world, FirmTmpBuffers{Float64})

    growth = expectations.output_growth
    inflation = expectations.inflation

    use_capacity_sales_for_investment = false
    investment_sales_match = true

    sector = price_indices.sector
    household = price_indices.household_consumption
    capital_goods = price_indices.capital_goods

    technology_matrix = properties.product_coeffs.technology_matrix
    employer_contribution = properties.social_insurance.employers_contribution

    debt_installment_rate = properties.banking_params.debt_installment_rate
    dividend_payout_ratio = properties.banking_params.dividend_payout_ratio
    corporate_tax = properties.tax_rates.corporate

    precompute_sector_production_costs!(
        firm_cache.sector_production_cost, technology_matrix, sector,
    )

    @dub for t in Ark.Query(world, FIRM_EXPECTATION_COMPONENTS)
        @inbounds for i in eachindex(t.e)
            product_id = t.principal_product[i].id
            price = t.price[i].value
            inv_price = inv(price)

            wage = t.average_wage_rate[i].rate
            δ = t.capital_depreciation_rate[i].rate
            a_m = t.intermediate_productivity[i].value
            a_l = t.labor_productivity[i].value
            a_k = t.capital_productivity[i].value

            demand = t.goods_demand[i].amount
            capital_stock = t.capital_stock[i].amount
            current_profit = t.profits[i].amount
            current_loans = t.loans_outstanding[i].amount
            current_deposits = t.deposits[i].amount

            sector_production_cost = firm_cache.sector_production_cost[product_id]

            cost_push_inflation = compute_firm_cost_push_inflation(
                wage, employer_contribution, household, δ, a_m, a_l, a_k,
                capital_goods, sector_production_cost, inv_price,
            )

            (
                expected_sales_amount, desired_materials_amount,
                desired_employment_amount, expected_profit_amount,
                expected_capital_amount, expected_loans_amount,
                target_loans_amount,
            ) = compute_firm_expectation_scalars(
                demand, capital_stock, current_profit, current_loans,
                current_deposits, growth, inflation, a_l, a_k, a_m,
                capital_goods, debt_installment_rate, dividend_payout_ratio,
                corporate_tax,
            )

            capacity_sales_amount = capital_stock * a_k
            if investment_sales_match && !isequal(capacity_sales_amount, expected_sales_amount)
                use_capacity_sales_for_investment = capacity_sales_amount < expected_sales_amount
                investment_sales_match = false
            end

            desired_investment_sales = use_capacity_sales_for_investment ? capacity_sales_amount : expected_sales_amount

            t.desired_investment[i] = desired_investment_amount(δ, a_k, desired_investment_sales) |> DesiredInvestment
            t.desired_materials[i] = desired_materials_amount |> DesiredMaterials
            t.desired_employment[i] = desired_employment_amount |> DesiredEmployment
            t.expected_sales[i] = expected_sales_amount |> ExpectedSales
            t.expected_profits[i] = expected_profit_amount |> ExpectedProfits
            t.expected_capital[i] = expected_capital_amount |> ExpectedCapital
            t.expected_loans[i] = expected_loans_amount |> ExpectedLoans
            t.target_loans[i] = target_loans_amount |> TargetLoans
            t.price[i] = price * (1 + cost_push_inflation) * (1 + inflation) |> Price
        end
    end

    return nothing
end

function firm_wage(
        baseline_wage, expected_sales,
        capital_stock, capital_productivity,
        materials, intermediate_productivity,
        employment, labor_productivity,
    )
    constrained_output = min(
        expected_sales,
        min(capital_stock * capital_productivity, materials * intermediate_productivity),
    )
    return baseline_wage * min(1.5, constrained_output / (employment * labor_productivity))
end

const FIRM_WAGE_COMPONENTS = (
    ExpectedSales, WageBill, CapitalStock, Intermediates, Employment, LaborProductivity,
    CapitalProductivity, IntermediateProductivity, AverageWageRate,
)

function set_firms_wages!(world::Ark.World)
    @dub for t in Ark.Query(world, FIRM_WAGE_COMPONENTS)
        t.wage_bill.amount .= firm_wage.(
            t.average_wage_rate.rate, t.expected_sales.amount,
            t.capital_stock.amount, t.capital_productivity.value,
            t.intermediates.amount, t.intermediate_productivity.value,
            t.employment.amount, t.labor_productivity.value
        )
    end

    return
end

@inline function firm_labor_productivity(
        baseline_labor_productivity, expected_sales, capital_stock, capital_productivity,
        materials, intermediate_productivity, employment,
    )
    constrained_output = min(
        expected_sales,
        min(capital_stock * capital_productivity, materials * intermediate_productivity),
    )
    return baseline_labor_productivity *
        min(1.5, constrained_output / (employment * baseline_labor_productivity))
end

@inline function firm_production(
        expected_sales, employment, labor_productivity, capital_stock, capital_productivity,
        materials, intermediate_productivity,
    )
    return min(
        expected_sales,
        min(
            employment * labor_productivity,
            min(capital_stock * capital_productivity, materials * intermediate_productivity),
        ),
    )
end

const FIRM_PRODUCTION_COMPONENTS = (
    ExpectedSales, Output, Employment, LaborProductivity, CapitalStock, CapitalProductivity,
    Intermediates, IntermediateProductivity,
)

function set_firms_production!(world::Ark.World)
    @dub for t in Ark.Query(world, FIRM_PRODUCTION_COMPONENTS)
        for i in eachindex(t.e)
            effective_labor_productivity = firm_labor_productivity(
                t.labor_productivity[i].value, t.expected_sales[i].amount,
                t.capital_stock[i].amount, t.capital_productivity[i].value,
                t.intermediates[i].amount, t.intermediate_productivity[i].value,
                t.employment[i].amount,
            )
            t.output[i] = firm_production(
                t.expected_sales[i].amount, t.employment[i].amount,
                effective_labor_productivity, t.capital_stock[i].amount,
                t.capital_productivity[i].value, t.intermediates[i].amount,
                t.intermediate_productivity[i].value,
            ) |> Output
        end
    end
    return nothing
end


@inline function firm_profit(
        price::T, quantity::T, excess_sales::T, deposits::T, wage::T, employment::V,
        household_price_index::T, employer_contribution::T, intermediate_productivity::T,
        intermediate_price::T, output::T, depreciation_rate::T, capital_productivity::T,
        capital_goods_price::T, product_tax_rate::T, capital_tax_rate::T, loans::T,
        lending_rate::T, deposit_rate::T,
    ) where {T <: Real, V <: Real}
    in_sales = price * quantity + price * excess_sales
    in_deposits = deposit_rate * pos(deposits)

    out_wages = (1 + employer_contribution) * wage * employment * household_price_index
    out_expenses = inv(intermediate_productivity) * intermediate_price * output
    out_depreciation = depreciation_rate / capital_productivity * capital_goods_price * output
    out_taxes_prods = product_tax_rate * price * output
    out_taxes_capital = capital_tax_rate * price * output
    out_loans = lending_rate * (loans + max(0.0, -deposits))

    return in_sales + in_deposits - out_wages - out_expenses - out_depreciation -
        out_taxes_prods - out_taxes_capital - out_loans
end

const FIRM_PROFIT_COMPONENTS = (
    Profits, Price, Sales, Output, FinalGoodsStockChange, Deposits, WageBill, Employment,
    IntermediateProductivity, PriceIndex, CapitalDeprecationRate, CapitalProductivity,
    CFPriceIndex, TaxRates, LoansOutstanding,
)

function set_firms_profits!(world::Ark.World)
    price_indices = Ark.get_resource(world, PriceIndices)
    properties = Ark.get_resource(world, Properties)

    _, r = single(Ark.Query(world, (LendingRate,)))
    _, r_bar = single(Ark.Query(world, (NominalInterestRate,)))

    @dub for t in Ark.Query(world, FIRM_PROFIT_COMPONENTS)
        @inbounds for i in eachindex(t.e)
            t.profits[i] = firm_profit(
                t.price.value[i], t.sales.amount[i], t.final_goods_stock_change.amount[i],
                t.deposits.amount[i], t.wage_bill.amount[i], t.employment.amount[i],
                price_indices.household_consumption, properties.social_insurance.employers_contribution,
                t.intermediate_productivity.value[i], t.price_index.value[i], t.output.amount[i],
                t.capital_depreciation_rate.rate[i], t.capital_productivity.value[i],
                t.cf_price_index.value[i], t.tax_rates.output[i], t.tax_rates.capital[i],
                t.loans_outstanding.amount[i], r.rate, r_bar.rate,
            ) |> Profits
        end

    end

    return nothing
end

@inline pos(x) = max(zero(x), x)

@inline function firm_deposits(
        deposits, price, sales, wage_bill, employment, household_price_index, employer_contribution,
        materials_stock_change, intermediate_price_index, output_tax_rate, output, capital_tax_rate,
        profits, corporate_tax_rate, dividend_payout_ratio, loans, lending_rate, deposit_rate,
        capital_goods_price_index, investment, loan_flow, debt_installment_rate,
    )
    sales_income = price * sales
    labour_cost = -(1.0 + employer_contribution) * wage_bill * employment * household_price_index
    material_cost = -materials_stock_change * intermediate_price_index
    taxes_products = -output_tax_rate * price * output
    taxes_production = -capital_tax_rate * price * output
    corporate_tax = -corporate_tax_rate * pos(profits)
    dividend_payments = -dividend_payout_ratio * (1.0 - corporate_tax_rate) * pos(profits)
    interest_payments = -lending_rate * (loans + pos(-deposits))
    interest_received = deposit_rate * pos(deposits)
    investment_cost = -capital_goods_price_index * investment
    debt_installment = -debt_installment_rate * loans

    deposit_change = sales_income + labour_cost + material_cost + taxes_products + taxes_production +
        corporate_tax + dividend_payments + interest_payments + interest_received + investment_cost +
        loan_flow + debt_installment

    return deposits + deposit_change
end

@inline function firm_equity(
        deposits, intermediates, sector_production_cost, price, inventories, capital_goods_price_index,
        capital_stock, loans,
    )
    return deposits +
        intermediates * sector_production_cost +
        price * inventories +
        capital_goods_price_index * capital_stock -
        loans
end

@inline function next_capital_stock(
        capital_stock, depreciation_rate, capital_productivity, output, investment,
    )
    return capital_stock - depreciation_rate / capital_productivity * output + investment
end

@inline function next_intermediates(
        intermediates, output, intermediate_productivity, materials_stock_change,
    )
    return intermediates - output / intermediate_productivity + materials_stock_change
end


const FIRM_DEPOSIT_COMPONENTS = (
    Deposits, Price, Sales, WageBill, Employment, MaterialsStockChange, PriceIndex, TaxRates,
    Output, CFPriceIndex, Profits, LoansOutstanding, Investment, LoanFlow,
)

function set_firms_deposits!(world::Ark.World)
    price_indices = Ark.get_resource(world, PriceIndices)
    properties = Ark.get_resource(world, Properties)

    _, r = single(Ark.Query(world, (LendingRate,)))
    _, r_bar = single(Ark.Query(world, (NominalInterestRate,)))

    employer_contribution = properties.social_insurance.employers_contribution
    corporate_tax_rate = properties.tax_rates.corporate
    dividend_payout_ratio = properties.banking_params.dividend_payout_ratio
    debt_installment_rate = properties.banking_params.debt_installment_rate

    household_price_index = price_indices.household_consumption

    @dub for t in Ark.Query(world, FIRM_DEPOSIT_COMPONENTS)
        for i in eachindex(t.deposits)
            t.deposits[i] = firm_deposits(
                t.deposits[i].amount, t.price[i].value, t.sales[i].amount,
                t.wage_bill[i].amount, t.employment[i].amount, household_price_index,
                employer_contribution, t.materials_stock_change[i].amount,
                t.price_index[i].value, t.tax_rates[i].output, t.output[i].amount,
                t.tax_rates[i].capital, t.profits[i].amount, corporate_tax_rate,
                dividend_payout_ratio, t.loans_outstanding[i].amount,
                r.rate, r_bar.rate, t.cf_price_index[i].value, t.investment[i].amount,
                t.loan_flow[i].amount, debt_installment_rate,
            ) |> Deposits
        end
    end

    return nothing
end

const FIRM_EQUITY_COMPONENTS = (
    Equity, Deposits, Intermediates, PrincipalProduct, Price, Inventories, CapitalStock,
    LoansOutstanding,
)

function set_firms_equity!(world::Ark.World)
    price_indices = Ark.get_resource(world, PriceIndices)
    properties = Ark.get_resource(world, Properties)
    firm_cache = Ark.get_resource(world, FirmTmpBuffers{Float64})

    precompute_sector_production_costs!(
        firm_cache.sector_production_cost, properties.product_coeffs.technology_matrix,
        price_indices.sector,
    )

    sector_costs = firm_cache.sector_production_cost
    capital_goods_price_index = price_indices.capital_goods

    @dub for t in Ark.Query(world, FIRM_EQUITY_COMPONENTS)
        @inbounds for i in eachindex(t.e)
            t.equity[i] = firm_equity(
                t.deposits[i].amount, t.intermediates[i].amount,
                sector_costs[t.principal_product[i].id], t.price[i].value,
                t.inventories[i].amount, capital_goods_price_index, t.capital_stock[i].amount,
                t.loans_outstanding[i].amount,
            ) |> Equity
        end
    end

    return nothing
end

const FIRM_LOAN_COMPONENTS = (LoansOutstanding, LoanFlow)

function set_firms_loans!(world::Ark.World)
    debt_installment_rate = Ark.get_resource(world, Properties).banking_params.debt_installment_rate

    @dub for t in Ark.Query(world, FIRM_LOAN_COMPONENTS)
        @inbounds t.loans_outstanding.amount .= (1.0 - debt_installment_rate) .* t.loans_outstanding.amount .+ t.loan_flow.amount
    end

    return nothing
end

const FIRM_STOCK_COMPONENTS = (
    CapitalStock, CapitalDeprecationRate, CapitalProductivity, Output, Investment, Intermediates,
    IntermediateProductivity, MaterialsStockChange, Sales, FinalGoodsStockChange, Inventories,
)

function set_firms_stocks!(world::Ark.World)
    @dub for t in Ark.Query(world, FIRM_STOCK_COMPONENTS)
        @inbounds t.final_goods_stock_change.amount .= t.output.amount .- t.sales.amount

        @inbounds t.capital_stock.amount .= next_capital_stock.(
            t.capital_stock.amount, t.capital_depreciation_rate.rate,
            t.capital_productivity.value, t.output.amount, t.investment.amount,
        )

        @inbounds t.intermediates.amount .= next_intermediates.(
            t.intermediates.amount, t.output.amount, t.intermediate_productivity.value,
            t.materials_stock_change.amount,
        )

        @inbounds t.inventories.amount .= t.inventories.amount .+ t.final_goods_stock_change.amount
    end

    return nothing
end
