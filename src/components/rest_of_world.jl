@register struct EuroAreaGDP <: AbstractComponent
    value::FloatType
end

@register struct EuroAreaGrowth <: AbstractComponent
    rate::FloatType
end

@register struct EuroAreaInflation <: AbstractComponent
    rate::FloatType
end

@register struct NetForeignPosition <: AbstractComponent
    amount::FloatType
end

@register struct ImportSupply <: AbstractComponent
    amount::FloatType
end

@register struct TotalExportDemand <: AbstractComponent
    amount::FloatType
end

@register struct TotalImportSupply <: AbstractComponent
    amount::FloatType
end

@register struct ExportDemand <: AbstractComponent
    amount::FloatType
end

@register struct ImportSales <: AbstractComponent
    amount::FloatType
end

@register struct ImportDemand <: AbstractComponent
    amount::FloatType
end

@register struct ImportPrice <: AbstractComponent
    value::FloatType
end

@register struct ExportPriceInflation <: AbstractComponent
    value::FloatType
end

@register struct ForeignSector <: AbstractComponent end

@register struct ForeignConsumptionDemand <: AbstractComponent
    amount::FloatType
end

@register struct ForeignConsumption <: AbstractComponent
    amount::FloatType
end

@register struct RestOfWorldEntity <: AbstractComponent
    entity::Ark.Entity
end

@register struct RestOfWorld <: AbstractComponent end
