
struct EuroAreaGDP <: AbstractComponent
    value::FloatType
end

struct EuroAreaGrowth <: AbstractComponent
    rate::FloatType
end

struct EuroAreaInflation <: AbstractComponent
    rate::FloatType
end

struct NetForeignPosition <: AbstractComponent
    amount::FloatType
end

struct ImportSupply <: AbstractComponent
    amount::FloatType
end

struct TotalExportDemand <: AbstractComponent
    amount::FloatType
end

struct TotalImportSupply <: AbstractComponent
    amount::FloatType
end

struct ExportDemand <: AbstractComponent
    amount::FloatType
end

struct ImportSales <: AbstractComponent
    amount::FloatType
end

struct ImportDemand <: AbstractComponent
    amount::FloatType
end
struct ImportPrice <: AbstractComponent
    value::FloatType
end

struct ExportPriceInflation <: AbstractComponent
    value::FloatType
end

struct ForeignSector <: AbstractComponent end

struct ForeignConsumptionDemand <: AbstractComponent
    amount::FloatType
end

struct ForeignConsumption <: AbstractComponent
    amount::FloatType
end

struct RestOfWorldEntity <: AbstractComponent
    entity::Ark.Entity
end

struct RestOfWorld <: AbstractComponent end
