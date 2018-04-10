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
    df = CSV.read(filepath, types=types, null=null)
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
    entries[entries.isnull] = replace
    convert(Vector{T}, entries)
end

function dropmissing(df::DataFrame, column::Symbol)
    df[.!df[column].isnull,:]
end

