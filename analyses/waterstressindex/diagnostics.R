setwd("~/research/water/awash/analyses/waterstressindex")

for (filename in list.files(".", ".*?monthly.*?\\.csv")) {
    df <- read.csv(filename)
    df$mytime <- df$startyear + (df$time - .5) / 12
    print(c(filename, max(table(df$mytime))))
}

df <- read.csv("stress-monthly-withres.csv")
df$mytime <- df$startyear + (df$time - .5) / 12
tbl <- table(df$mytime)
names(tbl)[tbl > 3109]

setwd("~/research/water/awash/analyses/waterstressindex")
df <- read.csv("stress-monthly-withres.csv")

## Check total amount of water

setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)
library(ncdf4)
library(reshape2)

df <- read.csv("demands.csv")
df <- subset(df, scale == "monthly")
df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"), by=c('fips'='FIPS'))

ncin <- nc_open("../../data/cache/counties/VIC_WB.nc")
ncfips <- ncvar_get(ncin, "state_fips") * 1000 + ncvar_get(ncin, "county_fips")
ncflow <- ncvar_get(ncin, "runoff") + ncvar_get(ncin, "baseflow")

flowdf <- melt(ncflow)
names(flowdf) <- c('timestep', 'cc', 'flowmm')
flowdf$fips <- ncfips[flowdf$cc]

df$fips <- as.numeric(df$fips)
df2 <- df %>% left_join(flowdf)
## mm * mi2 * k km2 / mi2 * (1000 m / km)^2 * m / 1000 mm = m^3
df2$flow <- df2$flowmm * df2$TotalArea_sqmi * 2.58999 # 1000 m^3

ncin2 <- nc_open("../../data/cache/counties/contributing_runoff_by_gage.nc")
ncflow2 <- ncvar_get(ncin2, "runoff") + ncvar_get(ncin2, "baseflow")

flowdf2 <- melt(ncflow2)
names(flowdf2) <- c('gg', 'timestep', 'flowmm')
areas <- ncvar_get(ncin2, 'contributing_area')
flowdf2$flow <- flowdf2$flowmm * areas[flowdf2$gg]

df3 <- df2 %>% group_by(timestep) %>% summarize(flow=sum(flow, na.rm=T))
flowdf3 <- flowdf2 %>% group_by(timestep) %>% summarize(flow=sum(flow, na.rm=T))

df4 <- df3 %>% left_join(flowdf3, by='timestep', suffix=c('state', 'gauge'))

library(ggplot2)

ggplot(df4, aes(flowstate, flowgauge)) +
    geom_point() + geom_abline(yintercept=0, slope=1)

## Figure out where there's less flow
flowdf2.byf <- flowdf2 %>% group_by(gg) %>% summarize(flowmm=mean(flowmm, na.rm=T))
flowdf2.byf$lat <- ncvar_get(ncin2, "gage_latitude")[flowdf2.byf$gg]
flowdf2.byf$lon <- ncvar_get(ncin2, "gage_longitude")[flowdf2.byf$gg]

ggplot(flowdf2.byf, aes(lon, lat, colour=flowmm)) +
    geom_point()

map.county <- map_data('county')
map.county$polyname <- paste(map.county$region, map.county$subregion, sep=',')
shp.county <- data.frame(PID=map.county$group, POS=map.county$order, X=map.county$long, Y=map.county$lat)

library(PBSmapping)
events <- as.EventData(data.frame(EID=1:nrow(flowdf2.byf), X=flowdf2.byf$lon, Y=flowdf2.byf$lat), projection=1)
found <- findPolys(events, shp.county)

flowdf2.byf$polyname <- NA
flowdf2.byf$polyname[found$EID] <- map.county$polyname[found$PID]

flowdf2.byf2 <- flowdf2.byf %>% left_join(county.fips)

df2.bys <- df2 %>% group_by(fips) %>% summarize(flowmm=mean(flowmm, na.rm=T))

flowdf2.byf3 <- flowdf2.byf2 %>% left_join(df2.bys, by='fips', suffix=c('gauge', 'county'))

ggplot(flowdf2.byf3, aes(flowmmgauge, flowmmcounty)) +
    geom_point() + geom_abline(yintercept=0, slope=1)
