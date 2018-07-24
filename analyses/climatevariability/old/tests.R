library(PBSmapping)
library(dplyr)
library(ggplot2)
library(ggmap)
library(maps)
library(maptools)
library(tmap)      # package for plotting
library(readxl)    # for reading Excel
library(tmaptools) 
require(tidyr)
require(reshape2)
data(wrld_simpl)

wd_path = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/")
setwd(wd_path)

# load
dem=read.csv("analyzereservoir_10yrs_12months/dem_tot.csv", header=F)
dem_p=read.csv("paleo_10yrs_12months/dem_tot.csv", header=F)
dem_diff=sum(unlist(dem), na.rm=T)-sum(unlist(dem_p), na.rm=T)

failurecon <- read.csv("analyzereservoir_10yrs_12months/failurecon.csv", header = F)
failurecon_p=read.csv("paleo_10yrs_12months/failurecon.csv", header=F)
failurecon_diff=sum(unlist(failurecon), na.rm=T)-sum(unlist(failurecon_p), na.rm=T)

failure=failurecon
per_cent_failure=100*failure/dem_tot
per_cent_failure[per_cent_failure==Inf]=0

p <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white")

# Set-up
start_year=2001
end_year=2010
tstep_py=1
nyears=end_year-start_year+1
time_ind0 <- 1:nyears*tstep_py
dir.create('plots', showWarnings=F)
# - county fips, state fips, region indexes
mastercounties <- read.csv("../../data/global/counties.csv")
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


fips <- mastercounties$fips
resdf <- read.csv("../../data/counties/reservoirs/allreservoirs.csv")


shapes <- importShapefile("C:/Users/luc/Desktop/awash/data/mapping/US_county_2000-simple")
polydata <- attributes(shapes)$PolyData
polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]
polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]
shapes$id <- polydata$STATE[shapes$PID] * 100 + polydata$COUNTY[shapes$PID] / 10;
names(shapes) <- tolower(names(shapes));

stateshapes <- importShapefile("../../data/mapping/tl_2010_us_state00/tl_2010_us_state00-simple")
statespolydata <- attributes(stateshapes)$PolyData
stateshapes$x <- stateshapes$X
stateshapes$y <- stateshapes$Y
stateshapes$id <- stateshapes$PID


failure_means=rowMeans(failurecon)
dem_sum=rowSums(dem)
dem_p_sum=rowSums(dem_p)

df <- data.frame(fips,dem_sum,dem_p_sum)
df$storage=NA

for (i in 1:nrow(df)){
  df$storage[i]=sum(resdf$MAXCAP[which(resdf$fips==df$fips[i])])
  
}
df$ratio=df$dem_sum/df$storage
df$ratio_p=df$dem_p_sum/df$storage
library("RColorBrewer")
myPalette <- colorRampPalette(rev(brewer.pal(11, "Spectral")))
sc <- scale_colour_gradientn(colours = myPalette(100), limits=c(0, 3))

gplot1 <- ggplot() +
  geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='gray', fill=NA) +
  geom_map(data=df, aes(fill=ratio, map_id=fips), map=shapes) +
  scale_fill_gradient(low="blue", high="red")+
  expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
  theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')+
  ggtitle("Ratio of total demand over maximum storage capacity - contemporary case")
gplot1

gplot2 <- ggplot() +
  geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='gray', fill=NA) +
  geom_map(data=df, aes(fill=ratio_p, map_id=fips), map=shapes) +
  scale_fill_gradient(low="blue", high="red")+
  expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
  theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')+
  ggtitle("Ratio of total demand over maximum storage capacity - paleo case")
gplot2

