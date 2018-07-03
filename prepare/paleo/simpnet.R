setwd("~/research/water/paleo")

load("monthly.disaggregation.RData")
load("../awash/data/counties/waternet/waternet.RData")
reservoirs <- read.csv("~/research/water/awash/data/counties/reservoirs/allreservoirs.csv")

source("~/research/water2/network3/load_navigate.R")

stations$collection <- as.character(stations$collection)
network$collection <- as.character(network$collection)

new.stations <- data.frame(collection=c(), colid=c(), area=c(), lat=c(), lon=c(), elev=c())
new.reservoirs <- data.frame(collection=c(), colid=c(), area=c(), lat=c(), lon=c(), elev=c(), MAXCAP=c())

skip.junctions <- c() # Can I skip all junctions below this
for (colid in colnames(DISAGG)[-1:-2]) {
    print(colid)
    areadf <- follow.upstream("usgs", colid, Inf, function(curr.col, curr.cid, next.coll, next.cid) {
        if (is.null(next.coll)) # Nothing higher
            return(NULL)
        next.coll <- as.character(next.coll)
        next.cid <- as.character(next.cid)
        if (next.coll == "usgs" && next.cid %in% colnames(DISAGG)) {
            skip.junctions <<- c(skip.junctions, next.cid) # Yes: go straight from gauge to gauge
            return(NULL)
        } else {
            if (sum(reservoirs$collection == next.coll & reservoirs$colid == next.cid) == 1) {
                row <- which(reservoirs$collection == next.coll & reservoirs$colid == next.cid)
                return(data.frame(area=reservoirs$area[row], maxcap=reservoirs$MAXCAP[row]))
            } else if (sum(stations$collection == next.coll & stations$colid == next.cid) == 1) {
                return(data.frame(area=stations$area[stations$collection == next.coll & stations$colid == next.cid], maxcap=0))
            } else
                return(data.frame(area=NA, maxcap=0))
        }
    })

    old.station <- stations[stations$collection == "usgs" & stations$colid == colid,]
    if (class(areadf) == "logical")
        new.stations <- rbind(new.stations, data.frame(collection="usgs", colid, area=old.station$area, lat=old.station$lat, lon=old.station$lon, elev=old.station$elev))
    else {
        new.stations <- rbind(new.stations, data.frame(collection="usgs", colid, area=sum(areadf$area), lat=old.station$lat, lon=old.station$lon, elev=old.station$elev))
        if (areadf$maxcap > 0)
            new.reservoirs <- rbind(new.reservoirs, data.frame(collection="usgs", colid, area=sum(areadf$area), lat=old.station$lat, lon=old.station$lon, elev=old.station$elev, MAXCAP=areadf$maxcap))
    }
}

new.network <- data.frame(collection="usgs", colid=new.stations$colid, lat=new.stations$lat, lon=new.stations$lon, elev=new.stations$elev, nextpt=NA, dist=NA)

for (colid in colnames(DISAGG)[-1:-2]) {
    do.skip.junctions <- colid %in% skip.junctions
    print(c(colid, nrow(new.network)))

    totaldist <- 0
    extracap <- 0
    parent.col <- "usgs"
    parent.cid <- colid
    follow.downstream("usgs", colid, Inf, function(curr.col, curr.cid, next.coll, next.cid) {
        station <- network[network$collection == parent.col & network$colid == parent.cid,]
        totaldist <<- totaldist + network$dist[network$collection == curr.col & network$colid == curr.cid]

        if (is.null(next.coll)) {
            if (sum(new.network$collection == parent.col & new.network$colid == parent.cid) == 0)
                new.network <<- rbind(new.network, data.frame(collection=parent.col, colid=parent.cid, lat=station$lat, lon=station$lon, elev=NA, nextpt=NA, dist=NA))
            return(NA) # STOP
        }

        next.coll <- as.character(next.coll)
        next.cid <- as.character(next.cid)

        if (next.coll == "usgs" && next.cid %in% colnames(DISAGG)) {
            nextpt <- which(new.stations$collection == "usgs" & new.stations$colid == next.cid)
            if (sum(new.network$collection == parent.col & new.network$colid == parent.cid) == 1) {
                new.network$nextpt[new.network$collection == parent.col & new.network$colid == parent.cid] <<- nextpt
                new.network$dist[new.network$collection == parent.col & new.network$colid == parent.cid] <<- totaldist
            } else
                new.network <<- rbind(new.network, data.frame(collection=parent.col, colid=parent.cid, lat=station$lat, lon=station$lon, elev=NA, nextpt, dist=totaldist))
            return(NA) # Stop
        }
        if (!do.skip.junctions && next.coll == "junction") {
            if (sum(new.network$collection == "junction" & new.network$colid == next.cid) == 1) {
                ## Already added!
                nextpt <- which(new.network$collection == "junction" & new.network$colid == next.cid)
                if (sum(new.network$collection == parent.col & new.network$colid == parent.cid) == 1) {
                    new.network$nextpt[new.network$collection == parent.col & new.network$colid == parent.cid] <<- nextpt
                    new.network$dist[new.network$collection == parent.col & new.network$colid == parent.cid] <<- totaldist
                } else
                    new.network <<- rbind(new.network, data.frame(collection=parent.col, colid=parent.cid, lat=station$lat, lon=station$lon, elev=NA, nextpt, dist=totaldist))
                return(NA) # Stop
            } else {
                if (sum(new.network$collection == parent.col & new.network$colid == parent.cid) == 1) {
                    new.network$nextpt[new.network$collection == parent.col & new.network$colid == parent.cid] <<- nrow(new.network) + 1
                    new.network$dist[new.network$collection == parent.col & new.network$colid == parent.cid] <<- totaldist
                } else {
                    new.network <<- rbind(new.network, network[network$collection == parent.col & network$colid == parent.cid,])
                    new.network$nextpt[nrow(new.network)] <<- nrow(new.network) + 1
                    new.network$dist[nrow(new.network)] <<- totaldist
                }

                totaldist <<- 0
                parent.col <<- next.coll
                parent.cid <<- next.cid
                return(NULL) # Continue with new parent
            }
        }
        if (!do.skip.junctions & sum(reservoirs$collection == next.coll & reservoirs$colid == next.cid) == 1) {
            extracap <<- extracap + reservoirs$MAXCAP[reservoirs$collection == next.coll & reservoirs$colid == next.cid]
        }
        return(NULL) # Continue with new parent
    })

    if (extracap > 0)
        reservoirs$MAXCAP[reservoirs$collection == "usgs" & reservoirs$colid == colid] <- reservoirs$MAXCAP[reservoirs$collection == "usgs" & reservoirs$colid == colid] + extracap
}

## Assert that dists and nextpt match
##new.network[!is.na(new.network$dist) & is.na(new.network$nextpt),]
##new.network[!is.na(new.network$nextpt) & is.na(new.network$dist),]

stations = new.stations
network = new.network

save(stations, network, file="paleonetwork.RData")
write.csv(new.reservoirs, "paleoreservoirs.csv", row.names=F)

