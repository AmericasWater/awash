"""
Returns a value for every region
If a value is given for the region, use that; otherwise use US averages
"""
function ers_information(crop::AbstractString, item::AbstractString, year::Int64; includeus=true)
    df = readtable(datapath("global/ers.csv"))

    reglink = readtable(datapath("agriculture/ers/reglink.csv"))
    fips = canonicalindex(reglink[:FIPS])
    indexes = getregionindices(fips)

    if (item == "cost")
        allcosts = ers_information_loaded(crop, "Total, costs listed", year, df, indexes, reglink[:ABBR]; includeus=includeus)
        unpaid = ers_information_loaded(crop, "Opportunity cost of unpaid labor", year, df, indexes, reglink[:ABBR]; includeus=includeus)
        opportunity = ers_information_loaded(crop, "Opportunity cost of land", year, df, indexes, reglink[:ABBR]; includeus=includeus)
        allcosts - unpaid - opportunity
    elseif (item == "yield")
        ers_information_loaded(crop, "Yield (bushels per planted acre)", year, df, indexes, reglink[:ABBR]; includeus=includeus)
    elseif (item == "price")
        # Report total price, across all products, not the line below
        #ers_information_loaded(crop, "Price (dollars per bushel at harvest)", year, df, indexes, reglink[:ABBR])
        revenue = ers_information_loaded(crop, "Total, gross value of production", year, df, indexes, reglink[:ABBR]; includeus=includeus)
        yield = ers_information_loaded(crop, "Yield (bushels per planted acre)", year, df, indexes, reglink[:ABBR]; includeus=includeus)
        revenue ./ yield
    elseif (item == "revenue")
        ers_information_loaded(crop, "Total, gross value of production", year, df, indexes, reglink[:ABBR]; includeus=includeus)
    else
        ers_information_loaded(crop, item, year, df, indexes, reglink[:ABBR]; includeus=includeus)
    end
end

function ers_information_loaded(crop::AbstractString, item::AbstractString, year::Int64, df::DataFrame, reglink_indexes, reglink_abbr; includeus=true)
    subdf = df[(df[:crop] .== crop) & (df[:item] .== item) & (df[:year] .== year), :]

    result = zeros(size(masterregions, 1)) * NA
    for (region in unique(reglink_abbr))
        value = subdf[subdf[:region] .== region, :value]
        if (length(value) == 0)
            continue
        end
        result[reglink_indexes[(reglink_abbr .== region) & (reglink_indexes .> 0)]] = value[1]
    end

    if includeus
        value = subdf[subdf[:region] .== "us", :value]
        result[isna(result)] = value[1]
    end

    result
end

"""
List all available ERS information items.
"""
function ers_information_list(crop::AbstractString)
    df = readtable(datapath("global/ers.csv"))
    ["cost"; "yield"; "price"; "revenue"; unique(df[df[:crop] .== crop, :item])]
end

