using MathProgBase
using DataFrames
using OptiMimi
using Gurobi

filepath = "futureprofits.csv" #"currentprofits.csv"

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/single.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/datastore.jl")

crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]

mat = readcsv(filepath)' # Transpose to crop x county

# Parameters: areas for each crop in each county

# Objectve
f = OptiMimi.vectorsingle([size(mat)[1], size(mat)[2]], (ii, jj) -> mat[ii, jj])

# Constrain total area per county to existing
knownareas = getfilteredtable("agriculture/knownareas.csv", :fips)

function areagen(subA, rr)
    subA[:] = 1
end
AA = OptiMimi.matrixintersect([size(mat)[2]], [size(mat)[1], size(mat)[2]], [:county], [:crop, :county], areagen)
bb = convert(Vector{Float64}, knownareas[:known] * 0.404686) # Convert to Ha

# Constrain total area per crop to existing
df = getfilteredtable("agriculture/totalareas.csv")
areacrops = [:barley, :corn, :cotton, :rice, :soybeans, :wheat]
for cc in 1:length(areacrops)
    if areacrops[cc] == :cotton
        total = 77e6 * 0.404686
    elseif areacrops[cc] == :rice
        total = 3.1e6 * 0.404686
    else
        total = sum(df[:, areacrops[cc]] * 0.404686)
    end
    subAA = spzeros(size(mat)[1], size(mat)[2])
    subAA[cc, :] = 1
    AA = [AA; vec(subAA)']
    push!(bb, total)
end

uppers = convert(Vector{Float64}, repeat(knownareas[:known] * 0.404686, inner=6))
lowers = zeros(prod(size(mat)))

f[f .== Inf] = maximum(f[f .!= Inf]*10+1e6)
f[isnan(f)] = 0

solver = GurobiSolver()
sol = linprog(-f, AA, '<', bb, lowers, uppers, solver)

optareas = reshape(sol.sol, size(mat))
topareas = [ifelse(sum(optareas[:, ii]) > 0, crops[findfirst(optareas[:, ii] .== maximum(optareas[:, ii]))], "NA") for ii in 1:size(mat)[2]]

df = DataFrame(fips=masterregions[:fips], topcrop=topareas)
for cc in 1:length(crops)
    df[Symbol(crops[cc])] = optareas[cc, :]
end

writetable("constopt-$filepath", df)
