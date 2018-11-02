include("lib/datastore.jl")
include("lib/annotated.jl")

function singlecropping()
    ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]
end

function doublecropping()
    combos = Vector{Tuple{ASCIIString, ASCIIString}}()
    for crop in singlecropping()
        push!(combos, (crop, ""))
    end

    for line in eachnoncomment(datapath("agriculture/combos.txt"))
        push!(combos, tuple(map(ASCIIString, split(strip(line), '-'))...))
    end

    combos
end
