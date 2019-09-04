## Graphing library
#
# Includes either graphing library, with `graphing-rcall.jl`
# preferred.

if ("RCall" in keys(versions))
    include("graphing-rcall.jl")
else
    if !("Shapefile" in keys(versions))
        Pkg.add("Shapefile")
    end

    if !("Gadfly" in keys(versions))
        Pkg.add("Gadfly")
    end

    include("graphing-native.jl")
end

"""
Produce a choropleth map of an DataFrame.

# Arguments:
* `df`: Dataframe with a `fips` column and a `value` column.
* `centered::Bollean`: Should the colors diverge from a common center value?  Not implemented for graphing-native.
"""
usmap

