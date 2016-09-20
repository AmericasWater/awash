setwd("~/projects/water/model/awash/prepare/bystate")

source("../../rlib/load_display.R")
load("../../data/waternet.RData")

library(maps)

## Draw old network
map("state")
drawNetwork(network)

## Draw new network
newnetwork <- read.csv("newnetwork.csv")

network$gaugeid <- paste(network$collection, network$colid, sep='.')
newnetwork$lat <- NA
newnetwork$lon <- NA
newnetwork$nextpt <- NA
for (ii in 1:nrow(newnetwork)) {
    print(ii / nrow(newnetwork))
    if (newnetwork$outnode[ii] == "")
        next
    networkrow <- network[network$gaugeid == newnetwork$outnode[ii],]
    newnetwork$lat[ii] <- networkrow$lat
    newnetwork$lon[ii] <- networkrow$lon

    nextpt <- which(newnetwork$outnode == as.character(newnetwork$node[ii]))
    if (length(nextpt) == 0) {
        networkrow <- network[network$gaugeid == newnetwork$node[ii],]
        newnetwork <- rbind(newnetwork, data.frame(outnode=newnetwork$node[ii], node=NA, lat=networkrow$lat, lon=networkrow$lon, nextpt=NA))
        newnetwork$nextpt[ii] <- nrow(newnetwork)
    } else {
        newnetwork$nextpt[ii] <- nextpt
    }
}

map("state")
drawNetwork(newnetwork, xlim=c(-105, -95), ylim=c(25, 35), col=3)
