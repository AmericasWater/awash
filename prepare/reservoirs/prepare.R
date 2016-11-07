##setwd("~/research/water/model/awash/prepare/reservoirs")

library(PBSmapping)
library(xlsx)

## Load data
polys <- importShapefile("../../data/mapping/US_county_2000-simple-latlon.shp")
polydata <- attributes(polys)$PolyData

reservoirs = read.xlsx("All reservoir data.xlsx", 1)

## Find location of all all reservoirs
events <- data.frame(EID=1:nrow(reservoirs), X=reservoirs$lon, Y=reservoirs$lat)
events <- as.EventData(events, projection="LL")

locations <- findPolys(events, polys)

## add fips to polydata
polydata$fips <- as.numeric(as.character(polydata$NHGISST)) * 100 + as.numeric(as.character(polydata$NHGISCTY)) / 10

## add fips to reservoirs
reservoirs$fips[locations$EID] <- polydata$fips[locations$PID]

forfile <- reservoirs[, c("collection", "colid", "area", "lat", "lon", "elev", "MAXCAP.m3", "fips")]
names(forfile) <- c("collection", "colid", "area", "lat", "lon", "elev", "MAXCAP", "fips")
write.csv(forfile, "../../data/reservoirs/allreservoirs.csv", row.names=F)
