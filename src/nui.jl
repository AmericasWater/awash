## Basic User Interface
#
# Install any packages that need to be installed and sets up standard
# functions.

using Pkg
versions = Pkg.installed()

if !("CSV" in keys(versions))
    Pkg.add("CSV")
end

if !("Mimi" in keys(versions))
    Pkg.add("Mimi")
end

if !("OptiMimi" in keys(versions))
    Pkg.add("OptiMimi")
    Pkg.checkout("OptiMimi")
end

if !("Graphs" in keys(versions))
    Pkg.add("Graphs")
end

if !("MathProgBase" in keys(versions))
    Pkg.add("MathProgBase")
end

if !("Missings" in keys(versions))
    Pkg.add("Missings")
end

if !("RCall" in keys(versions))
    @warn "RCall is not installed, so some graphing will not work.  If you have R installed, install RCall with `Pkg.add(\"RCall\")`."
end

if !("YAML" in keys(versions))
    Pkg.add("YAML")
end

if !("RData" in keys(versions))
    Pkg.add("RData")
end

if !is_windows() && !("NetCDF" in keys(versions))
    Pkg.add("NetCDF")
end

using DataFrames

using OptiMimi
using MathProgBase

include("lib/datastore.jl")
include("lib/readconfig.jl")
include("lib/graphing.jl")

config = emptyconfig()
model = nothing # The master model object for functions below

function prepsimulatesurface(configfile::AbstractString)
    global config, model

    config = readconfig("../configs/" * configfile)

    # Download any files we will need
    predownload()

    include("../src/model-surfacewater.jl")
end

function prepsimulate(configfile::AbstractString)
    global config, model

    config = readconfig("../configs/" * configfile)

    # Download any files we will need
    predownload()

    include("../src/model.jl")
end

function prepoptimizesurface(configfile::AbstractString)
    global config, model

    config = readconfig("../configs/" * configfile)

    # Download any files we will need
    predownload()

    include(joinpath(dirname(@__FILE__), "optimization-given.jl"))
    global redogwwo = true
    house = Base.invokelatest(optimization_given, false)
    model = house
end

function prepoptimize(configfile::AbstractString)
    global config, model

    config = readconfig("../configs/" * configfile)

    # Download any files we will need
    predownload()

    include("optimization.jl")
    model = house
end

function runmodel(solver=nothing)
    if typeof(model) <: Model
        run(model)
    elseif typeof(model) <: LinearProgrammingHouse
        if solver == nothing
            houseoptimize(model)
        else
            houseoptimize(model, solver)
        end
    end
end

"""
Return a table of the parameters and variables of a component, and
their corresponding dimensions.

`component` should be a symbol, like `:MyComponent`.
"""
function getvariables(component)
    parlist = parameters(component)
    varlist = variables(component)

    pardims = map(name -> getindexlabels(model, component, name), parlist)
    vardims = map(name -> getindexlabels(model, component, name), varlist)

    DataFrame(name=[parlist; varlist], dims=[pardims; vardims])
end

function savedata(filename, component, variable, subset=nothing)
    if subset == nothing
        writecsv(filename, model[component, variable])
    else
        writecsv(filename, model[component, variable][subset...])
    end
end

"""
Produce a choropleth map of an output variable from a model run.

# Arguments:
* `component`: a symbol for a component (e.g., :Allocation)
* `variable`: a symbol for a variable (e.g., :waterallocated)
"""
function mapdata(component, variable=nothing, subset=nothing, centered=nothing)
    if variable == nothing
	data = vec(component)
    elseif subset == nothing
        data = vec(model[component, variable])
    else
        data = vec(model[component, variable][subset...])
    end

    if length(data) != numcounties
        error("This does not appear to be a county result.")
    end

    df = DataFrame(fips=collect(masterregions[!, :fips]), value=data)
    usmap(df, centered=nothing)
end


open(joinpath(dirname(@__FILE__), "../docs/intro.txt")) do fp
    println(readstring(fp))
end
