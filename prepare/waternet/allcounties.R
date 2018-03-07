### Construct a list of all of the network sources that can feed into
### each county

include.canals <- F

setwd("~/research/water/awash6/prepare/waternet")
source("add-county.R") # generates info data.frame
source("distance.R")

load("../../data/paleo/waternet/waternet.RData")

## Put connection between counties and all nodes within them
county.names <- map.where("county", network$lon, network$lat)
## Correct a couple locations
county.names[which(county.names == "missouri,ste genevieve")] <- "missouri,saline"
county.names[which(county.names == "missouri,shelby")] <- "missouri,butler"
county.names[which(county.names == "missouri,shannon")] <- "missouri,shelby"
county.names[which(county.names == "missouri,sullivan")] <- "missouri,taney"
county.names[which(county.names == "missouri,stone")] <- "missouri,sullivan"
county.names[which(county.names == "missouri,stoddard")] <- "missouri,stone"
county.names[which(county.names == "missouri,texas")] <- "missouri,vernon"
county.names[which(county.names == "missouri,wright")] <- "missouri,st louis"
county.names[which(county.names == "missouri,scott")] <- "missouri,shannon"
county.names[which(county.names == "missouri,webster")] <- "missouri,X"
county.names[which(county.names == "missouri,worth")] <- "missouri,webster"
county.names[which(county.names == "missouri,X")] <- "missouri,worth"

draws <- data.frame(fips=c(), source=c(), justif=c(), downhill=c(), exdist=c())
info$count <- 0 # the number of sources

for (ii in 1:nrow(info)) {
    print(ii / nrow(info))
    county.rows <- which(county.names == info$name[ii])
    if (length(county.rows) == 0)
        next

    ## Only take those less than 200 km away (one buggy county!)
    if (max(gcd.slc(info$cent.x[ii], info$cent.y[ii], network$lon[county.rows], network$lat[county.rows])) > 200) {
        print(paste("Long distance at", ii)) # these counties moved!
        next
    }

    draws <- rbind(draws, data.frame(fips=info$fips[ii], source=county.rows, justif="contains", downhill=info$elev[ii] < network$elev[county.rows], exdist=0))
}

if (include.canals) {
    canals <- read.csv("canalnetwork.csv")

    draws <- rbind(draws, data.frame(fips=canals$fips, source=canals$netsource,
                                     justif=paste0('canal-', canals$creation),
                                     downhill=NA, exdist=0))
}

## For all others, make a pipe
for (ii in 1:nrow(info)) {
    info$count[ii] <- sum(draws$fips == info$fips[ii])
    if (info$count[ii] > 0)
        next
    print(ii / nrow(info))

    valids <- subset(network, elev > info$elevation[ii])
    dists <- gcd.slc(info$cent.x[ii], info$cent.y[ii], valids$lon, valids$lat)
    closest <- min(dists)

    if (closest < 100) {
        source <- as.numeric(row.names(valids)[which(dists == closest)])
        draws <- rbind(draws, data.frame(fips=info$fips[ii], source, justif="down-pipe", downhill=T, exdist=closest))
    } else {
        dists <- gcd.slc(info$cent.x[ii], info$cent.y[ii], network$lon, network$lat)
        closest <- min(dists)
        draws <- rbind(draws, data.frame(fips=info$fips[ii], source=which(dists == closest), justif="up-pipe", downhill=F, exdist=closest))
    }
}

## Drop two known bad
draws <- draws[!(draws$fips == 4001 & draws$source %in% c(12241, 11805)),]

draws$justif <- factor(draws$justif)

png("network-county.png", width=1000, height=700)

map("county", fill=T, col="#A08080", border="white", lwd=.1)
map("state", col="yellow", lwd=.5, add=T)
for (ii in 1:nrow(info)) {
    if (info$count[ii] == 0)
        map("county", info$name[ii], fill=T, col="#F08080", lwd=.1, add=T)
}
for (ii in 1:nrow(network)) {
  if (!is.na(network$nextpt[ii])) {
    downstream <- network[network$nextpt[ii],]
    lines(c(network$lon[ii], downstream$lon), c(network$lat[ii], downstream$lat))
  }
}
for (ii in 1:nrow(draws)) {
    county <- info[info$fips == draws$fips[ii],]
    upstream <- network[draws$source[ii],]
    lines(c(county$cent.x, upstream$lon), c(county$cent.y, upstream$lat), col=as.numeric(draws$justif[ii])+1)
}

dev.off()

save(draws, file="../../data/paleo/waternet/countydraws.RData")

