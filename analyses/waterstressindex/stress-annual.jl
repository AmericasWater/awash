using DataFrames, DataArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete-yearly.yml")

using Gurobi
solver = GurobiSolver()

allowgw = false #"demandonly"
suffixbase = "annual" #"annual-alldemand"

for filtercanals in [false, true]
    for allowreservoirs in [false, true]
        if allowreservoirs
            suffix = "$suffixbase-withres"
        else
            suffix = "$suffixbase-nores"
        end

        config["proportionnaturalflowforenvironment"] = .37

        if filtercanals
            config["filtercanals"] = "direct"
            suffix *= "-nocanal"
        else
            config["filtercanals"] = nothing
        end

        if isfile("stress-$suffix.csv")
            continue
        end
        println(suffix)

        rm("../../data/counties/extraction/withdrawals.jld", force=true)
        include("../../src/optimization-given.jl")

        house = optimization_given(allowgw, allowreservoirs, nocache=true)
        sol = houseoptimize(house, solver)
        supersource0 = getparametersolution(house, sol.sol, :quarterwaterfromsupersource) + getparametersolution(house, sol.sol, :waterfromsupersource)

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
            supersource = getparametersolution(house, sol.sol, :waterfromsupersource)
            minefp[(supersource .> 0) .& (minefp .== 0)] = efp

            df = DataFrame(fips=repeat(masterregions[:fips], outer=numsteps), time=repeat(1:61, inner=numregions), supersource=supersource0, minefp=minefp)
            writetable("stress-$suffix.csv", df)
        end

        minefp[(minefp .== 0)] = 100.

        df = DataFrame(fips=repeat(masterregions[:fips], outer=numsteps), time=repeat(1:61, inner=numregions), supersource=supersource0, minefp=minefp)
        writetable("stress-$suffix.csv", df)
    end
end
