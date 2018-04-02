library(dplyr)
library(ggplot2)
library(ggmap)
library(maps)
library(maptools)
library(tmap)      # package for plotting
library(readxl)    # for reading Excel
library(tmaptools) 
data(wrld_simpl)
setwd('C:/Users/luc/Desktop/awash/analyses/climatevariability/analyzereservoir/')
time_ind0 <- 1:10
dir.create('plots', showWarnings=F)
# - county fips, state fips, region indexes
mastercounties <- read.csv("../../../data/global/counties.csv")
fips <- matrix(mastercounties$fips, nrow = 3109, ncol = length(time_ind0)) %>% as.vector()
time_ind <- t(matrix(time_ind0, nrow = length(time_ind0), ncol = 3109)) %>% as.vector() %>% as.factor()
state_ind <- matrix(mastercounties$state, nrow = 3109, ncol = max(time_ind0)) %>% as.vector()
region_ind <- state_ind
region_ind[which(region_ind %in% c("CT", "ME", "MA", "NH", "RI", "VT"))] <- "I"
region_ind[which(region_ind %in% c("NJ", "NY"))] <- "II"
region_ind[which(region_ind %in% c("DE", "DC", "MD", "PA", "VA", "WV"))] <- "III"
region_ind[which(region_ind %in% c("AL", "FL", "GA", "KY", "MS", "NC", "SC", "TN"))] <- "IV"
region_ind[which(region_ind %in% c("IL", "IN", "MI", "MN", "OH", "WI"))] <- "V"
region_ind[which(region_ind %in% c("AR", "LA", "NM", "OK", "TX"))] <- "VI"
region_ind[which(region_ind %in% c("IA", "KS", "MO", "NE"))] <- "VII"
region_ind[which(region_ind %in% c("CO", "MT", "ND", "SD", "UT", "WY"))] <- "VIII"
region_ind[which(region_ind %in% c("AZ", "CA", "NV"))] <- "IX"
region_ind[which(region_ind %in% c("ID", "OR", "WA"))] <- "X"

# Read-in reservoir data
resdf <- read.csv("../../../data/counties/reservoirs/allreservoirs.csv")


# Delete Alaskan reservoir
AL_Idx=which(resdf$lat>50)
resdf<-resdf[-AL_Idx,]



# Read-in results
captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
storage <- as.matrix(read.csv("storage.csv", header = F)) # reservoir level
smax <- matrix(as.matrix(read.csv("storagecapmax.csv", header = F)), nrow = dim(captures)[1], ncol = dim(captures)[2])#*(1-0.05)^12
captures <- captures[-AL_Idx,]
storage <- storage[-AL_Idx,]
smax <- smax[-AL_Idx,]

failuresin <- read.csv("failuresin.csv", header = F)
failurecon <- read.csv("failurecon.csv", header = F)

# Separate captures and releases
release <- captures
release[which(release > 0)] <- 0
proprel <- release/smax
proprel[which(smax == 0)] <- 0
hist(rowSums(proprel), breaks = 10)

capture <- captures
capture[which(capture < 0)] <- 0
propcapture <- capture/smax
propcapture[which(smax == 0)] <- 0
hist(propcapture, breaks = 100)
sum(rowMeans(propcapture)<0.01)/length(rowMeans(propcapture))*100
mpctcap <- 100*rowMeans(propcapture)


# Reservoir maps
map <- map_data("usa")

png(paste0('plots/reservoir_map.png'), height = 800, width = 1200)
p <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white")+
  geom_point(data=resdf, aes(x=lon, y=lat), color='red')+
  ggtitle('CONUS reservoir map')+
  theme_bw()
print(p)
dev.off()

resdf$capture=apply(capture, MARGIN=1, FUN = sum)
resdf$release=apply(release, MARGIN=1, FUN = sum)
resdf$captures=apply(captures, MARGIN=1, FUN = sum)
resdf$sd_captures=apply(captures, MARGIN=1, FUN = sd)
resdf$sd_cap[resdf$sd_cap<0]=0
resdf$max_capture=apply(capture, MARGIN=1, FUN = max)
resdf$max_release=-apply(release, MARGIN=1, FUN = min)


p <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white")

png(paste0('plots/sd_capture_map.png'), height = 800, width = 1200)
p1 <- p +
   geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(sd_cap)), size=1)+
   scale_colour_gradient(low='blue', high='red')+
   ggtitle('Log1p of the standard deviation of captures across years')+
   theme_bw()
p1
dev.off()

png(paste0('plots/max_capture_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(max_capture)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of the maximum capture across years')+
  theme_bw()
p1
dev.off()

png(paste0('plots/max_release_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(max_release)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of the maximum release across years')+
  theme_bw()
p1
dev.off()

which(apply(capture, MARGIN=2, FUN = sum)==max(apply(capture, MARGIN=2, FUN = sum)))
which(apply(release, MARGIN=2, FUN = sum)==min(apply(release, MARGIN=2, FUN = sum)))
resdf$capture2006=capture[,7]
resdf$release2009=capture[,10]

png(paste0('plots/capture2006_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(capture2006)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of 2006 captures')+
  theme_bw()
p1
dev.off()

png(paste0('plots/release2009_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(release2009)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of 2009 releases')+
  theme_bw()
p1
dev.off()


# County-level maps
failure_diff=failuresin-failurecon
df_counties=data.frame(FIPS=mastercounties$fips)
df_counties$FIPS[1:286]=paste0("0", mastercounties$fips[1:286])
df_counties$failurecon=log1p(apply(failurecon, MARGIN=1, FUN = sum))
df_counties$failuresin=log1p(apply(failuresin, MARGIN=1, FUN = sum))
df_counties$max_failurecon=apply(failurecon, MARGIN=1, FUN = max)
df_counties$max_failuresin=apply(failuresin, MARGIN=1, FUN = max)
df_counties$sd_failurecon=log1p(apply(failurecon, MARGIN=1, FUN = sd))
df_counties$sd_failuresin=log1p(apply(failuresin, MARGIN=1, FUN = sd))
df_counties$failure_diff=apply(failure_diff, MARGIN=1, FUN = sum)
which(apply(failurecon, MARGIN=2, FUN = sum)==max(apply(failurecon, MARGIN=2, FUN = sum)))
which(apply(failuresin, MARGIN=2, FUN = sum)==max(apply(failuresin, MARGIN=2, FUN = sum)))
df_counties$failurecon_2004=failurecon[,5]
df_counties$failuresin_2004=failuresin[,5]


#f <- tempfile()
#download.file("http://www2.census.gov/geo/tiger/GENZ2010/gz_2010_us_050_00_20m.zip", destfile = f)
#unzip(f, exdir = ".")
US <- read_shape("gz_2010_us_050_00_20m.shp")
# Leave out AK, HI, and PR (state FIPS: 02, 15, and 72)
US <- US[!(US$STATE %in% c("02","15","72")),] 
US$FIPS <- paste0(US$STATE, US$COUNTY)
US <- append_data(US, df_counties, key.shp = "FIPS", key.data = "FIPS")


png(paste0('plots/failuresin_map.png'), height = 1000, width = 1200)
qtm(US, fill='failuresin')
#US_states <- unionSpatialPolygons(US, IDs=US@data$STATE)
tm_shape(US, projection="+init=epsg:2163") +
  tm_polygons("failuresin", border.col = "grey30", title="") +
  #tm_shape(US_states) +
  tm_borders(lwd=2, col = "black", alpha = .5) +
  tm_layout(title="Log1p of total failures accross years - no reservoirs", 
            title.position = c("center", "top"),
            title.size = 1.3,
            legend.text.size=1)
dev.off()

png(paste0('plots/failurecon_map.png'), height = 1000, width = 1200)
qtm(US, fill='failurecon')
#US_states <- unionSpatialPolygons(US, IDs=US@data$STATE)
tm_shape(US, projection="+init=epsg:2163") +
  tm_polygons("failurecon", border.col = "grey30", title="") +
  #tm_shape(US_states) +
  tm_borders(lwd=2, col = "black", alpha = .5) +
  tm_layout(title="Log1p of total failures accross years - with reservoirs", 
            title.position = c("center", "top"),
            title.size = 1.3,
            legend.text.size=1)
dev.off()
png(paste0('plots/sd_failuresin_map.png'), height = 1000, width = 1200)
qtm(US, fill='sd_failuresin')
#US_states <- unionSpatialPolygons(US, IDs=US@data$STATE)
tm_shape(US, projection="+init=epsg:2163") +
  tm_polygons("sd_failuresin", border.col = "grey30", title="") +
  #tm_shape(US_states) +
  tm_borders(lwd=2, col = "black", alpha = .5) +
  tm_layout(title="Log1p of standard deviation of failures accross years - no reservoirs", 
            title.position = c("center", "top"),
            title.size = 1.3,
            legend.text.size=1)
dev.off()

png(paste0('plots/sd_failurecon_map.png'), height = 1000, width = 1200)
qtm(US, fill='sd_failurecon')
#US_states <- unionSpatialPolygons(US, IDs=US@data$STATE)
tm_shape(US, projection="+init=epsg:2163") +
  tm_polygons("sd_failuresin", border.col = "grey30", title="") +
  #tm_shape(US_states) +
  tm_borders(lwd=2, col = "black", alpha = .5) +
  tm_layout(title="Log1p of standard deviation of failures accross years - with reservoirs", 
            title.position = c("center", "top"),
            title.size = 1.3,
            legend.text.size=1)
dev.off()


# Plot reservoir curves
plot(storage[1,]/smax[1,], ylim = c(0, 1.1), type = "l", xlab = "month", ylab = "proportion storage")
for(tt in 2:2670){lines(storage[tt,]/smax[tt,])}
plot(colSums(storage/smax))
plot(captures[1,]/smax[1,], ylim = c(-1.1, 1.1), type = "l", xlab = "month", ylab = "proportion capture")
for(tt in 2:2670){lines(captures[tt,]/smax[tt,])}

# TS analysis

df=data.frame(time_ind, fips, state_ind, region_ind)
p<-ggplot(data=df_counties,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p
