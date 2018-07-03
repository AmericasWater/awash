## Match each of the canals in canalcounties with the gauged canals
setwd("~/projects/water/network3/canals")

library(PBSmapping)
source("~/projects/research-common/R/distance.R")

data <- read.csv("canalcounties.csv")

canalshapes <- importShapefile("../../nhd/canals", readDBF=T)
proj.abbr <- attr(canals, "projection")

## Find all USGS canals that lie upon an NHD canal
canals <- read.delim("../../allusgs/canals/USGS_monthly_canals_database.txt", colClasses=c(rep("character", 3), rep("numeric", 3), "character", rep("numeric", 2)))

canals$nhdid <- NA

## Check for gauges actually within the areas
events <- data.frame(EID=1:nrow(canals), X=canals$dec_long_va, Y=canals$dec_lat_va)
events <- as.EventData(events, projection=proj.abbr)

withins <- findPolys(events, canalshapes)

canals$nhdid[withins$EID] <- withins$PID

## Check for gauges very close to canals
for (ii in 1:nrow(canals)) {
    if (!is.na(canals$nhdid[ii]))
        next

    print(ii / nrow(canals))
    dists <- gcd.slc(canals$dec_long_va[ii], canals$dec_lat_va[ii], canalshapes$X, canalshapes$Y)
    mindist <- min(dists)
    if (mindist < .2)
        canals$nhdid[ii] <- unique(canalshapes$PID[dists == mindist])
}

## Now match based on only-canal-in-county-possible
counties <- importShapefile("../../gis/USA_adm2-simple.shp", readDBF=T)
polydata <- attr(counties, "PolyData")
proj.abbr <- attr(counties, "projection")

withins <- findPolys(events, counties)

## Record everything that's been matched as much as possible
withins$drop <- withins$EID %in% which(!is.na(canals$nhdid))

data$drop <- F

## Drop all PIDs not represented at all in data
for (pid in unique(withins$PID)) {
    if (sum(data$county[!data$drop] == pid) == 0)
        withins$drop[withins$PID == pid] <- T
}

## Find all PIDs represented only once in each database
options(warn=2)
data$drop <- data$canal %in% canals$nhdid[!is.na(canals$nhdid)]
for (pid in unique(withins$PID)) {
    if (sum(withins$PID[!withins$drop] == pid) == 1 && sum(data$county[!data$drop] == pid) == 1) {
        print(pid)
        withins$drop[withins$PID == pid & !withins$drop] <- T
        canal <- data$canal[data$county == pid & !data$drop]
        data$drop[data$canal == canal] <- T
        canals$nhdid[withins$EID[withins$PID == pid]] <- canal
    }
}

rbind(table(withins$PID[!withins$drop]),
      table(data$county[!data$drop & data$county %in% unique(withins$PID[!withins$drop])]))

options(warn=0)

sum(!is.na(canals$nhdid))

## Give each canal a FIPS
canals$fips <- NA

counties <- importShapefile("../../gis/USA_adm2-simple.shp", readDBF=T)
proj.abbr <- attr(counties, "projection")
polydata <- attr(counties, "PolyData")

events <- data.frame(EID=1:nrow(canals), X=canals$dec_long_va, Y=canals$dec_lat_va)
events <- as.EventData(events, projection=proj.abbr)

withins <- findPolys(events, counties)
withins$name <- polydata$NAME_2[withins$PID]
withins$state <- polydata$NAME_1[withins$PID]

data(county.fips)

for (ii in 1:nrow(withins)) {
    if (withins$state[ii] == 'Hawaii')
        next
    polyname <- paste(tolower(withins$state[ii]), tolower(withins$name[ii]), sep=',')
    polyname <- gsub(",saint ", ",st ", polyname)

    if (polyname == "texas,galveston")
        polyname <- "texas,galveston:main"
    if (polyname == "indiana,laporte")
        polyname <- "indiana,la porte"
    if (polyname == "district of columbia,district of columbia")
        polyname <- "district of columbia,washington"
    if (polyname == "louisiana,st martin")
        polyname <- "louisiana,st martin:north"
    if (polyname == "mississippi,desoto")
        polyname <- "mississippi,de soto"
    if (polyname == "new mexico,debaca")
        polyname <- "new mexico,de baca"
    if (polyname == "washington,pierce")
        polyname <- "washington,pierce:main"

    fips <- county.fips$fips[county.fips$polyname == polyname]
    if (length(fips) == 0) {
        if (!grepl("lake ", polyname) && polyname != "virginia,chesapeake")
            print(c(polyname, ii))
        next
    }
    withins$fips[ii] <- fips
}

canals$fips[withins$EID] <- withins$fips

## Create canals-to-county mapping

load("../waternet.RData")

## multiple fips may exist for a single source, if a canal flows through multiple counties
## multiple sources may feed a single fips, if there are multiple canals in a county
## creation may be one of 'nhd', 'usgs', 'infer'
extracts <- data.frame(netsource=c(), fips=c(), creation=c())

for (ii in 1:nrow(canals)) {
    ## Get this network source
    netsource <- which(network$collection == 'canal' & network$colid == canals$site_no[ii])
    if (length(netsource) == 0) {
        print(paste("Could not find", ii))
        next
    }

    fipses <- c()
    creations <- c()

    if (!is.na(canals$fips[ii])) {
        fipses <- canals$fips[ii]
        creations <- "within"
    }

    if (!is.na(canals$nhdid[ii])) {
        fipses2 <- data$fips[data$canal == canals$nhdid[ii]]
        creations2 <- rep("nhd", length(fipses2))

        if (length(fipses) > 0 && fipses %in% fipses2) {
            if (which(fipses2 == fipses) == 1) {
                creations <- c(creations, creations2[fipses2 != fipses])
                fipses <- c(fipses, fipses2[fipses2 != fipses])
            } else if (which(fipses2 == fipses) == length(fipses2)) {
                creations <- c(creations2[fipses2 != fipses], creations)
                fipses <- c(fipses2[fipses2 != fipses], fipses)
            } else {
                creations2[fipses2 != fipses] <- creations
                creations <- creations2
                fipses <- fipses2
            }
        } else {
            fipses <- c(fipses, fipses2)
            creations <- c(creations, creations2)
        }
    }

    if (length(fipses) > 0)
        extracts <- rbind(extracts, data.frame(netsource, fips=fipses, creation=creations))
}

## Get centroid for each fips
library(maps)

counties <- map("county", plot=F, fill=T)

data(county.fips)

counties$x <- c(counties$x, NA)
counties$y <- c(counties$y, NA)

nas <- which(is.na(counties$x))
startii <- 1

info <- data.frame(name=c(), fips=c(), cent.x=c(), cent.y=c())
for (nai in 1:length(nas)) {
  print(nai/length(nas))
  shape <- data.frame(PID=1, X=counties$x[startii:(nas[nai]-1)], Y=counties$y[startii:(nas[nai]-1)])

  if (nrow(shape) == 1)
    centroid <- shape
  else if (nrow(shape) == 2)
    centroid <- data.frame(X=mean(shape$X), Y=mean(shape$Y))
  else {
    shape$POS <- 1:nrow(shape)
    centroid <- calcCentroid(shape, 1)
  }

  fips <- county.fips$fips[county.fips$polyname == counties$names[nai] & !is.na(counties$names[nai])]
  if (length(fips) == 0)
    fips <- NA

  info <- rbind(info, data.frame(name=counties$names[nai], fips=fips, cent.x=centroid$X, cent.y=centroid$Y))

  startii <- nas[nai] + 1
}

extracts$cent.x <- NA
extracts$cent.y <- NA
for (ii in 1:nrow(extracts)) {
    extracts$cent.x[ii] <- info$cent.x[info$fips == extracts$fips[ii]][1]
    extracts$cent.y[ii] <- info$cent.y[info$fips == extracts$fips[ii]][1]
}

write.csv(extracts, "nhd-canals.csv", row.names=F)

## Draw it!
pdf("canalnetwork.pdf", width=10, height=7)

map("county", fill=T, col="#C0A0A0", border="#F0C0C0", lwd=.5)
map("state", col="yellow", lwd=.5, add=T)
for (ii in 1:nrow(network)) {
  if (!is.na(network$nextpt[ii])) {
    downstream <- network[network$nextpt[ii],]
    lines(c(network$lon[ii], downstream$lon), c(network$lat[ii], downstream$lat), col="#00000080")
  }
}
for (netsource in unique(extracts$netsource)) {
    thissource <- extracts[extracts$netsource == netsource,]
    if (gcd.slc(thissource$cent.x[1], thissource$cent.y[1], network$lon[netsource], network$lat[netsource]) > 1000) {
        print(paste("More than 100 km!", netsource))
        next
    }
    lines(c(network$lon[netsource], thissource$cent.x), c(network$lat[netsource], thissource$cent.y), col=min(nrow(thissource) + 1, 3))
}

dev.off()

