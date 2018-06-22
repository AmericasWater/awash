using MathProgBase
using DataFrames
using OptiMimi
using Gurobi

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
for crop in areacrops
    knownareas[:mytotal] += knownareas[crop]
end

if switchcost > 0
    baseline = readcsv("actualcrops.csv")
    baselinerow = zeros(nrow(knownareas))
    for ii in 1:nrow(knownareas)
        baselinerow[ii] = findfirst(knownareas[ii, :fips] .== baseline[:fips])
    end
end

results = DataFrame(filepath=String[], costs=Float64[], objective=Float64[])

for switchcost in [0; collect(exp.(linspace(log(1), log(1000), 10)))]
    for filepath in filepaths
        mat = readcsv(filepath)' # Transpose to crop x county

        # Parameters: areas for each crop in each county

        # Objectve
        if switchcost > 0
            ff = OptiMimi.vectorsingle([size(mat)[1], size(mat)[2]], (ii, jj) -> mat[ii, jj] - switchcost * (baseline[baselinerow[jj], :maxcrop] != String(areacrops[ii])))
        else
            ff = OptiMimi.vectorsingle([size(mat)[1], size(mat)[2]], (ii, jj) -> mat[ii, jj])
        end

        function areagen(subA, rr)
            subA[:] = 1
        end
        AA = OptiMimi.matrixintersect([size(mat)[2]], [size(mat)[1], size(mat)[2]], [:county], [:crop, :county], areagen)
        bb = convert(Vector{Float64}, knownareas[:mytotal] * 0.404686) # Convert to Ha

        # Constrain total area per crop to existing
        for cc in 1:length(areacrops)
            total = sum(knownareas[areacrops[cc]] * 0.404686)
            subAA = spzeros(size(mat)[1], size(mat)[2])
            subAA[cc, :] = 1
            AA = [AA; vec(subAA)']
            push!(bb, total)
        end

        uppers = convert(Vector{Float64}, repeat(knownareas[:mytotal] * 0.404686, inner=6))
        lowers = zeros(prod(size(mat)))
        
        ff[ff .== Inf] = maximum(ff[ff .!= Inf]*10+1e6)
        ff[isnan.(ff)] = 0

        solver = GurobiSolver()
        sol = linprog(-ff, AA, '<', bb, lowers, uppers, solver)

        push!(results, [filepath, switchcost, -sol.objval])
        println(results)
    end
end

writetable("constopt-byprice.csv", results)
