##setwd("~/research/water/awash/prepare/reservoirs")

library(PBSmapping)
library(readxl)

## Load data
polys <- importShapefile("../../data/mapping/US_county_2000-simple-latlon.shp")
polydata <- attributes(polys)$PolyData

reservoirs = read_excel("All reservoir data.xlsx", 1)

## Find location of all all reservoirs
events <- data.frame(EID=1:nrow(reservoirs), X=reservoirs$lon, Y=reservoirs$lat)
events <- as.EventData(events, projection="LL")

locations <- findPolys(events, polys)

## add fips to polydata
polydata$fips <- as.numeric(as.character(polydata$NHGISST)) * 100 + as.numeric(as.character(polydata$NHGISCTY)) / 10

## add fips to reservoirs
reservoirs$fips[locations$EID] <- polydata$fips[locations$PID]

## Collect additional rez information
resdata = read_excel("reservoirs_database.xlsx", 1)

library(dplyr)
reservoirs2 <- reservoirs %>% left_join(data.frame(collection='reservoir', height=resdata$HEIGHT, normcap=resdata$NORMCAP, lat=resdata$LATDD, lon=resdata$LONDD))
reservoirs2$height.m <- reservoirs2$height * 0.3048

forfile <- reservoirs2[, c("collection", "colid", "area", "lat", "lon", "elev", "MAXCAP-m3", "fips", "height.m", "normcap")]
names(forfile) <- c("collection", "colid", "area", "lat", "lon", "elev", "MAXCAP", "fips", "height", "normcap")
write.csv(forfile, "../../data/counties/reservoirs/allreservoirs.csv", row.names=F)
