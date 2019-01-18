waternetdata = load(datapath("waternet/waternet.RData"));
netdata = waternetdata["network"];

drawsdata = load(datapath("waternet/countydraws.RData"));
draws = drawsdata["draws"];
draws[:source] = round.(Int64, draws[:source]);

# Label all with the node name
draws[:gaugeid] = ""
for ii in 1:nrow(draws)
    row = draws[ii, :source]
    draws[ii, :gaugeid] = "$(netdata[row, :collection]).$(netdata[row, :colid])"
end

function getregion(label)
    regions = round.(Int64, floor(draws[(draws[:gaugeid] .== label) .& (draws[:justif] .== "contains"), :fips] / 1000))
    if length(regions) == 1
        regions[1] < 10 ? "0$(regions[1])" : "$(regions[1])"
    elseif length(regions) == 0
        "missing"
    else
        "multiple"
    end
end
