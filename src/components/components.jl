abstract type AbstractComponent end

include("bank.jl")
include("central_bank.jl")
include("firms.jl")
include("government.jl")
include("households.jl")
include("loans.jl")
include("profits.jl")
include("rest_of_world.jl")
include("workers.jl")

const COMPONENTS_VEC = [
    ResidualItems, LendingRate, Banker, Bank, NominalInterestRate,
    GovernmentBondInterestRate, GradualAdjustmentRate, EquilibriumInterestRate, InflationTargetingWeight,
    EconomicWeight, CentralBank, PrincipalProduct, LaborProductivity, IntermediateProductivity,
    CapitalProductivity, FirmProperties, CapitalDeprecationRate, OperatingMargins, WageBill,
    AverageWageRate, TaxRates, Price, PriceIndex, CFPriceIndex, Employment,
    Vacancies, DesiredEmployment, Output, Sales, GoodsDemand,
    Inventories, Intermediates, Investment, Equity, FinalGoodsStockChange,
    MaterialsStockChange, TargetLoans, ExpectedCapital, ExpectedLoans, ExpectedSales,
    DesiredInvestment, DesiredMaterials, Owner, Capitalist, Firm,
    GovernmentRevenues, SocialBenefitsInactive, SocialBenefitsOther, PriceInflationGovernmentGoods,
    GovernmentDebt, ConsumptionDemand, LocalGovernment, Government, NetDisposableIncome, ExpectedIncome,
    Deposits, CapitalStock, ConsumptionBudget, InvestmentBudget, RealisedConsumption,
    RealisedInvestment, Household, LoansOutstanding, LoanFlow, Profits,
    ExpectedProfits, EuroAreaGDP, EuroAreaGrowth, EuroAreaInflation, NetForeignPosition,
    ImportSupply, TotalExportDemand, TotalImportSupply, ExportDemand, ImportSales,
    ImportDemand, ImportPrice, ExportPriceInflation, ForeignSector, ForeignConsumptionDemand,
    ForeignConsumption, RestOfWorldEntity, RestOfWorld, Employed, EmployedAt,
    Inactive, Unemployed,
]

# Convert to Tuple for Ark
const COMPONENTS = Tuple(COMPONENTS_VEC)
