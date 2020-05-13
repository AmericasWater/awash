using DataFrames, CSV

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete-yearly.yml")

using Gurobi
solver = GurobiSolver()

scenarios = ["-nores-nocanal", "-nores", "-withres"]

for allowgw in [false, "demandonly"]
    if allowgw == "demandonly"
        suffixbase = "annual-alldemand"
    else
        suffixbase = "annual"
    end

    for scenario in scenarios
        filtercanals = occursin("nores", scenario)
        allowreservoirs = occursin("withres", scenario)

        suffix = "$suffixbase$scenario"

        config["proportionnaturalflowforenvironment"] = .37

        if filtercanals
            config["filtercanals"] = "direct"
        else
            config["filtercanals"] = nothing
        end

        if isfile("stress-$suffix.csv")
            continue
        end
        println(suffix)

        rm("../../data/cache/counties/extraction/withdrawals.jld", force=true)
        include("../../src/optimization-given.jl")

        house = optimization_given(allowgw, allowreservoirs, nocache=true)
        sol = houseoptimize(house, solver)
        supersource0 = getparametersolution(house, sol.sol, :quartersupersourcesupply) + getparametersolution(house, sol.sol, :supersourcesupply)

        # Calculate remaining flow in rivers-- not used because bad display
        # runoff = constraintoffset_waternetwork_outflows(house.model).f
        # modifies = getconstraintsolution(house, sol, :outflows)
        # remaining = runoff - modifies

        offset0 = constraintoffset_waternetwork_outflows(house.model)
        config["proportionnaturalflowforenvironment"] = 1.0
        envflow1 = constraintoffset_environmentalflows(house.model)

        minefp = 37. * (supersource0 .> 0)

        for efp in 37:5:100
            if efp == 37
                continue
            end
            println(efp)
            setconstraintoffset!(house, offset0 - LinearProgrammingHall(envflow1.component, envflow1.name, (efp / 100.) * envflow1.f))
            sol = houseoptimize(house, solver)
            supersource = getparametersolution(house, sol.sol, :supersourcesupply)
            minefp[(supersource .> 0) .& (minefp .== 0)] .= efp

            df = DataFrame(fips=repeat(masterregions[:fips], outer=numsteps), time=repeat(1:61, inner=numregions), supersource=supersource0, minefp=minefp)
            CSV.write("stress-$suffix.csv", df)
        end

        minefp[(minefp .== 0)] .= 100.

        df = DataFrame(fips=repeat(masterregions[:fips], outer=numsteps), time=repeat(1:61, inner=numregions), supersource=supersource0, minefp=minefp)
        CSV.write("stress-$suffix.csv", df)
    end
end
