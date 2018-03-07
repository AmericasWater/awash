# Install any packages that need to be installed

if Pkg.installed("Mimi") == nothing
    Pkg.add("Mimi")
    Pkg.checkout("Mimi")
end

if Pkg.installed("OptiMimi") == nothing
    Pkg.add("OptiMimi")
    Pkg.checkout("OptiMimi")
end

if Pkg.installed("Graphs") == nothing
    Pkg.add("Graphs")
end

if Pkg.installed("MathProgBase") == nothing
    Pkg.add("MathProgBase")
end

if Pkg.installed("RCall") == nothing
    warn("RCall is not installed, so some graphing will not work.  If you have R installed, install RCall with `Pkg.add(\"RCall\")`.")
end

if Pkg.installed("YAML") == nothing
    Pkg.add("YAML")
end

if Pkg.installed("RData") == nothing
    Pkg.add("RData")
end

if !is_windows() && Pkg.installed("NetCDF") == nothing
    Pkg.add("NetCDF")
end

using DataFrames

using OptiMimi
using MathProgBase
import Mimi.getmetainfo

include("lib/datastore.jl")
include("lib/readconfig.jl")
include("lib/graphing.jl")

config = emptyconfig()
model = nothing # The master model object for functions below

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

    include("optimization-given.jl")
    house = optimization_given(false)
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
    parlist = collect(keys(getmetainfo(model, component).parameters))

    varlist = variables(model, component)

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
function mapdata(component, variable, subset=nothing)
    if subset == nothing
        data = vec(model[component, variable])
    else
        data = vec(model[component, variable][subset...])
    end

    if length(data) != numcounties
        error("This does not appear to be a county result.")
    end

    df = DataFrame(fips=collect(masterregions[:fips]), value=data)
    usmap(df)
end

open("../docs/intro.txt") do fp
    println(readstring(fp))
end
