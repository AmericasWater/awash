filepath = ARGS[1]

function input{T<:AbstractString}(prompt::T; options::Dict{T, T}=Dict{T, T}(), default::T="")
    if isempty(options)
        if default == ""
            print("$prompt: ")
        else
            print("$prompt [$default]: ")
        end
        return chomp(readline())
    else
        if default == ""
            println("$prompt:")
        else
            println("$prompt [$default]:")
        end
        for key in keys(options)
            println("$key: $(options[key])")
        end
        print("Enter: ")

        selected = chomp(readline())
        if selected == "" && default != ""
            return default
        end
        if selected in keys(options)
            return selected
        else
            println("No option '$selected'.")
            return input(prompt, options=options, default=default)
        end
    end
end

function ingestweather(filepath)
    if input("This appears to be a weather file.  Cannot check file integrity.  Replace existing weather", options=Dict("y" => "Yes", "n" => "No"), default="y") != "y"
        quit()
    end

    # Copy to cache
    cp(filepath, "../data/cache/counties/" * splitdir(filepath)[2], remove_destination=true)

    # Copy to Dropbox
    if isdir("/Users/jrising/Dropbox/America\'s\ Water/Public\ Model\ Data/")
        println("Copying to public model data Dropbox.")
        source = "/Users/jrising/Dropbox/America\'s\ Water/Public\ Model\ Data/" * splitdir(filepath)[2]
        cp(filepath, source, remove_destination=true)
    else
        println("Processing in-place.  Please copy to the America\'s\ Water/Public\ Model\ Data Dropbox")
        source = filepath
    end

    # Run netcdf2csv
    if splitdir(source)[2] == "contributing_runoff_by_gage.nc"
        println("Converting to CSV...")
        run(`julia netcdf2csv.jl "$source" gage nchar`)
        println("Converting to state-level...")
        cd("bystate/weather")
        run(`julia convert-bygauge.jl`)
        cd("../..")
        println("Converting to state-level CSV...")
        run(`julia netcdf2csv.jl $(splitext(source)[1])-states.nc gage`)
    elseif splitdir(source)[2] == "VIC_WB.nc"
        println("Converting to CSV...")
        run(`julia netcdf2csv.jl "$source" county`)
        println("Converting to state-level...")
        cd("bystate/weather")
        run(`julia convert-bycounty.jl`)
        cd("../..")
        println("Converting to state-level CSV...")
        run(`julia netcdf2csv.jl $(splitext(source)[1])-states.nc state`)
    else
        println("Unknown file: cannot perform NetCDF2CSV automatically.")
    end
end

filenameprocs = Dict{AbstractString, Function}("contributing_runoff_by_gage.nc" => ingestweather, "VIC_WB.nc" => ingestweather)

filedir, filename = splitdir(filepath)
if filename in keys(filenameprocs)
    proc = filenameprocs[filename]
else
    proc = input("Cannot find handling for this file.  Please select one of the available functions", options=map(proc -> "$proc", unique(values(filenameprocs))))
end

proc(filepath)
