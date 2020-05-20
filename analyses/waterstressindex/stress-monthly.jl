using DataFrames, CSV

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

using Gurobi
solver = GurobiSolver()

burnyears = 2
saveyears = 2

scenarios = ["-nores-nocanal", "-nores", "-withres"]

for allowgw in [false, "demandonly"]
    if allowgw == "demandonly"
        suffixbase = "monthly-alldemand"
    else
        suffixbase = "monthly"
    end

    for scenario in scenarios
        filtercanals = occursin("nores", scenario)
        allowreservoirs = occursin("withres", scenario)

        suffix = "$suffixbase$scenario"

        if filtercanals
            config["filtercanals"] = "direct"
        else
            config["filtercanals"] = nothing
        end

        println(suffix)
        if isfile("stress-$suffix.csv")
            finaldf = CSV.read("stress-$suffix.csv")
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
                println("$startyear: $efp")
                setconstraintoffset!(house, offset0 - LinearProgrammingHall(envflow1.component, envflow1.name, (efp / 100.) * envflow1.f))
                sol = houseoptimize(house, solver)
                supersource = getparametersolution(house, sol.sol, :supersourcesupply)
                minefp[(supersource .> 0) .& (minefp .== 0)] .= efp

                df = vcat(finaldf, DataFrame(startyear=(startyear + burnyears) * ones(Int64, numregions * saveyears * 12), fips=repeat(masterregions[:fips], outer=saveyears * 12), time=repeat(1:(saveyears * 12), inner=numregions), supersource=supersource0[(numregions * burnyears * 12 + 1):end], minefp=minefp[(numregions * burnyears * 12 + 1):end]))
                CSV.write("stress-$suffix.csv", df)
            end

            minefp[(minefp .== 0)] .= 100.

            finaldf = vcat(finaldf, DataFrame(startyear=(startyear + burnyears) * ones(Int64, numregions * saveyears * 12), fips=repeat(masterregions[:fips], outer=saveyears * 12), time=repeat(1:(saveyears * 12), inner=numregions), supersource=supersource0[(numregions * burnyears * 12 + 1):end], minefp=minefp[(numregions * burnyears * 12 + 1):end]))
            CSV.write("stress-$suffix.csv", finaldf)
        end
    end
end
