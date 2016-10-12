if Pkg.installed("RCall") != nothing
    include("graphing-rcall.jl")
    
else
    if Pkg.installed("Shapefile") == nothing
        Pkg.add("Shapefile")
    end

    if Pkg.installed("Gadfly") == nothing
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
