function search_and_matching_credit!(world::Ark.World)
    (; capital_requirement, loan_to_value_ratio) = BeforeIT.properties(world).banking_params
    total_expected_loans = @sum_over (el.amount for el in Ark.Query(world, (Components.ExpectedLoans,)))
    total_loans = 0.0
    (_, E_k) = single(Ark.Query(world, (Components.Equity,), with = (Components.Bank,)))

    for (_, loan_flow) in Ark.Query(world, (Components.LoanFlow,), with = (Components.Firm,))
        loan_flow.amount .= 0.0
    end

    rows = NamedTuple[]
    for (e, loan_flow, target_loan, expected_loan, expected_capital) in Ark.Query(
            world,
            (Components.LoanFlow, Components.TargetLoans, Components.ExpectedLoans, Components.ExpectedCapital),
        )
        for i in eachindex(e)
            push!(rows, (
                entity = e[i],
                loan_flow = loan_flow,
                target_loan = target_loan,
                expected_loan = expected_loan,
                expected_capital = expected_capital,
                index = i,
            ))
        end
    end

    sort!(rows; by = row -> row.entity)
    active_rows = findall(row -> row.target_loan[row.index].amount > 0.0, rows)
    shuffle!(active_rows)

    for row_index in active_rows
        row = rows[row_index]
        i = row.index
        loan_flow = row.loan_flow
        target_loan = row.target_loan
        expected_loan = row.expected_loan
        expected_capital = row.expected_capital

        loan_flow[i] = Components.LoanFlow(
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

    return nothing
end
