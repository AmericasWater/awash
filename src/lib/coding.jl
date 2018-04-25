## Reproducability library
#
# Functions to make AWASH code consistent, even as underlying
# libraries change.

"""
Read a CSV file, with some type management.
nullallow has the same number of elements as types.
  nullallow[ii] may be nothing, in which case nulls produce an error
  nullallow[ii] may be NA, in which case nulls are allowed
  nullallow[ii] may be a value, in which case nulls are replaced with the value.
"""
function robustcsvread(filepath::String, types::Vector{DataType}, null::String, nullallow::Vector{Any})
    df = readtable(filepath, eltypes=types, nastrings=[null])
    for ii in 1:length(types)
        try
            if nullallow[ii] == nothing
                df[:, ii] = convert(Vector{types[ii]}, df[:, ii])
            elseif typeof(nullallow[ii]) != DataArrays.NAtype
                df[:, ii] = replacemissing(df, names(df)[ii], nullallow[ii])
            end
        catch
            println("Column $(names(df)[ii]) null-handling failed.")
        end
    end

    df
end

function replacemissing{T}(df::DataFrame, column::Symbol, replace::T)
    entries = df[column]
    entries[isna.(entries)] = replace
    convert(Vector{T}, entries)
end

function dropmissing(df::DataFrame, column::Symbol)
    df[.!isna.(df[column]),:]
end

warnedonce = []

function warnonce(warning::String)
    if !(warning in warnedonce)
        push!(warnedonce, warning)
        println(warning)
    end
end

### Extensions to Mimi

using Mimi
import Mimi: ModelInstance, getdiminfoforvar

function getdataframe(m::Model, componentname::Symbol, name::Symbol)
    if isnull(m.mi)
        error("Cannot get dataframe, model has not been built yet")
    elseif !(name in variables(m, componentname))
        error("Cannot get dataframe; variable not in provided component")
    else
        return getdataframe(m, get(m.mi), componentname, name)
    end
end

function getdataframe(m::Model, mi::ModelInstance, componentname::Symbol, name::Symbol)
    comp_type = typeof(mi.components[componentname])

    meta_module_name = Symbol(supertype(typeof(mi.components[componentname])).name.module)
    meta_component_name = Symbol(supertype(typeof(mi.components[componentname])).name.name)

    vardiminfo = getdiminfoforvar((meta_module_name,meta_component_name), name)

    if length(vardiminfo)==0
        return mi[componentname, name]
    elseif length(vardiminfo)==1
        df = DataFrame()
        df[vardiminfo[1]] = m.indices_values[vardiminfo[1]]
        df[name] = mi[componentname, name]
        return df
    else
        return getdataframe_helper(m, name, vardiminfo, mi[componentname, name])
    end
end

function getdataframe_helper(m::Model, name::Symbol, vardiminfo::Array{Any}, data::AbstractArray)
    if length(vardiminfo)==2
        df = DataFrame()
        dim1 = length(m.indices_values[vardiminfo[1]])
        dim2 = length(m.indices_values[vardiminfo[2]])
        df[vardiminfo[1]] = repeat(m.indices_values[vardiminfo[1]],inner=[dim2])
        df[vardiminfo[2]] = repeat(m.indices_values[vardiminfo[2]],outer=[dim1])
        df[name] = cat(1,[vec(data[i,:]) for i=1:dim1]...)
        return df
    else
        # Initial blank DF
        df = nothing

        # Indexes is #, :, :, ... for each index of first dimension
        indexes = repmat(Any[Colon()], length(vardiminfo))
        for ii in 1:size(data)[1]
            indexes[1] = ii
            subdf = getdataframe_helper(m, name, vardiminfo[2:end], data[indexes...])
            subdf[vardiminfo[1]] = m.indices_values[vardiminfo[1]][ii]
            if df == nothing
                df = subdf
            else
                df = vcat(df, subdf)
            end
        end

        return df
    end
end
