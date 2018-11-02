using MathProgBase
using DataFrames
using OptiMimi
using Gurobi
using NaNMath

filepaths = ["currentprofits-pfixed-lybymc.csv", "all2050profits-pfixed-notime-histco-lybymc.csv", "all2070profits-pfixed-notime-histco-lybymc.csv"]

switchcost = 0 # 0 for free switching

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/single.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/datastore.jl")

crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
areacrops = [:BARLEY, :CORN, :COTTON, :RICE, :SOYBEANS, :WHEAT]

knownareas = getfilteredtable("agriculture/knownareas.csv", :fips)
# Constrain total area per county to existing
knownareas[:mytotal] = 0
areabycrop = zeros(length(crops), nrow(knownareas))
for cc in 1:length(areacrops)
    knownareas[:mytotal] += knownareas[areacrops[cc]]
    areabycrop[cc, :] = knownareas[areacrops[cc]]
end

results = DataFrame(filepath=String[], choice=String[], costs=Float64[], objective=Float64[], exclcosts=Float64[])

for switchcost in [0; collect(exp.(linspace(log(1), log(1000), 1000))); Inf]
    for filepath in filepaths
        mat = readcsv(filepath)' # Transpose to crop x county
        numcrops = size(mat)[1]
        numcounties = size(mat)[2]

        # Parameters: areas for each crop in each county, up to and above observed

        # Objectve
        ff1 = OptiMimi.vectorsingle([numcrops, numcounties], (ii, jj) -> mat[ii, jj])
        ff2 = OptiMimi.vectorsingle([numcrops, numcounties], (ii, jj) -> mat[ii, jj] - switchcost)

        # Constrain non-switching area to observed
        AA1 = OptiMimi.matrixdiagonal([numcrops, numcounties], 1.)
        AA2 = OptiMimi.matrixdiagonal([numcrops, numcounties], 0.)
        bb = vec(areabycrop) * 0.404686 # Convert to Ha
        
        # Constrain total ag area to total observed
        function areagen(subA, rr)
            subA[:] = 1
        end
        AA1 = [AA1; OptiMimi.matrixintersect([numcounties], [numcrops, numcounties], [:county], [:crop, :county], areagen)]
        AA2 = [AA2; OptiMimi.matrixintersect([numcounties], [numcrops, numcounties], [:county], [:crop, :county], areagen)]
        append!(bb, convert(Vector{Float64}, knownareas[:mytotal] * 0.404686)) # Convert to Ha

        # Constrain total area per crop to existing
        for cc in 1:length(areacrops)
            total = sum(knownareas[areacrops[cc]] * 0.404686)

            subAA1 = spzeros(numcrops, numcounties)
            subAA1[cc, :] = 1
            AA1 = [AA1; vec(subAA1)']
            subAA2 = spzeros(numcrops, numcounties)
            subAA2[cc, :] = 1
            AA2 = [AA2; vec(subAA2)']

            push!(bb, total)
        end

        uppers = convert(Vector{Float64}, repeat(knownareas[:mytotal] * 0.404686, inner=6))
        lowers = zeros(prod(size(mat)))
        
        ff1[ff1 .== Inf] = maximum(ff1[ff1 .!= Inf]*10+1e6)
        ff1[isnan.(ff1)] = 0
        ff2[ff2 .== Inf] = maximum(ff2[ff2 .!= Inf]*10+1e6)
        ff2[isnan.(ff2)] = 0

        solver = GurobiSolver()
        sol = linprog(-[ff1; ff2], [AA1 AA2], '<', bb, [lowers; lowers], [uppers; uppers], solver)

        withoutswitchcost = NaNMath.sum(sol.sol .* [ff1; ff1])

        push!(results, [filepath, "optimal", switchcost, -sol.objval, withoutswitchcost])

        if switchcost == 0
            sol0 = [OptiMimi.vectorsingle([numcrops, numcounties], (ii, jj) -> knownareas[jj, areacrops[ii]] * 0.404686); 0 * ff1]
            sol0[[ff1; ff2] .== -Inf] = 0
            baselinecrops = NaNMath.sum(sol0 .* [ff1; ff2])
            push!(results, [filepath, "observed", NaN, baselinecrops, baselinecrops])
        end

        println(results)
    end
end

writetable("constopt-byprice.csv", results)
