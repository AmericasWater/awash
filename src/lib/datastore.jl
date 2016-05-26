"""
Return the full path to a standard data file.
"""
function datapath(filename)
    "../data/$filename"
end

"""
Either get data from a cached source, or produce it by a fallback generation
Does not save fallback generation: for saving, use ...
"""
function cached_fallback(filename, generate)
    confighash = hash(config) # make specific to configs
    if isfile(datapath("$filename$suffix-$confighash.jld"))
        deserialize(open(datapath("$filename$suffix-$confighash.jld")))
    else
        generate()
    end
end
