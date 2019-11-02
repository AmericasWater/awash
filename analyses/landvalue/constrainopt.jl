using MathProgBase
using DataFrames
using OptiMimi
using Gurobi
using CSV, DelimitedFiles
using SparseArrays

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/single.yml")

include("../../src/world-minimal.jl")
include("../../src/lib/datastore.jl")

resdir = "results-mc" # "results"
crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]

shadows = DataFrame(fips=[masterregions[:fips]; crops])

for filename in readdir(resdir)
    if !occursin("profits", filename) || filename[end-3:end] != ".csv" || occursin("constopt", filename)
        continue
    end
    println(filename)

filepath = resdir * "/$filename"

mat = readdlm(filepath, ',')' # Transpose to crop x county

# Parameters: areas for each crop in each county

# Objectve
f = OptiMimi.vectorsingle([size(mat)[1], size(mat)[2]], (ii, jj) -> mat[ii, jj])

# Constrain total area per county to existing
knownareas = getfilteredtable("agriculture/knownareas.csv", :fips)
areacrops = [:BARLEY, :CORN, :COTTON, :RICE, :SOYBEANS, :WHEAT]
mytotal = zeros(nrow(knownareas))
for crop in areacrops
    mytotal += knownareas[!, crop]
end

function areagen(subA, rr)
    subA[:] .= 1
end
AA = OptiMimi.matrixintersect([size(mat)[2]], [size(mat)[1], size(mat)[2]], [:county], [:crop, :county], areagen)
bb = convert(Vector{Float64}, mytotal * 0.404686) # Convert to Ha

# Constrain total area per crop to existing
for cc in 1:length(areacrops)
    total = sum(knownareas[!, areacrops[cc]] * 0.404686)
    subAA = spzeros(size(mat)[1], size(mat)[2])
    subAA[cc, :] .= 1
    AA = [AA; vec(subAA)']
    push!(bb, total)
end

uppers = convert(Vector{Float64}, repeat(mytotal * 0.404686, inner=6))
lowers = zeros(prod(size(mat)))

f[f .== Inf] .= maximum(f[f .!= Inf]*10 .+ 1e6)
f[isnan.(f)] .= 0

solver = GurobiSolver()
sol = linprog(-f, AA, '<', bb, lowers, uppers, solver)

optareas = reshape(sol.sol, size(mat))
topareas = [ifelse(sum(optareas[:, ii]) > 0, crops[findfirst(optareas[:, ii] .== maximum(optareas[:, ii]))], "NA") for ii in 1:size(mat)[2]]

df = DataFrame(fips=masterregions[:fips], topcrop=topareas)
for cc in 1:length(crops)
    df[Symbol(crops[cc])] = optareas[cc, :]
end

    CSV.write(resdir * "/constopt-$filename", df)
    shadows[Symbol(filename[1:end-4])] = sol.attrs[:lambda]
end

CSV.write("results/shadows.csv", shadows)
