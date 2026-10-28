# # A banking sector with multiple banks

# By default the financial sector is made of a single bank, as in the original model.
# Here we show how to split it into several banks and how to inspect each of them.

import BeforeIT as Bit
import Ark, JLD2
using Plots

# We load the standard Austrian parameters and initial conditions as dictionaries,
# so that we can change a parameter before building the model
dir = joinpath(pkgdir(Bit), "data", "austria")
parameters = JLD2.load(joinpath(dir, "parameters", "2010Q1.jld2"))
initial_conditions = JLD2.load(joinpath(dir, "initial_conditions", "2010Q1.jld2"))

# The number of banks is set through the parameter `n_banks`.
# Each firm (together with its owner) and each household is randomly assigned to one bank,
# and the aggregate equity of the banking sector is split equally among them.
parameters["n_banks"] = 3

model = Bit.Model(parameters, initial_conditions);

# Every bank is an entity with a `Bank` tag, and the clients of a bank are linked to it
# through the `BankAccount` relation. We can therefore ask for the equity of each bank
banks = Bit.bank_entities(model.world)
[Ark.get_components(model.world, b, (Bit.Equity,))[1].amount for b in banks]

# or count the firms that are customers of each bank
[
    sum(length(e) for (e,) in Ark.Query(model.world, (), with = (Bit.Firm, Bit.BankAccount => b)))
        for b in banks
]

# We run the model as usual
T = 20
Bit.run!(model, T);

# Aggregate variables are tracked as usual, while some variables are also tracked for
# each bank, i.e. `equity_per_bank`, `credit_stock_per_bank`, `credit_new_per_bank`,
# `reserves_per_bank` and `roe_per_bank`. We stack them into a matrix to plot one line per bank
equity = reduce(hcat, model.data.equity_per_bank)'
credit = reduce(hcat, model.data.credit_stock_per_bank)'
p1 = plot(equity, title = "equity", titlefont = 10, label = ["bank 1" "bank 2" "bank 3"])
p2 = plot(credit, title = "loans", titlefont = 10, legend = false)
plot(p1, p2, layout = (1, 2))
