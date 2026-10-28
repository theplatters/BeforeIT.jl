function search_and_matching_credit!(world::Ark.World)
    @dub for t in Ark.Query(world, (LoanFlow,), with = (Firm,))
        t.loan_flow.amount .= 0.0
    end

    cache = Ark.get_resource(world, CreditMatchingCache)

    # every bank rations credit to its own clients against its own capital
    @dub for b in Ark.Query(world, (Equity,), with = (Bank,))
        for k in eachindex(b.e)
            match_bank_credit!(world, cache, b.e[k], b.equity[k].amount)
        end
    end

    return nothing
end

function match_bank_credit!(world::Ark.World, cache, bank::Ark.Entity, equity::Float64)
    (; capital_requirement, loan_to_value_ratio, overdrafts_in_capital_ratio) =
        BeforeIT.properties(world).banking_params
    account = (BankAccount => bank,)

    # the credit-supply constraint binds on the bank's whole loan book
    exposure = sum_amount(world, ExpectedLoans, with = account)
    if overdrafts_in_capital_ratio
        exposure += sum_negative_amount(world, Deposits, with = account)
    end
    total_loans = 0.0

    active_firms = cache.active_firms

    n_active = 0
    @dub for t in Ark.Query(world, (TargetLoans,), with = (Firm, account...))
        for i in eachindex(t.e)
            if t.target_loans[i].amount > 0.0
                n_active += 1
                active_firms[n_active] = t.e[i]
            end
        end
    end

    active_view = @view active_firms[1:n_active]
    shuffle!(active_view)

    for firm in active_view
        target_loan, expected_loan, expected_capital = Ark.get_components(
            world, firm, (TargetLoans, ExpectedLoans, ExpectedCapital),
        )
        amount = max(
            0.0,
            min(
                target_loan.amount,
                loan_to_value_ratio * expected_capital.amount - expected_loan.amount,
                equity / capital_requirement - exposure - total_loans
            )
        )
        Ark.set_components!(world, firm, (LoanFlow(amount),))
        total_loans += amount
    end

    return nothing
end
