using DataFrames

eddlimits = Dict("alfalfa" => (0, 30), "otherhay" => (0, 30),
                 "Barley" => (0, 15), "Barley.Winter" => (0, 15),
                 "Maize" => (8, 29),
                 "Sorghum" => (8, 29),
                 "Soybeans" => (5, 29),
                 "Wheat" => (0, 26), "Wheat.Winter" => (0, 26))

## Duplicates code from regress.jl
mastercounties = readtable("../../data/global/counties.csv", eltypes=[UTF8String, UTF8String, UTF8String])
masteryears = 1949:2009

for crop in keys(eddlimits)
    gddarray = zeros(1+nrow(mastercounties), length(masteryears)) * NA
    gddarray[1, :] = masteryears

    kddarray = zeros(1+nrow(mastercounties), length(masteryears)) * NA
    kddarray[1, :] = masteryears
    
    for year in masteryears
        eddfilename = "/home/jrising/Dropbox/Agriculture Weather/edds/$crop-$year.csv"
        if !isfile(eddfilename)
            continue
        end

        println(year)
        temps = readtable(eddfilename);
        if nrow(temps) < 2
            continue
        end
        temps[:fullfips] = map(fips -> isna(fips) ? "" : (fips > 10000 ? "$fips" : "0$fips"), temps[:fips])
        gdd0col = symbol("above$(eddlimits[crop][1])")
        kdd0col = symbol("above$(eddlimits[crop][2])")
        
        for rr in 1:nrow(mastercounties)
            ii = findfirst(mastercounties[rr, :fips] .== temps[:fullfips])
            if ii > 0
                gddarray[1 + rr, year - masteryears[1] + 1] = temps[ii, gdd0col] - temps[ii, kdd0col];
                kddarray[1 + rr, year - masteryears[1] + 1] = temps[ii, kdd0col];
            end
        end
    end

    writecsv("../../data/agriculture/edds/$crop-gdd.csv", gddarray)
    writecsv("../../data/agriculture/edds/$crop-kdd.csv", kddarray)
end

