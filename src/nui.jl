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
    Pkg.add("RCall")
end

if Pkg.installed("YAML") == nothing
    Pkg.add("YAML")
end

@windows_only iswindows = true
if !isdefined(:windows) && Pkg.installed("NetCDF") == nothing
    Pkg.add("NetCDF")
end

using OptiMimi
using MathProgBase
using RCall

include("lib/datastore.jl")
include("lib/readconfig.jl")

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
    include("optimization-surface.jl")
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

mapinited = false

function mapdata(component, variable, subset=nothing)
    global mapinited

    if subset == nothing
        data = vec(getdata(component, variable))
    else
        data = vec(getdata(component, variable)[subset...])
    end

    if length(data) != numcounties
        error("This does not appear to be a county result.")
    end

    if !mapinited
        RCall.ijulia_setdevice(MIME("image/png"),width=8*72,height=5*72)
        R"library(ggplot2)"
        R"library(PBSmapping)"
        R"shapes <- importShapefile('../data/mapping/US_county_2000-simple')"
        R"polydata <- attributes(shapes)$PolyData"
        R"polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]"
        R"polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]"
        R"shapes$id <- polydata$STATE[shapes$PID] * 100 + polydata$COUNTY[shapes$PID] / 10";
        R"names(shapes) <- tolower(names(shapes))";

        mapinited = true
    end

    df = DataFrame(fips=collect(mastercounties[:fips]), value=data)

    R"ggplot($df, aes(map_id=fips)) +
    geom_map(aes(fill=value), map=shapes) +
    expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
    theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')"
end

open("../docs/intro.txt") do fp
    println(readall(fp))
end

