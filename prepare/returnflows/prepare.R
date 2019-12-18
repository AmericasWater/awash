setwd("~/research/water/awash/prepare/returnflows")

library(ggplot2)
library(raster)
library(dplyr)

df <- read.csv("us-soils.csv")
ggplot(df, aes(lon, lat, fill=top.ksat)) +
    geom_raster() + theme_bw() + scale_x_continuous(expand=c(0, 0)) +
    scale_y_continuous(expand=c(0, 0)) + scale_fill_continuous(name="Ksat\n(lower layer)")

## Fill in the missing pieces with mean
df2 <- expand.grid(lon=seq(-124.848974, -66.885444, by=1/12.), lat=seq(24.396308, 49.384358, by=1/12.))
df2$rc <- paste(round(12*df2$lon), round(12*df2$lat))
df$rc <- paste(round(12*df$lon), round(12*df$lat))

df3 <- df2 %>% left_join(df, by='rc')
df3$top.ksat[is.na(df3$top.ksat)] <- mean(df$top.ksat)

et <- raster("julyet.asc")
et <- as.data.frame(et, xy=T)

df3$rc <- paste(round(2*df3$lon.x - .5), round(2*df3$lat.x - .5))
et$rc <- paste(round(2*et$x - .5), round(2*et$y - .5))

df4 <- df3 %>% left_join(et)

## ksat and et are both in mm/day
## assume that there is another term
## Q = ET*T + RF*T + X*T
## RF / Q = RF / (ET + RF + X)
## Want mean to equal known value, so mean(RF / (ET + RF + X)) = RF0
irrmethod <- c('Gravity', 'Sprinkler', 'Efficient')
lorfracs <- c(.15, .05, 0)
hirfracs <- c(.5, .15, .1)

for (ii in 1:3) {
    sol <- optim(c(1, 1), function(xx) sum(abs(range((df4$top.ksat + xx[1]) / (df4$top.ksat + df4$julyet + xx[2]), na.rm=T) - c(lorfracs[ii], hirfracs[ii]))))

    print(sol$par)
    print(range((df4$top.ksat + sol$par[1]) / (df4$top.ksat + df4$julyet + sol$par[2]), na.rm=T))

    df4[, irrmethod[ii]] <- (df4$top.ksat + sol$par[1]) / (df4$top.ksat + df4$julyet + sol$par[2])
}

ggplot(df4, aes(lon.x, lat.x, fill=Gravity)) +
    geom_raster() + theme_bw() + scale_x_continuous(name=NULL, expand=c(0, 0)) +
    scale_y_continuous(name=NULL, expand=c(0, 0)) + scale_fill_continuous(name="Return Flow") +
    borders("usa", colour='black')

## Classify each point by state

library(PBSmapping)
shp <- importShapefile("../../data/mapping/tl_2010_us_state00/tl_2010_us_state00.shp")
polydata <- attr(shp, "PolyData")

events <- as.EventData(data.frame(EID=1:nrow(df4), X=df4$lon.x, Y=df4$lat.x), projection=1)
found <- findPolys(events, shp, maxRows=1e6)

## Find the share of irrigation by state

irrshares <- read.csv("irrigation-methods.csv")
irrshares$mytotal <- irrshares$Gravity + irrshares$Sprinkler + irrshares$Efficient

df4$avg <- NA
for (pid in 1:nrow(polydata)) {
    ii <- which(irrshares$State == as.character(polydata$NAME00[pid]))
    if (length(ii) != 1) {
        print(paste("Missing state", polydata$NAME00[pid], pid))
        next
    }

    rows <- found$EID[found$PID == pid]
    df4$avg[rows] <- (df4$Gravity[rows] * irrshares$Gravity[ii] + df4$Sprinkler[rows] * irrshares$Sprinkler[ii] + df4$Efficient[rows] * irrshares$Efficient[ii]) / irrshares$mytotal[ii]
}

ggplot(df4, aes(lon.x, lat.x, fill=avg)) +
    geom_raster() + theme_bw() + scale_x_continuous(name=NULL, expand=c(0, 0)) +
    scale_y_continuous(name=NULL, expand=c(0, 0)) + scale_fill_continuous(name="Return Flow") +
    borders("usa", colour='black')

## Below mean rf from USGS -- improvements?

write.csv(df4, "returnflow.csv", row.names=F)

spg <- df4[, c('lon.x', 'lat.x', 'avg')]
coordinates(spg) <- ~ lon.x + lat.x
gridded(spg) <- T
rasterDF <- raster(spg)
writeRaster(rasterDF, "returnflow.bil", format="EHdr", overwrite=T)

## Generate county and state averages

results <- data.frame()
for (pid in 1:nrow(polydata)) {
    rows <- found$EID[found$PID == pid]
    rfmean <- mean(df4$avg[rows], na.rm=T)
    results <- rbind(results, data.frame(ST=polydata$STUSPS00[pid], State=polydata$NAME00[pid], rfmean))
}

write.csv(results, "../../data/states/returnflows/returnfracs.csv", row.names=F)

shp <- importShapefile("../../data/mapping/US_county_2000-simple-latlon.shp")
polydata <- attr(shp, "PolyData")

found <- findPolys(events, shp, maxRows=1e6)

results <- data.frame()
for (pid in 1:nrow(polydata)) {
    rows <- found$EID[found$PID == pid]
    rfmean <- mean(df4$avg[rows], na.rm=T)
    results <- rbind(results, data.frame(FIPS=as.numeric(as.character(polydata$STATE[pid])) * 100 + as.numeric(as.character(polydata$COUNTY[pid])) / 10, County=polydata$ICPSRNAM[pid], State=polydata$STATENAM[pid], rfmean))
}

write.csv(results, "../../data/counties/returnflows/returnfracs.csv", row.names=F)
