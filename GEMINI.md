# BeforeIT.jl

BeforeIT.jl is a high-performance, behavioural agent-based economic forecasting framework developed by the IT research unit of the Bank of Italy. It matches the forecasting performance of traditional economic tools while allowing for complex counterfactual scenario analysis.

## Project Overview

- **Core Technology:** [Julia](https://julialang.org/)
- **Architecture:** Based on an Entity-Component-System (ECS) pattern using [Ark.jl](https://github.com/bancaditalia/Ark.jl).
- **Domain:** Macroeconomics, Agent-Based Modeling (ABM), Forecasting.
- **Key Components:** Banks, Central Banks, Firms, Government, Households, Workers, Rest of World (ROTW).
- **Data Handling:** Parameters and initial conditions for different regions (e.g., Austria, Italy) are stored in `data/`. Results are typically stored in JLD2 format.

## Development Workflows

### Building and Setup

To set up the environment and install dependencies:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Running the Model

A basic example can be run via:

```bash
julia --project=. main.jl
```

Or interactively in the REPL:

```julia
import BeforeIT as Bit
model = Bit.Model(Bit.AUSTRIA2010Q1.parameters, Bit.AUSTRIA2010Q1.initial_conditions)
Bit.run!(model, 20)
```

### Testing

To run the test suite:

```bash
julia --project=. test/runtests.jl
```

Individual test files (e.g., `test/systems/banks.jl`) can also be run directly if the environment is active.

### Formatting

The project uses [Runic.jl](https://github.com/fredrikekre/Runic.jl) for code formatting. To format the package:

```bash
julia --project=. format.jl
```

## Architectural Conventions

- **Component Registry:** Components are defined in `src/components/` and registered using the `@component` macro in `src/components/components.jl`.
- **System Logic:** The logic for each time step is divided into systems located in `src/systems/`.
- **Simulation Loop:** The main simulation loop is orchestrated in `src/schedule/one_step.jl` via the `step!` function.
- **Initialization:** Model setup logic is found in `src/model_init/`.
- **Resources:** Global state or configuration shared across systems is handled via `Ark` resources, defined in `src/resources/`.
- **Utils:** Various mathematical and helper functions are located in `src/utils/`.

## Coding Style & Standards

- **Language:** Julia (v1.9+).
- **Testing:** Always add tests for new systems or component logic in the `test/` directory.
- **Naming:** Follow Julia's standard naming conventions (CamelCase for Types/Modules, snake_case for functions/variables).
- **Documentation:** Documentation is generated using `Documenter.jl` and resides in `docs/`.
