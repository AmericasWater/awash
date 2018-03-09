using YAML

function readconfig(ymlpath)
    if length(ymlpath) > 11 && ymlpath[1:11] == "../configs/"
        ymlpath = joinpath(dirname(@__FILE__), "../" * ymlpath)
    end

    config = YAML.load(open(ymlpath))
    if "parent-config" in keys(config)
        config = mergeconfigs(readconfig(joinpath(dirname(ymlpath), config["parent-config"] * ".yml")), config)
    end
    
    dataset = readdatasetconfig(config["dataset"])

    config = mergeconfigs(dataset, config)

    config["indexcols"] = map(Symbol, config["indexcols"])

    config
end

"""
Read dataset configuration
"""
function readdatasetconfig(dataset)
    dataset = YAML.load(open(joinpath(dirname(@__FILE__), "../../data/" * dataset * "/dataset.yml")))
    if "parent-dataset" in keys(dataset)
        parent = readdatasetconfig(dataset["parent-dataset"])

        return mergeconfigs(parent, dataset)
    else
        return dataset
    end
end

"""
Universal logic for merging config files
"""
function mergeconfigs(parent, child)
    for key in keys(parent)
        if !in(key, keys(child))
            child[key] = parent[key]
        else
            if isa(parent[key], Dict) && isa(child[key], Dict)
                child[key] = mergeconfigs(parent[key], child[key])
            end
        end
    end
    return child
end

function emptyconfig()
    Dict{AbstractString, Any}()
end

function parsemonth(mmyyyy)
    parts = split(mmyyyy, '/')
    (parse(UInt16, parts[2]) - 1) * 12 + parse(UInt8, parts[1])
end

# Consider reworking this using index2yearindex and similar
function index2year(tt::Int64)
    startmonth = parsemonth(config["startmonth"])
    startyear = parse(Int16, split(config["startmonth"], '/')[2])
    endyear = parse(Int16, split(config["endmonth"], '/')[2])

    times = startmonth:config["timestep"]:parsemonth(config["endmonth"])
    years = startyear:endyear

    years[div(times[tt]-1, 12) - div(startmonth, 12) + 1]


end

if !isdefined(:configtransforms)
    configtransforms = Dict{AbstractString, Function}()
    configtransforms["identity"] = (index, x) -> x
    configtransforms["repcap"] = (index, x) -> error("The PopulationDemand component needs to be loaded first.")
end

"""
Understanding main indexes

TODO: This should look at config to see what these mean in context
"""
function getindices(name::Symbol, as::Type=Any)
    if name == :regions
        values = masterregions[:fips]
    else
        error("We have not defined index $name yet.")
    end

    if as != Any && as != typeof(values[1])
        values = Vector{as}([parse(as, value) for value in values])
    end

    values
end


"""
Read data, in a configurable way.

If config contains `<name>-path`, read the values from there; if
config contains `<name>-column`, read from that column (of the default
file or the configured file).

The default data file path and default column within that file are
given by `defpath` and `defcol`.

If not all values are given, then an additional `<name>-index` config
parameter is required, which specifies the column for that corresponds
to the values in `defindex`, an symbol known by `getindices`.
"""
function configdata(name::AbstractString, defpath::AbstractString, defcol::Symbol, defindex::Symbol)
    if haskey(config, "$name-path") || haskey(config, "$name-column")
        path = datapath(get(config, "$name-path", defpath))
        column = Symbol(get(config, "$name-column", defcol))
        transform = configtransforms[get(config, "$name-transform", "identity")]

        data = readtable(path)
        if nrow(data) == length(getindices(defindex))
            # We can use these values directly
            indices = getindices(defindex)
            return [transform(indices[ii], data[ii, column]) for ii in 1:nrow(data)]
        else
            if haskey(config, "$name-index")
                indexcol = Symbol(config["$name-index"])

                # Read in the default values
                values = readtable(datapath(defpath))[:, defcol]
                indices = getindices(defindex, typeof(values[1]))
                # Fill in the new values where given
                for rr in 1:nrow(data)
                    ii = findfirst(data[rr, indexcol] .== indices)
                    if ii > 0
                        newvalue = transform(data[rr, indexcol], data[rr, column])
                        if !isna.(newvalue)
                            values[ii] = newvalue
                        end

                    end
                end

                return values
            else
                error("There are not $(length(getindices(defindex))) entries, but no $name-index configuration specified.")
            end
        end
    else
        readtable(datapath(defpath))[:, defcol]
    end
end
