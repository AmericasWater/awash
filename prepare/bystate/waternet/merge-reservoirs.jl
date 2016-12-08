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

outlets = Dict{UTF8String, Vector{Int64}}()
for ii in 1:nrow(allreservoirs)
    label = "$(allreservoirs[ii, :collection]).$(allreservoirs[ii, :colid])"
    println("$ii: $label ($(length(keys(outlets))))")
    found = findnode(label)
    if found != nothing
        if !in(found, keys(outlets))
            outlets[found] = Int64[]
        end
        push!(outlets[found], ii)
    end
end

network = load(datapath("waternet.RData"))["network"];
network[:label] = map(ii -> "$(network[ii, :collection]).$(network[ii, :colid])", 1:nrow(network))

states = readtable(datapath("global/states.csv"))

result = DataFrame(collection=UTF8String[], colid=UTF8String[], area=Float64[],
                   lat=Float64[], lon=Float64[], elev=Float64[], MAXCAP=Float64[], ST=UTF8String[])
for label in keys(outlets)
    colcolid = split(label, ".")
    networkrow = network[:label] .== label

    # Find state most common
    allstatefips = map(fips -> string(div(fips, 1000)), allreservoirs[outlets[label], :fips])
    countstatefips = countmap(allstatefips)
    maxval, maxkey = findmax(countstatefips)
    statefips = parse(Int, maxval[1])
    
    push!(result, [colcolid; sum(allreservoirs[outlets[label], :area]);
                   network[networkrow, :lat]; network[networkrow, :lon];
                   NA; sum(allreservoirs[outlets[label], :MAXCAP]);
                   states[states[:fips] .== statefips, :state]])
end

writetable(datapath("states/reservoirs/allreservoirs.csv"), result)
