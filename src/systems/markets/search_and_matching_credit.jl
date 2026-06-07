function search_and_matching_credit!(world::Ark.World)
    (; capital_requirement, loan_to_value_ratio) = BeforeIT.properties(world).banking_params
    total_expected_loans = @sum_over (el.amount for el in Ark.Query(world, (ExpectedLoans,)))
    total_loans = 0.0
    (_, E_k) = single(Ark.Query(world, (Equity,), with = (Bank,)))

    for (_, loan_flow) in Ark.Query(world, (LoanFlow,), with = (Firm,))
        loan_flow.amount .= 0.0
    end

    cache = Ark.get_resource(world, CreditMatchingCache)
    active_firms = cache.active_firms

    n_active = 0
    for (e, target_loan) in Ark.Query(
            world,
            (TargetLoans,),
            with = (Firm,),
        )
        for i in eachindex(e)
            if target_loan[i].amount > 0.0
                n_active += 1
                active_firms[n_active] = e[i]
            end
        end
    end

    active_view = @view active_firms[1:n_active]
    shuffle!(active_view)

    for firm in active_view
        target_loan, expected_loan, expected_capital = Ark.get_components(
            world,
            firm,
            (TargetLoans, ExpectedLoans, ExpectedCapital),
        )
        amount = max(
            0.0,
            min(
                target_loan.amount,
                loan_to_value_ratio * expected_capital.amount - expected_loan.amount,
                E_k.amount / capital_requirement - total_expected_loans - total_loans
            )
        )
        Ark.set_components!(
            world,
            firm,
            (
                LoanFlow(amount),
            )
        )
        total_loans += amount
    end

    return nothing
end
