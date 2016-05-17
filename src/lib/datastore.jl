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
    if isfile(datapath("$filename$suffix.jld"))
        deserialize(open(datapath("$filename$suffix.jld")))
    else
        generate()
    end
end
