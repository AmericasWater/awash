using DataFrames
using DataArrays
using ExcelReaders

regabbrs = ["us", "nc", "hl", "np", "pg", "mp", "ss", "br", "fr", "eu"]
crops = ["corn", "soyb", "whea", "sorg", "barl"] #"cott", "rice", "oats", "pean"

df = DataFrame(crop=[], region=[], item=[], year=[], value=[])

for crop in crops
    for region in regabbrs
        filename = download("https://www.ers.usda.gov/webdocs/DataFiles/47913/r$region$crop.xls?v=42856")
        for sheet in 1:5
            println("Sheet $sheet")
            data = try
                readxlsheet(filename, sheet)
            catch
                []
            end
            for col in 2:size(data, 2)
                year = data[3, col]
                for row in 4:size(data, 1)
                    if !isna(data[row, 1]) && typeof(data[row, col]) == Float64
                        item = strip(replace(data[row, 1], r"\d+/", ""))
                        value = data[row, col]

                        push!(df, [crop, region, item, year, value])
                    end
                end
            end
        end
    end
end

df[df[:item] .== "Total,  operating costs", :item] = "Total, operating costs"
df[df[:item] .== "Total costs listed", :item] = "Total, costs listed"
df[df[:item] .== "Price (dollars per bushedl at harvest)", :item] = "Price (dollars per bushel at harvest)"
df[df[:item] .== "Opportunity cost of land(rental rate)", :item] = "Opportunity cost of land"
df[df[:item] .== "Opportunity cost of land (rental rate)", :item] = "Opportunity cost of land"
df[df[:item] .== "Price (dollars per bu at harvest)", :item] = "Price (dollars per bushel at harvest)"

unique(df[:item])

writetable("../../../data/global/ers.csv", df)
