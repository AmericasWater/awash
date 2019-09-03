using Test

include("../src/lib/datastore.jl")
include("../src/lib/readconfig.jl")

config = readconfig("../configs/standard-state.yml")

@test !cached_fallback("dummydata", () -> false)
cached_store("dummydata", true)
@test cached_fallback("dummydata", () -> false)

# Clean up
confighash = hash(config)
rm(cachepath("dummydata-$confighash.jld"))
