function replacemissing(df::DataFrame, column::Symbol, replace::Float64)
    entries = df[column]
    entries[entries.isnull] = replace
    convert(Vector{Float64}, entries)
end
