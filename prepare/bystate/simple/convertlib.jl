using DataFrames
using DataArrays

function translateregion(region, subdf, columns, todrop, renames, translate)
    # Add on each column
    for name in names(subdf)
        value = translate(name, subdf[name])
        if !ismissing(value) && value == nothing
            push!(todrop, name)
        elseif value == :targetid
            if !in(name, keys(columns))
                columns[name] = DataVector{Symbol}([])
            end
            push!(columns[name], region)
            renames[name] = :targetid
        else
            if !in(name, keys(columns))
                if ismissing(value)
                    columns[name] = DataVector{Float64}([])
                else
                    columns[name] = DataVector{typeof(value)}([])
                end
            end
            push!(columns[name], value)
        end
    end
end

todata = "../../.."

"""
Convert a table by passing each super-region's values for each column to `translate`

Arguments:
    - filename: table to convert (not including dataset directory)
    - config: configuration dictionary (see below)
    - translate; translation function
    - eltypes: optional array of types for each column

Configuration parameters (all symbols of the `config` dictionary):
- `source`: dataset of source files (e.g., counties)
- `target`: dataset of target files (e.g., states)
- `sourceid`: The source ID column in the source file
- `forcematching`: should the number of rows match the master file?  true/false
- `mastersourceid`: The source ID column in the master file
"""
function converttable(filename, config, translate; eltypes=nothing)
    println("Reading data...")

    masterregions = readtable(joinpath(todata, config[:masterfile]),
                              eltypes=[String, String, String])

    # Check that we have all regions
    if eltypes != nothing
        df = readtable(joinpath(todata, "data", config[:source], filename), eltypes=eltypes)
    else
        df = readtable(joinpath(todata, "data", config[:source], filename))
    end

    if nrow(df) != nrow(masterregions)
        if config[:forcematching]
            error("Rows don't match: $(nrow(df)) <> $(nrow(masterregions))")
        else
            warn("Rows don't match: $(nrow(df)) <> $(nrow(masterregions))")
        end
    end

    # Prepare the destination
    mkpath(joinpath(todata, "data", config[:target], dirname(filename)))

    # Construct the result, one region at a time
    columns = Dict{Symbol, Any}()
    todrop = Set{Symbol}()
    renames = Dict{Symbol, Symbol}()
    for region in unique(masterregions[config[:mastertargetid]])
        println("  $region")
        # Collect all the regions
        subregions = masterregions[masterregions[config[:mastertargetid]] .== region, config[:mastersourceid]]
        subregions = map(id -> parse(Int64, id), subregions)
        subdf = df[convert(Vector{Bool}, map(subreg -> in(subreg, subregions), df[config[:sourceid]])), :]

        translateregion(region, subdf, columns, todrop, renames, translate)
    end

    result = DataFrame()
    result[config[:targetid]] = unique(masterregions[config[:mastertargetid]])
    for name in filter(name -> !in(name, todrop), names(df))
        if name in keys(renames)
            toname = renames[name]
            if toname == :targetid
                toname = config[:mastertargetid]
            end
        else
            toname = name
        end

        result[toname] = columns[name]
    end

    writetable(joinpath(todata, "data", config[:target], filename), result)
end

"""
Configuration parameters (all symbols of the `config` dictionary):
- `source`: dataset of source files (e.g., counties)
- `target`: dataset of target files (e.g., states)
- `mastersourcefile`: master file with all source regions
- `mastertargetfile`: master file with all target regions
- `mastersourceid`: column in source master file with target region ids
- `mastertargetid`: column in target master file with target region ids
"""
function orderedconverttable(filename, config, translate)
    println("Reading data...")
    df = readtable(joinpath(todata, "data", config[:source], filename), header=get(config, :header, true))

    result = orderedconvertdf(df, config, translate)

    # Prepare the destination
    mkpath(joinpath(todata, "data", config[:target], dirname(filename)))

    writetable(joinpath(todata, "data", config[:target], filename), result, header=get(config, :header, true))
end

function orderedconvertdf(df, config, translate)
    sourceregions = readtable(joinpath(todata, config[:mastersourcefile]),
                              eltypes=[String, String, String])
    targetregions = readtable(joinpath(todata, config[:mastertargetfile]),
                              eltypes=[String, String, String])

    # Check that we have all regions
    if nrow(df) != nrow(sourceregions)
        error("Rows don't match: $(nrow(df)) <> $(nrow(sourceregions))")
    end

    # Construct the result, one region at a time
    columns = Dict{Symbol, Any}()
    todrop = Set{Symbol}()
    renames = Dict{Symbol, Symbol}()
    for region in targetregions[config[:mastertargetid]]
        println("  $region")
        # Collect all the regions
        subdf = df[sourceregions[config[:mastersourceid]] .== region, :]

        translateregion(region, subdf, columns, todrop, renames, translate)
    end

    result = DataFrame()
    for name in filter(name -> !in(name, todrop), names(df))
        if name in keys(renames)
            toname = renames[name]
            if toname == :targetid
                toname = config[:mastertargetid]
            end
        else
            toname = name
        end

        result[toname] = columns[name]
    end

    result
end

"""
Configuration-based direct copy
"""
function mirrorfile(filename, config)
    src = joinpath(todata, "data", config[:source], filename)
    dst = joinpath(todata, "data", config[:target], filename)

    mkpath(dirname(dst))

    cp(src, dst, remove_destination=true)
end

"""
Convert a table by passing each super-region sub-table to translate

Configuration parameters (all symbols of the `config` dictionary):
- `source`: dataset of source files (e.g., counties)
- `target`: dataset of target files (e.g., states)
- `sourceid`: The source ID column in the source file
- `mastersourceid`: The source ID column in the master file
"""
function chunkyconverttable(filename, config, translatechunk)
    println("Reading data...")

    masterregions = readtable(joinpath(todata, config[:masterfile]),
                              eltypes=[String, String, String])

    # Check that we have all regions
    df = readtable(joinpath(todata, "data", config[:source], filename))

    # Prepare the destination
    mkpath(joinpath(todata, "data", config[:target], dirname(filename)))

    # Construct the result, one region at a time
    result = nothing
    for region in unique(masterregions[config[:mastertargetid]])
        println("  $region")
        # Collect all the regions
        subregions = masterregions[masterregions[config[:mastertargetid]] .== region, config[:mastersourceid]]
        subregions = map(id -> parse(Int64, id), subregions)
        subdf = df[convert(Vector{Bool}, map(subreg -> in(subreg, subregions), df[config[:sourceid]])), :]

        subresult = translatechunk(subdf)
        subresult[config[:targetid]] = region

        if result == nothing
            result = subresult
        else
            append!(result, subresult)
        end
    end

    writetable(joinpath(todata, "data", config[:target], filename), result)
end

"""
Configuration parameters (all symbols of the `config` dictionary):
- `source`: dataset of source files (e.g., counties)
- `target`: dataset of target files (e.g., states)
- `mastersourcefile`: master file with all source regions
- `mastertargetfile`: master file with all target regions
- `mastersourceid`: column in source master file with target region ids
- `mastertargetid`: column in target master file with target region ids
- `separator`: character separating columns
"""
function chunkyorderedconverttable(filename, config, translatechunk)
    println("Reading data...")
    df = readtable(joinpath(todata, "data", config[:source], filename), header=get(config, :header, true), separator=get(config, :separator, '\t'))

    result = chunkyorderedconvertdf(df, config, translatechunk)
    result = convert(DataFrame, convert(Array{Float64, 2}, result))

    # Prepare the destination
    mkpath(joinpath(todata, "data", config[:target], dirname(filename)))

    writetable(joinpath(todata, "data", config[:target], filename), result, header=get(config, :header, true), separator=get(config, :separator, '\t'))
end

function chunkyorderedconvertdf(df, config, translatechunk)
    sourceregions = readtable(joinpath(todata, config[:mastersourcefile]),
                              eltypes=[String, String, String])
    targetregions = readtable(joinpath(todata, config[:mastertargetfile]),
                              eltypes=[String, String, String])

    # Check that we have all regions
    if nrow(df) != nrow(sourceregions)
        error("Rows don't match: $(nrow(df)) <> $(nrow(sourceregions))")
    end

    # Construct the result, one region at a time
    result = nothing
    for region in targetregions[config[:mastertargetid]]
        println("  $region")
        # Collect all the regions
        subdf = df[sourceregions[config[:mastersourceid]] .== region, :]

        subresult = translatechunk(region, subdf)

        if result == nothing
            result = transpose(subresult)
        else
            result = vcat(result, transpose(subresult))
        end
    end

    convert(DataFrame, result)
end
