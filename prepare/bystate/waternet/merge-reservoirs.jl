using DataFrames

include("../../../src/lib/readconfig.jl")
suffix = ""
config = emptyconfig()

include("../../../src/lib/datastore.jl")
include("../../../src/lib/reservoirs.jl")
include("../../../src/waternet.jl")

result = readtable("newnetwork.csv")
allreservoirs = readtable(datapath("reservoirs/allreservoirs.csv"))

function findnode(nodename)
    if in(nodename, result[:node])
        return nodename
    elseif in(nodename, result[:outnode])
        return nodename
    end

    # Find the next node downstream
    foundvertex = nothing
    for vertex in downstreamorder
        upstreams = out_neighbors(vertex, waternet)
        if in(nodename, map(upstream -> upstream.label, upstreams))
            foundvertex = vertex
            break
        end
    end

    if foundvertex == nothing
        return nothing
    end

    return findnode(foundvertex.label)
end

outlets = Dict{UTF8String, Vector{UTF8String}}()
for ii in 1:nrow(allreservoirs)
    label = "$(allreservoirs[ii, :collection]).$(allreservoirs[ii, :colid])"
    println("$ii: $label ($(length(keys(outlets))))")
    found = findnode(label)
    if found != nothing
        if !in(found, keys(outlets))
            outlets[found] = UTF8String[]
        end
        push!(outlets[found], label)
    end
end

println(outlets)
