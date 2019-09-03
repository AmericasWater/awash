using NetCDF

function netcdf2csv{T<:AbstractString}(ncpath::T, csvpath::T, coldimname::T, skipdimnames::Vector{T}=T[])
    println("Understanding dimensions...")

    nc4 = ncinfo(ncpath)

    coldim = nc4.dim[coldimname]
    skipdims = [nc4.dim[skipdimname] for skipdimname in skipdimnames]

    # Find any variable that follows the other dimensions (store it)
    rowdims = Dict{AbstractString, AbstractVector{Float64}}()
    for varname in keys(nc4.vars)
        if length(nc4.vars[varname].dim) == 1 && nc4.vars[varname].dim[1] != coldim && !any([skipdim in nc4.vars[varname].dim for skipdim in skipdims])
            rowdims[varname] = vec(nc4.vars[varname])
        end
    end

    rownames = []
    cols = Int64(length(rowdims) + coldim.dimlen)
    result = DataArray(Float64, 0, cols)

    # Find any variable that follows the column dimension
    for varname in keys(nc4.vars)
        if length(nc4.vars[varname].dim) == 1 && nc4.vars[varname].dim[1] == coldim
            push!(rownames, varname)
            result = [result; [@data(repmat([NaN], length(rowdims))); vec(nc4.vars[varname])]']
        end
    end

    # Add all remaining variables
    println("Collecting variables...")
    for varname in keys(nc4.vars)
        if length(nc4.vars[varname].dim) == 1 || any([skipdim in nc4.vars[varname].dim for skipdim in skipdims])
            continue
        elseif !(coldim in nc4.vars[varname].dim)
            println("Skipping $varname since it does not include $coldimname.")
        else
            println("  $varname")
            rows = Int64(prod(map(dim -> (dim == coldim ? 1 : dim.dimlen), nc4.vars[varname].dim)))
            addition = DataArray(Float64, rows, cols)
            for ii in 1:rows
                push!(rownames, varname)

                # Generate index for row ii
                indexes = []
                rowvalues = Float64[]
                offset = ii - 1
                for dim in nc4.vars[varname].dim
                    if dim == coldim
                        push!(indexes, :)
                    else
                        rowindex = offset % dim.dimlen + 1
                        push!(rowvalues, rowdims[dim.name][rowindex])
                        push!(indexes, rowindex)
                        offset = floor(Int64, offset / dim.dimlen)
                    end
                end

                addition[ii, 1:length(rowdims)] = rowvalues
                addition[ii, length(rowdims)+1:end] = nc4.vars[varname][indexes...]
            end

            result = [result; addition]
        end
    end

    writecsv(csvpath, [rownames result])
end

# netcdf2csv(expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/VIC_WB.nc"), expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/VIC_WB.csv"), "county")
# netcdf2csv(expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/contributing_runoff_by_gage.nc"), expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/contributing_runoff_by_gage.csv"), "gage", ["nchar"])
# netcdf2csv(expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/VIC_WB-states.nc"), expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/VIC_WB-states.csv"), "state")
# netcdf2csv(expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/contributing_runoff_by_gage-states.nc"), expanduser("~/Dropbox/America\'s\ Water/Public\ Model\ Data/contributing_runoff_by_gage-states.csv"), "gage")

source = ARGS[1]
target = convert(String, splitext(source)[1] * ".csv")
coldimname = ARGS[2]
skipdimnames = ARGS[3:end]

netcdf2csv(source, target, coldimname, skipdimnames)
