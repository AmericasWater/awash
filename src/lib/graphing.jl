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
