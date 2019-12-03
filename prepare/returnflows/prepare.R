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
meanrf <- 1 - 0.607
sol <- optim(1, function(x) abs(mean(df4$top.ksat / (df4$top.ksat + df4$julyet + x), na.rm=T) - meanrf))

df4$rf <- df4$top.ksat / (df4$top.ksat + df4$julyet + sol$par)

ggplot(df4, aes(lon.x, lat.x, fill=rf)) +
    geom_raster() + theme_bw() + scale_x_continuous(name=NULL, expand=c(0, 0)) +
    scale_y_continuous(name=NULL, expand=c(0, 0)) + scale_fill_continuous(name="Return Flow") +
    borders("usa", colour='black')

write.csv(df4, "returnflow.csv", row.names=F)

spg <- df4[, c('lon.x', 'lat.x', 'rf')]
coordinates(spg) <- ~ lon.x + lat.x
gridded(spg) <- T
rasterDF <- raster(spg)
writeRaster(rasterDF, "returnflow.bil", format="EHdr")
