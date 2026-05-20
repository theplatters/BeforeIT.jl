function search_and_matching_credit!(world::Ark.World)
    (; capital_requirement, loan_to_value_ratio) = BeforeIT.properties(world).banking_params
    total_expected_loans = @sum_over (el.amount for el in Ark.Query(world, (ExpectedLoans,)))
    total_loans = 0.0
    (_, E_k) = single(Ark.Query(world, (Equity,), with = (Bank,)))

    for (_, loan_flow) in Ark.Query(world, (LoanFlow,), with = (Firm,))
        loan_flow.amount .= 0.0
    end

    cache = Ark.get_resource(world, CreditMatchingCache)

    n_active = 0
    for (e, loan_flow, target_loan, expected_loan, expected_capital) in Ark.Query(
            world,
            (LoanFlow, TargetLoans, ExpectedLoans, ExpectedCapital),
        )
        for i in eachindex(e)
            if target_loan[i].amount > 0.0
                n_active += 1
                cache.active_rows[n_active] = i
            end
        end
    end

    active_view = @view cache.active_rows[1:n_active]
    shuffle!(active_view)

    for (e, loan_flow, target_loan, expected_loan, expected_capital) in Ark.Query(
            world,
            (LoanFlow, TargetLoans, ExpectedLoans, ExpectedCapital),
        )
        for i in active_view
            loan_flow[i] = LoanFlow(
                max(
                    0.0,
                    min(
                        target_loan[i].amount,
                        loan_to_value_ratio * expected_capital[i].amount - expected_loan[i].amount,
                        E_k.amount / capital_requirement - total_expected_loans - total_loans
                    )
                )
            )
            total_loans += loan_flow[i].amount
        end
    end

    return nothing
end
