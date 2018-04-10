using RCall

mapinited = false
ggplotinited = false

"""
df must have columns fips and the value column.
"""
function usmap(df, centered=nothing)
    global mapinited

    toshapefile = datapath("mapping/US_county_2000-simple")
    tostateshapefile = datapath("mapping/tl_2010_us_state00/tl_2010_us_state00-simple")

    if !mapinited
        #RCall.ijulia_setdevice(MIME("image/png"),width=8*72,height=5*72)
        R"library(ggplot2)"
        R"library(PBSmapping)"
        R"shapes <- importShapefile($toshapefile)"
        R"polydata <- attributes(shapes)$PolyData"
        R"polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]"
        R"polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]"
        R"shapes$id <- polydata$STATE[shapes$PID] * 100 + polydata$COUNTY[shapes$PID] / 10";
        R"names(shapes) <- tolower(names(shapes))";
        R"stateshapes <- importShapefile($tostateshapefile)"
        R"statespolydata <- attributes(stateshapes)$PolyData"
        R"stateshapes$x <- stateshapes$X"
        R"stateshapes$y <- stateshapes$Y"
        R"stateshapes$id <- stateshapes$PID"

        mapinited = true
    end

    R"df = $df"
    R"df$fips = as.numeric(df$fips)"
    if (centered==true) || (centered!=false) || (R"sum(df$value<0)>0 & sum(df$value>0)>0"[1] == 1)  
        R"ggplot(df) +
        geom_map(aes(fill=value, map_id=fips), map=shapes) +
        geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
        expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
        theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('') +
        scale_fill_gradient2()"
    else
        R"ggplot(df) +
        geom_map(aes(fill=value, map_id=fips), map=shapes) +
        geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
        expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
        theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')"
    end
end

function xyplot(xx, yy, title, xlab, ylab, size=1)
    global ggplotinited

    if !mapinited
        #RCall.ijulia_setdevice(MIME("image/png"),width=8*72,height=5*72)
        R"library(ggplot2)"
    end

    df = DataFrame(x=xx, y=yy, size=size)
    R"library(ggplot2)"
    R"ggplot($df, aes(x, y, size=size)) +
geom_point() + xlab($xlab) + ylab($ylab) + ggtitle($title) + theme_bw()"
end

