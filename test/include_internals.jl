for C in Bit.BIT_COMPONENTS
    name = C <: Ark.Relation ? nameof(C.parameters[1]) : nameof(C)
    @eval using BeforeIT: $name
end
