# Install any packages that need to be installed

if Pkg.installed("Mimi") == nothing
    Pkg.add("Mimi")
    Pkg.pin("Mimi", v"0.2.0")
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

@windows_only iswindows = true
if !isdefined(:iswindows) && Pkg.installed("NetCDF") == nothing
    Pkg.add("NetCDF")
end

using DataFrames

if !isdefined(:isna)
    function isna(xx)
        convert(BitArray, map(x -> isequal(NA, x), xx))
    end
end

using OptiMimi
using MathProgBase

include("lib/datastore.jl")
include("lib/readconfig.jl")
include("lib/graphing.jl")

# Download any files we will need
predownload()

model = nothing # The master model object for functions below

function prepsimulate(configfile::AbstractString)
    global config, model

    config = readconfig("../configs/" * configfile)
    include("../src/model.jl")
end

function prepoptimizesurface(configfile::AbstractString)
    global config, model

    config = readconfig("../configs/" * configfile)
    include("optimization-given.jl")
    house = optimization_given(false)
    model = house
end

function prepoptimize(configfile::AbstractString)
    global config, model

    config = readconfig("../configs/" * configfile)
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

function getvariables(component)
    parameters = fieldnames(model.components[component].Parameters)
    variables = fieldnames(model.components[component].Variables)

    pardims = map(name -> string(size(model.components[component].Parameters.(name))), parameters)
    vardims = map(name -> string(size(model.components[component].Variables.(name))), variables)

    DataFrame(name=[parameters; variables], dims=[pardims; vardims])
end

function getdata(component, variable)
    if variable in fieldnames(model.components[component].Parameters)
        model.components[component].Parameters.(variable)
    elseif variable in fieldnames(model.components[component].Variables)
        model[component, variable]
    else
        error("Unknown parameter or variable")
    end
end

function savedata(filename, component, variable, subset=nothing)
    if subset == nothing
        writecsv(filename, getdata(component, variable))
    else
        writecsv(filename, getdata(component, variable)[subset...])
    end
end

"""
Produce a choropleth map of an output variable from a model run.

# Arguments:
* `component`: a symbol for a component (e.g., :Allocation)
* `variable`: a symbol for a variable (e.g., :waterallocated)
"""
function mapdata(component, variable=nothing, subset=nothing, center=false)
    if variable !=nothing
	if subset == nothing
            data = vec(getdata(component, variable))
        elseif subset == "sum"
	    data = vec(sum(getdata(component, variable),2))
        else
            data = vec(getdata(component, variable)[subset...])
        end
    else
	data = vec(component)
    end
    if length(data) != numcounties
        error("This does not appear to be a county result.")
    end

    df = DataFrame(fips=collect(mastercounties[:fips]), value=data)
    usmap(df,center)
end

open("../docs/intro.txt") do fp
    println(readall(fp))
end

