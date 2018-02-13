using DataFrames

include("../../src/lib/readconfig.jl");
config = readconfig("../../configs/complete.yml")
config["startmonth"] = "1/1950"
config["timestep"] = 12

include("../../src/lib/weather.jl")

mastercounties = readtable(datapath("global/counties.csv"), eltypes=[String, String, String])

## Load yearly precipitation
statefips = dncload("weather", "state_fips", ["county"])
countyfips = dncload("weather", "county_fips", ["county"])
fips = map(fipsnum -> (fipsnum < 10000 ? "0$fipsnum" : "$fipsnum"), round(Int, statefips * 1000 + countyfips))

# Load precipitation from the county-aggregated weather
numsteps = round(Int64, (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"])

precip = reorderfips(sum2timestep(dncload("weather", "precip", ["county", "month"])), fips, mastercounties[:fips]); # mm / timestep

## Load yearly NDI by crop
deficitvalues = readtable("/home/jrising/Dropbox/CWC databases/Drought/per_crop/unit_area_deficit_in_meter/hay__unit_area_deficit_in_meter.csv")

deficit = reorderfips_notranspose(Array{Float64}(deficitvalues[:, 5:65]), map(fips -> fips > 10000 ? "$fips" : "0$fips", deficit[:FIPS]), mastercounties[:fips])

corprecip = vec(precip)
cordeficit = vec(deficit)
corvalid = !isnan(corprecip) & !isnan(cordeficit)

cor(corprecip[corvalid], cordeficit[corvalid])
