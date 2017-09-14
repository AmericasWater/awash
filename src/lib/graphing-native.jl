using Gadfly, Shapefile, DataFrames

"""
df must have columns fips and the value column.
"""
function usmap(df, centered=false)
    # The start of such an implementation; note: fails on James's machine
    shp = open(datapath("mapping/US_county_2000-simple.shp")) do fd
        read(fd, Shapefile.Handle)
    end

    attrs = readtable(datapath("mapping/US_county_2000-simple.csv"))
    attrs[:fips] = attrs[:STATE] * 100 + attrs[:COUNTY] / 10
    attrs[:fips][isna.(attrs[:fips])] = 0

    xxs = []
    yys = []
    groups = []
    colors = []
    shapeii = 1
    for shape in shp.shapes
        row = findfirst(df[:fips] .== attrs[shapeii, :fips])
        if row > 0
            append!(xxs, map(pt -> pt.x, shape.points))
            append!(yys, map(pt -> pt.y, shape.points))
            append!(groups, map(pt -> shapeii, shape.points))
            append!(colors, map(pt -> df[row, :value], shape.points))
        end
        shapeii += 1
    end

    plot(x=xxs, y=yys, group=groups, color=colors,
         Geom.polygon(preserve_order=true, fill=true))
end

function xyplot(xx, yy, xlab, ylab)
    Gadfly.plot(x=xx, y=yy, Guide.xlabel(xlab), Guide.ylabel(ylab))
end
