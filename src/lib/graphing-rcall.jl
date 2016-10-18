using RCall

mapinited = false

"""
df must have columns fips and the value column.
"""
function usmap(df, centered=false)
    global mapinited
    if !mapinited
        RCall.ijulia_setdevice(MIME("image/png"),width=8*72,height=5*72)
        R"library(ggplot2)"
        R"library(PBSmapping)"
        R"shapes <- importShapefile('../data/mapping/US_county_2000-simple')"
        R"polydata <- attributes(shapes)$PolyData"
        R"polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]"
        R"polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]"
        R"shapes$id <- polydata$STATE[shapes$PID] * 100 + polydata$COUNTY[shapes$PID] / 10";
        R"names(shapes) <- tolower(names(shapes))";

        mapinited = true
    end
    
    if centered
        R"ggplot($df, aes(map_id=fips)) +
        geom_map(aes(fill=value), map=shapes) +
        expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
        theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('') +
        scale_fill_gradient2()"
    else
        R"ggplot($df, aes(map_id=fips)) +
        geom_map(aes(fill=value), map=shapes) +
        expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
        theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')"
    end
end
