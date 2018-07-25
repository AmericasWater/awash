using DataFrames, DataArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

using Gurobi
solver = GurobiSolver()

suffixbase = "monthly"
burnyears = 2
saveyears = 5

for filtercanals in [false, true]
    for allowreservoirs in [false, true]
        if allowreservoirs
            suffix = "$suffixbase-withres"
        else
            suffix = "$suffixbase-nores"
        end

        if filtercanals
            config["filtercanals"] = "direct"
            suffix *= "-nocanal"
        else
            config["filtercanals"] = nothing
        end

        println(suffix)
        if isfile("stress-$suffix.csv")
            finaldf = readtable("stress-$suffix.csv")
            startyear0 = maximum(finaldf[:startyear]) - burnyears + saveyears
            if startyear0 >= 2005
                continue
            end
        else
            finaldf = DataFrame(startyear=Int64[], fips=String[], time=Int64[], supersource=Float64[], minefp=Float64[])
            startyear0 = 1949
        end

        for startyear in startyear0:saveyears:(2010 - burnyears - saveyears)
            config["proportionnaturalflowforenvironment"] = .37
            config["startmonth"] = "10/$startyear"
            config["endmonth"] = "9/$(startyear + burnyears + saveyears)"
            config["startweather"] = 12 * (startyear - 1949) + 1

            rm("../../data/counties/extraction/withdrawals.jld", force=true)
            include("../../src/optimization-given.jl")

            house = optimization_given(false, allowreservoirs, nocache=true)
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
                println("$startyear: $efp")
                setconstraintoffset!(house, offset0 - LinearProgrammingHall(envflow1.component, envflow1.name, (efp / 100.) * envflow1.f))
                sol = houseoptimize(house, solver)
                supersource = getparametersolution(house, sol.sol, :waterfromsupersource)
                minefp[(supersource .> 0) .& (minefp .== 0)] = efp

                df = vcat(finaldf, DataFrame(startyear=(startyear + burnyears) * ones(Int64, numregions * saveyears * 12), fips=repeat(masterregions[:fips], outer=saveyears * 12), time=repeat(1:(saveyears * 12), inner=numregions), supersource=supersource0[(numregions * burnyears * 12 + 1):end], minefp=minefp[(numregions * burnyears * 12 + 1):end]))
                writetable("stress-$suffix.csv", df)
            end

            minefp[(minefp .== 0)] = 100.

            finaldf = vcat(finaldf, DataFrame(startyear=(startyear + burnyears) * ones(Int64, numregions * saveyears * 12), fips=repeat(masterregions[:fips], outer=saveyears * 12), time=repeat(1:(saveyears * 12), inner=numregions), supersource=supersource0[(numregions * burnyears * 12 + 1):end], minefp=minefp[(numregions * burnyears * 12 + 1):end]))
            writetable("stress-$suffix.csv", finaldf)
        end
    end
end
