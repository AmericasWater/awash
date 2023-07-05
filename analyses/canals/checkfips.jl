using CSV

include("../../src/nui.jl")

# Perform surface optimization
prepoptimizesurface("complete-5year.yml")
sol = runmodel()

# Extract all withdrawals
varlens = varlengths(model.model, model.paramcomps, model.parameters, Dict(:quartersupersourcesupply => :supersourcesupply))
withdrawals = reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numsteps)

varlens = varlengths(model.model, model.constcomps, model.constraints, Dict(:storagemin => :storage, :storagemax => :storage))
outflows = reshape(getconstraintsolution(model, sol, :outflows), numgauges, numsteps)

# Determine FIPS of each node
waternetdata = load(loadpath("waternet/waternet.RData"));
netdata = waternetdata["network"];
netdata[:fips] = 0
for ii in find(draws[:justif] .== "contains")
    netdata[draws[ii, :source], :fips] = draws[ii, :fips]
end
netdata[:fullid] = ["$(netdata[ii, :collection]).$(netdata[ii, :colid])" for ii in 1:nrow(netdata)]

# Translate FIPS to draws
draws[:fromfips] = netdata[draws[:source], :fips];

# Identify which flows are through canals
canaldraw = [findfirst(["missingcanal", "canal-within", "canal-nhd"], justif) for justif in draws[:justif]] .> 0
bycanals = canaldraw .& (draws[:fips] .!= draws[:fromfips])

# Get other information
recorded = knowndf("exogenous-withdrawals")
masterregions = CSV.read(datapath(config["masterregions"]), types=[String, String, String])
netattrs = CSV.read(datapath("waternet/network-attributes.csv"), types=[String, String, String, String, String, Float64])
netattrs[:fullid] = ["$(netattrs[ii, :collection]).$(netattrs[ii, :colid])" for ii in 1:nrow(netattrs)]

function findfips(name)
    county, state = tuple(split(name, ", ")...)
    iis = find((masterregions[:name] .== county) .& (masterregions[:state] .== state))
    if length(iis) == 1
        return masterregions[iis[1], :fips]
    end
end

function checkfips(fips)
    ii = getregionindices([fips])[1]

    # Get annual demand
    demand = recorded[ii, :TO_SW] # MGal/day

    # Get all canals
    thisdraws = draws[draws[:fips] .== fips, :]

    # Describe flows
    canalsources = Dict{String, Float64}()
    localsources = Dict{String, Float64}()
    for jj in find(draws[:fips] .== fips)
        drawtotal = sum(withdrawals[jj, :]) / 5
        portion = drawtotal / (demand * 1383.)

        nodeid = "$(netdata[draws[jj, :source], :collection]).$(netdata[draws[jj, :source], :colid])"
        aa = findfirst(netattrs[:fullid], nodeid)
        if aa > 0
            sourcename = netattrs[aa, :name10]
        else
            sourcename = nodeid
        end

        fromii = getregionindices([draws[jj, :fromfips]])[1]
        countyname = "$(masterregions[fromii, :name]), $(masterregions[fromii, :state])"

        if fromii == ii
            descript = "$sourcename ($(draws[jj, :justif]))"
        else
            descript = "$sourcename ($countyname, $(draws[jj, :justif]))"
        end
        if bycanals[jj]
            sourcedict = canalsources
        else
            sourcedict = localsources
        end
        sourcedict[descript] = get(sourcedict, descript, 0) + portion
    end

    # Get sink and source flows
    flow_sink = (sum(withdrawals[bycanals .& (draws[:fips] .== fips), :]) / 5) / 1383
    flow_source = (sum(withdrawals[bycanals .& (draws[:fromfips] .== fips), :]) / 5) / 1383

    # Look at most downstream for each gauge
    netincs = netdata[:fips] .== fips
    for jj in find(netincs)
        if netincs[netdata[jj, :nextpt]]
            netincs[jj] = false
        end
    end

    gaugeiis = [findfirst(netdata[netincs, :fullid], gaugeid) > 0 for gaugeid in gaugeorder]

    flow_localremaining = (sum(maximum(outflows[gaugeiis, :], 1)) / 5) / 1383

    return demand, canalsources, localsources, flow_sink, flow_source, flow_localremaining
end

results = DataFrame(location=String[], fips=String[], demand=String[], localsources=String[], canalsources=String[], xfer_sink=String[], xfer_source=String[], flow_localremaining=String[])
for fips in [26081, 4019, 8031]
    demand, canalsources, localsources, flow_sink, flow_source, flow_localremaining = checkfips(fips)
    if length(canalsources) == 0
        canalstr = ["None"]
    else
        canalstr = ["$key: $(round(canalsources[key], 2) * 100)%" for key in keys(canalsources)]
    end
    if length(localsources) == 0
        localstr = ["None"]
    else
        localstr = ["$key: $(round(localsources[key], 2) * 100)%" for key in keys(localsources)]
    end

    jj = findfirst(fips .== parse.(Int64, masterregions[:fips]))
    location = "$(masterregions[jj, :name]), $(masterregions[jj, :state])"

    push!(results, [location, "$fips", "$demand", localstr[1], canalstr[1], "$flow_sink", "$flow_source", "$flow_localremaining"])
    if length(localstr) > 1 || length(canalstr) > 1
        for ii in 2:max(length(localstr), length(canalstr))
            if ii <= length(localstr)
                localstrii = localstr[ii]
            else
                localstrii = ""
            end
            if ii <= length(canalstr)
                canalstrii = canalstr[ii]
            else
                canalstrii = ""
            end

            push!(results, ["", "", "", localstrii, canalstrii, "", "", ""])
        end
    end
end

CSV.write("canalinfo.csv", results, colnames=["Location", "FIPS", "SW Demand (MGal/day)", "Local Sources", "Canal Sources", "Canal Imports (MG/d)", "Canal Exports (MG/d)", "Remaining Local Flow (MG/d)"])
