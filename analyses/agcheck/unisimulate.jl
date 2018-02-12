include("../../src/lib/readconfig.jl");
config = readconfig("../configs/complete.yml")
config["startmonth"] = "1/1950"
config["timestep"] = 12;

include("../../src/world.jl");
include("../../src/weather.jl");
include("../../src/UnivariateAgriculture.jl");

model = newmodel();
agriculture = initunivariateagriculture(model);
run(model);

fipsmapping = readtable(datapath("agriculture/allyears/Master_Spreadsheet_All.csv"));

dfbycy = DataFrame(crop=String[], fips=String[], year=Int64[], obsprod=Float64[], estprod=Float64[])
for crop in ["barley"]
    obsprods = readtable("../../data/counties/agriculture/allyears/barley_production_in_bu.csv")
    estprods = model[:UnivariateAgriculture, :production][:, 1, :]
    for ii in 1:nrow(masterregions)
        if ii % 300 == 0
            println(ii)
        end
        fidrows = fipsmapping[:, :FIPS] .== parse(Int64, masterregions[ii, :fips]);
        if sum(fidrows) == 1
            fid = fipsmapping[fidrows, :FID][1]
            for year in 1950:2010
                obsprod = obsprods[obsprods[:cnty_FID] .== fid, symbol("PRODUCTION_$year")]
                estprod = estprods[ii, 1, year - 1950 + 1]
                if !isna(obsprod[1])
                    push!(dfbycy, [crop masterregions[ii, :fips] year obsprod estprod])
                end
            end
        end
    end
end

writetable("unibyyear.csv", dfbycy)

dfbyy = DataFrame(fips=[], year=[], obsirrig=[], estirrig=[])

obsirrigs = readtable("../../data/counties/extraction/allyear_irrigation.csv")
estirrigs = model[:UnivariateAgriculture, :totalirrigation]

for ii in 1:nrow(masterregions)
    if ii % 300 == 0
        println(ii)
    end
    for year in 1985:5:2010
        obsirrig = obsirrigs[obsirrigs[:FIPS] .== parse(Int64, masterregions[ii, :fips]), symbol("IR_To_$year")]
        estirrig = estirrigs[ii, 1, year - 1950 + 1]
        push!(dfbycy, @data([crop masterregions[ii, :fips] year obsirrig estirrig]))
    end
end
