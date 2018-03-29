setwd("~/projects/water/network3/canals")

library(PBSmapping)

##canals <- importShapefile("../../nhd/canals", readDBF=T)
canals <- importShapefile("../../nhd/canals-simple", readDBF=T)
proj.abbr <- attr(canals, "projection")

plotMap(canals, projection=proj.abbr, border="gray",
    xlab="Longitude", ylab="Latitude")

events <- data.frame(EID=1:nrow(canals), X=canals$X, Y=canals$Y)
events <- as.EventData(events, projection=proj.abbr)

##counties <- importShapefile("../../reag/year2000/US_county_2000.shp", readDBF=T)
counties <- importShapefile("../../gis/USA_adm2-simple.shp", readDBF=T)
polydata <- attr(counties, "PolyData")

withins <- findPolys(events, counties)

data <- data.frame(canal=c(), county=c())

for (pid in unique(canals$PID)) {
    print(pid)
    within <- withins[withins$EID %in% which(canals$PID == pid),]

    pids <- unique(within$PID)
    if (length(pids) <= 1)
        next

    print(length(pids))
    data <- rbind(data, data.frame(canal=pid, county=pids))
}

data$stateid <- polydata$ID_1[data$county]
data$name <- polydata$NAME_2[data$county]

## Associate canalcounties with FIPS
library(maps)

data(county.fips)

data$fips <- NA
for (ii in 1:nrow(data)) {
    statename <- tolower(polydata$NAME_1[polydata$PID == data$county[ii]])
    polyname <- paste(statename, tolower(data$name[ii]), sep=',')
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

    fips <- county.fips$fips[county.fips$polyname == polyname]
    if (length(fips) == 0) {
        if (!grepl("lake ", polyname) && polyname != "virginia,chesapeake")
            print(c(polyname, ii))
        next
    }
    data$fips[ii] <- fips
}

## Drop all with NA (these are draining canals) and see if still have 2
for (ii in which(is.na(data$fips)))
    if (sum(data$canal == data$canal[ii]) == 2)
        data$fips[data$canal == data$canal[ii]] <- NA

data <- data[!is.na(data$fips),]

write.csv(data, "canalcounties.csv", row.names=F)
