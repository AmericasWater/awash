include("../../src/lib/readconfig.jl");
config = readconfig("../../configs/complete.yml")
config["startmonth"] = "1/1950"
config["timestep"] = 12

include("../../src/world.jl");
include("../../src/weather.jl");
include("../../src/UnivariateAgriculture.jl");

## XXX: This code duplicates some of the work in James's crops/regress.jl

irrigatedareas = DataArray(zeros(Float64, numcounties, numcrops, numsteps)) * NA;
rainfedareas = DataArray(zeros(Float64, numcounties, numcrops, numsteps)) * NA;

getyields = Dict() # crop symbol => (Function(fips, fid, year) -> (irrigated, rainfed))

## Load values where we only have combined
targetcrops = Dict(:barley => "Barley", :hay => "alfalfa", :sorghum => "Sorghum", :soybeans => "Soybeans") #:rice => ???
sourcefiles = Dict(:barley => ("barley_area_planted_in_acre.csv", "barley_production_in_bu.csv"),
                   :hay => ("hay_area_harvested_in_acre.csv", "hay_production_in_lb.csv"),
                   :rice => ("rice_area_planted_in_acre.csv", "rice_production_in_cwt.csv"),
                   :sorghum => ("sorghum_area_planted_in_acre.csv", "sorghum_production_in_lb.csv"),
                   :soybeans => ("soybeans_area_planted_in_acre.csv", "soybeans_production_in_bu.csv"))
isirrigated = Dict(:barley => false, :hay => false, :rice => true, :sorghum => false, :soybeans => true)
isperennial = Dict(:barley => false, :hay => true, :rice => false, :sorghum => false, :soybeans => false)

fipsmapping = readtable(datapath("agriculture/allyears/Master_Spreadsheet_All.csv"));

for crop in keys(targetcrops)
    println("Loading $crop...")

    areas = readtable(datapath("agriculture/allyears/$(sourcefiles[crop][1])"));
    if isperennial[crop]
        getareas = (fid, year) -> areas[areas[:, :cnty_FID] .== fid, symbol("AREA_HARVESTED_$year")][1]
    else
        getareas = (fid, year) -> areas[areas[:, :cnty_FID] .== fid, symbol("AREA_PLANTED_$year")][1]
    end

    jj = find(targetcrops[crop] .== crops)[1]

    for ii in 1:nrow(masterregions)
        fidrows = fipsmapping[:, :FIPS] .== parse(Int64, masterregions[ii, :fips]);
        if sum(fidrows) == 1
            fid = fipsmapping[fidrows, :FID][1]

            for year in 1950:2010
                if isirrigated[crop]
                    irrigatedareas[ii, jj, year - 1949] = getareas(fid, year)
                else
                    rainfedareas[ii, jj, year - 1949] = getareas(fid, year)
                end
            end
        end
    end
end

for crop in keys(targetcrops)
    # use -1 for NA, because of DataFrames error
    areas = readtable(datapath("agriculture/allyears/$(sourcefiles[crop][1])"));
    production = readtable(datapath("agriculture/allyears/$(sourcefiles[crop][2])"));
    if isperennial[crop]
        if isirrigated[crop]
            getyields[crop] = (fips, fid, year) -> (production[production[:, :cnty_FID] .== fid, symbol("PRODUCTION_$year")][1] / areas[areas[:, :cnty_FID] .== fid, symbol("AREA_HARVESTED_$year")][1], NA)
        else
            getyields[crop] = (fips, fid, year) -> (NA, production[production[:, :cnty_FID] .== fid, symbol("PRODUCTION_$year")][1] / areas[areas[:, :cnty_FID] .== fid, symbol("AREA_HARVESTED_$year")][1])
        end
    else
        if isirrigated[crop]
            getyields[crop] = (fips, fid, year) -> (production[production[:, :cnty_FID] .== fid, symbol("PRODUCTION_$year")][1] / areas[areas[:, :cnty_FID] .== fid, symbol("AREA_PLANTED_$year")][1], NA)
        else
            getyields[crop] = (fips, fid, year) -> (NA, production[production[:, :cnty_FID] .== fid, symbol("PRODUCTION_$year")][1] / areas[areas[:, :cnty_FID] .== fid, symbol("AREA_PLANTED_$year")][1])
        end
    end
end

## Load values where have irrigated and rainfed
targetcrops = Dict(:maize => "Maize", :wheat => "Wheat") # :cotton => ???
for crop in keys(targetcrops)
    println("Loading $crop...")

    irrigated = readtable(datapath("agriculture/allyears/$crop-irrigated-planted.csv"));
    irrigated[:fips] = [isna(irrigated[ii, :County_ANSI]) ? 0 : irrigated[ii, :State_ANSI] * 1000 + irrigated[ii, :County_ANSI] for ii in 1:nrow(irrigated)];
    irrigated[:xvalue] = map(str -> parse(Float64, replace(str, ",", "")), irrigated[:Value]);
    rainfed = readtable(datapath("agriculture/allyears/$crop-nonirrigated-planted.csv"));
    rainfed[:fips] = [isna(rainfed[ii, :County_ANSI]) ? 0 : rainfed[ii, :State_ANSI] * 1000 + rainfed[ii, :County_ANSI] for ii in 1:nrow(rainfed)];
    rainfed[:xvalue] = map(str -> parse(Float64, replace(str, ",", "")), rainfed[:Value]);

    function getareas(fips::Int64, year::Int64)
        irrigatedindex = find((irrigated[:fips] .== fips) & (irrigated[:Year] .== year))
        if length(irrigatedindex) == 0
            irrigatedvalue = NA
        else
            irrigatedvalue = irrigated[irrigatedindex, :xvalue][1]
        end

        rainfedindex = find((rainfed[:fips] .== fips) & (rainfed[:Year] .== year))
        if length(rainfedindex) == 0
            rainfedvalue = NA
        else
            rainfedvalue = rainfed[rainfedindex, :xvalue][1]
        end

        (irrigatedvalue, rainfedvalue)
    end

    jj = find(targetcrops[crop] .== crops)[1]

    for ii in 1:nrow(masterregions)
        for year in 1950:2010
            irrigatedvalue, rainfedvalue = getareas(parse(Int64, masterregions[ii, :fips]), year)
            irrigatedareas[ii, jj, year - 1949] = irrigatedvalue
            rainfedareas[ii, jj, year - 1949] = rainfedvalue
        end
    end

    irrigatedproduction = readtable(datapath("agriculture/allyears/$crop-irrigated-production.csv"));
    irrigatedproduction[:fips] = [isna(irrigatedproduction[ii, :County_ANSI]) ? 0 : irrigatedproduction[ii, :State_ANSI] * 1000 + irrigatedproduction[ii, :County_ANSI] for ii in 1:nrow(irrigatedproduction)];
    irrigatedproduction[:xvalue] = map(str -> parse(Float64, replace(str, ",", "")), irrigatedproduction[:Value]);
    rainfedproduction = readtable(datapath("agriculture/allyears/$crop-nonirrigated-production.csv"));
    rainfedproduction[:fips] = [isna(rainfedproduction[ii, :County_ANSI]) ? 0 : rainfedproduction[ii, :State_ANSI] * 1000 + rainfedproduction[ii, :County_ANSI] for ii in 1:nrow(rainfedproduction)];
    rainfedproduction[:xvalue] = map(str -> parse(Float64, replace(str, ",", "")), rainfedproduction[:Value]);

    function getyield(fips::Int64, fid::Int64, year::Int64)
        irrigatedindex = find((irrigated[:fips] .== fips) & (irrigated[:Year] .== year))
        if length(irrigatedindex) == 0
            irrigatedvalue = NA
        else
            irrigatedvalue = irrigated[irrigatedindex, :xvalue][1]
        end

        irrigatedproductionindex = find((irrigatedproduction[:fips] .== fips) & (irrigatedproduction[:Year] .== year))
        if length(irrigatedproductionindex) == 0
            irrigatedproductionvalue = NA
        else
            irrigatedproductionvalue = irrigatedproduction[irrigatedproductionindex, :xvalue][1]
        end

        rainfedindex = find((rainfed[:fips] .== fips) & (rainfed[:Year] .== year))
        if length(rainfedindex) == 0
            rainfedvalue = NA
        else
            rainfedvalue = rainfed[rainfedindex, :xvalue][1]
        end

        rainfedproductionindex = find((rainfedproduction[:fips] .== fips) & (rainfedproduction[:Year] .== year))
        if length(rainfedproductionindex) == 0
            rainfedproductionvalue = NA
        else
            rainfedproductionvalue = rainfedproduction[rainfedproductionindex, :xvalue][1]
        end

        (irrigatedproductionvalue / irrigatedvalue, rainfedproductionvalue / rainfedvalue)
    end

    getyields[crop] = getyield
end

writecsv("irrigatedareas.csv", reshape(irrigatedareas, 3109*9, 61))
writecsv("rainfedareas.csv", reshape(rainfedareas, 3109*9, 61))

# Set to 0 for model
irrigatedareas[isna(irrigatedareas)] = 0
rainfedareas[isna(rainfedareas)] = 0

## Run the model
model = newmodel();

agriculture = initagriculture(model);

agriculture[:irrigatedareas] = irrigatedareas
agriculture[:rainfedareas] = rainfedareas

run(model);

## Compare the results

allcrops = [:barley, :hay, :sorghum, :soybeans, :maize, :wheat]
allnames = Dict(:barley => "Barley", :hay => "alfalfa", :sorghum => "Sorghum", :soybeans => "Soybeans", :maize => "Maize", :wheat => "Wheat") #:rice => ???, :cotton => ???

dfbycy = DataFrame(crop=[], fips=[], year=[], obsirrigatedyield=[], estirrigatedyield=[],
                   obsrainfedyield=[], estrainfedyield=[])
for crop in allcrops
    println("Recording $crop...")

    jj = find(allnames[crop] .== crops)[1]

    for ii in 1:nrow(masterregions)
        fidrows = fipsmapping[:, :FIPS] .== parse(Int64, masterregions[ii, :fips]);
        if sum(fidrows) == 1
            fid = fipsmapping[fidrows, :FID][1]

            for year in 1950:2010
                irrigatedyield, rainfedyield = getyields[crop](parse(Int64, masterregions[ii, :fips]), fid, year)
                if isna(irrigatedyield)
                    irrigatedyield = -1.
                end
                if isna(rainfedyield)
                    rainfedyield = -1.
                end
                push!(dfbycy, @data([crop masterregions[ii, :fips] year irrigatedyield exp(model.parameters[:logirrigatedyield].values[ii, jj, year - 1949]) rainfedyield exp(model[:Agriculture, :lograinfedyield][ii, jj, year - 1949])]))
            end
        end
    end
end

writetable("byyear.csv", dfbycy)

recorded = readtable(datapath("extraction/USGS-2010.csv"))

dfbyww = DataFrame(fips=masterregions[:fips], year=2010,
                   obsirrigation=recorded[:, :IR_To] * 1382592. / 1000,
                   estirrigation=model[:Agriculture, :totalirrigation][:, end])

writetable("irrigation.csv", dfbyww)
