
## Parameters to change
result_path = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "paleo_1yr_1month/")

start_year=1451
end_year=1460
tstep_py=1

## Load libraries and finish set-up
library(PBSmapping)
library(RColorBrewer)
library(dplyr)
library(ggplot2)
library(ggmap)
library(maps)
library(maptools)
library(tmap)      # package for plotting
library(readxl)    # for reading Excel
library(tmaptools) 
data(wrld_simpl)
setwd(result_path)

nyears=end_year-start_year+1
time_ind0 <- 1:(nyears*tstep_py)
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
resdf <- read.csv("../../../data/paleo/reservoirs/allreservoirs.csv")

# Read-in results
captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
storage <- as.matrix(read.csv("storage.csv", header = F)) # reservoir level
smax <- matrix(as.matrix(read.csv("storagecapmax.csv", header = F)), nrow = dim(captures)[1], ncol = dim(captures)[2])#*(1-0.05)^12

failuresin <- read.csv("failuresin.csv", header = F)
failurecon <- read.csv("failurecon.csv", header = F)

dem=read.csv("dem_tot.csv", header=F)

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


resdf$state=state_ind[match(resdf$fips, fips[1:3109])]

## Basic CONUS reservoir maps
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
resdf$sd_cap=apply(captures, MARGIN=1, FUN = sd)
resdf$max_capture=apply(capture, MARGIN=1, FUN = max)
resdf$max_release=-apply(release, MARGIN=1, FUN = min)


p <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white")

png(paste0('plots/sd_capture_map.png'), height = 800, width = 1200)
p1 <- p +
   geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(sd_cap)), size=2)+
   scale_colour_gradient(low='blue', high='red')+
   ggtitle('Log1p of the standard deviation of captures across years')+
   theme_bw()
p1
dev.off()

png(paste0('plots/max_capture_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(max_capture)), size=2)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of the maximum capture across years')+
  theme_bw()
p1
dev.off()

png(paste0('plots/max_release_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(max_release)), size=2)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of the maximum release across years')+
  theme_bw()
p1
dev.off()

Idx1=which(apply(capture, MARGIN=2, FUN = sum)==max(apply(capture, MARGIN=2, FUN = sum)))
Idx2=which(apply(release, MARGIN=2, FUN = sum)==min(apply(release, MARGIN=2, FUN = sum)))
Idx3=which(apply(abs(captures), MARGIN=2, FUN = sum)==max(apply(abs(captures), MARGIN=2, FUN = sum)))
resdf$capturemax=capture[,Idx1]
resdf$releasemax=capture[,Idx2]
resdf$capturesmax=captures[,Idx3]

png(paste0('plots/capturemax_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(capturemax)), size=2)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle(paste0('Log1p of captures in ', start_year+Idx1, ', year with largest captures'))+
  theme_bw()
p1
dev.off()

png(paste0('plots/releasemax_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf, aes(x=lon, y=lat, colour = log1p(releasemax)), size=2)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle(paste0('Log1p of releases in ', start_year+Idx2, ', year with largest releases'))+
  theme_bw()
p1
dev.off()


## Analyses of reservoirs with highest variance across years
nres=10
IdX=order(resdf$sd_cap, decreasing = T)[1:nres]
df_nres <- resdf[IdX, ]

# Map
png(paste0('plots/variancemax10_map.png'), height = 800, width = 1200)
p1 <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white") + 
  geom_point(data=df_nres, aes(x=lon, y=lat, size=sd_cap), colour='red')+
  #geom_text(aes(label=Name),hjust=0, vjust=0)+ in case we add names to the reservoir file
  theme_bw()+
  ggtitle(paste0('Locations of ', nres, ' reservoirs with highest variance across years'))
p1
dev.off()
# TS of captures and releases
captures_nres <- t(captures[IdX, ])
capture_nres <- t(capture[IdX, ])
release_nres <- t(release[IdX, ])

colnames(captures_nres)=colnames(capture_nres)=colnames(release_nres)=paste0('dam_',df_nres$colid)
rownames(captures_nres)=rownames(capture_nres)=rownames(release_nres)=time_ind0

df_nres2 <- data.frame(Time=rep(time_ind0, nres), captures=as.vector(captures_nres),
                       capture = as.vector(capture_nres), release=as.vector(release_nres),
                       name=rep(colnames(captures_nres), each=length(time_ind0)))


a=subset(df_nres2[df_nres2$Time==1&df_nres2$name=="dam_1310",])

png(paste0('plots/captures', nres, ' reservoirs.png'), height = 800, width = 1200)
p <- ggplot(data=df_nres2,aes(x=Time))+
  geom_line(aes(y=captures, colour=name), linetype=1)+
  theme_bw()+
  ggtitle(paste0('Evolution of captures and releases through time for ', nres, ' reservoirs'))+
  ylab('Captures and releases [1000 m3]')
  #scale_x_continuous(breaks=c(start_year:end_year))
p
dev.off()

png(paste0('plots/capture', nres, ' reservoirs.png'), height = 800, width = 1200)
p <- ggplot(data=df_nres2,aes(x=Time))+
  geom_line(aes(y=capture, col=name), linetype=1)+
  theme_bw()+
  ggtitle(paste0('Evolution of captures through time for ', nres, ' reservoirs'))+
  ylab('Captures [1000 m3]')
  #scale_x_continuous(breaks=c(start_year:end_year))
p
dev.off()

png(paste0('plots/release', nres, ' reservoirs.png'), height = 800, width = 1200)
p <- ggplot(data=df_nres2,aes(x=Time))+
  geom_line(aes(y=release, col=name), linetype=1)+
  theme_bw()+
  ggtitle(paste0('Evolution of captures through time for ', nres, ' reservoirs'))+
  ylab('release [1000 m3]')
#scale_x_continuous(breaks=c(start_year:end_year))
p
dev.off()
## Analysis of "inactive" dams

# Maps
png(paste0('plots/locations_max100_reservoirs.png'), height = 800, width = 1200)
p1 <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white") + 
  geom_point(data=resdf[(apply(abs(captures), MARGIN=1, FUN = max)<1e-1),], aes(x=lon, y=lat), colour='red')+
  #geom_text(aes(label=Name),hjust=0, vjust=0)+
  theme_bw()+
  ggtitle('Locations of dams whose maximum capture or release is less than 100 m3')
p1
dev.off()

png(paste0('plots/locations_max10_reservoirs.png'), height = 800, width = 1200)
p1 <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white") + 
  geom_point(data=resdf[(apply(abs(captures), MARGIN=1, FUN = max)<1e-2),], aes(x=lon, y=lat), colour='red')+
  #geom_text(aes(label=Name),hjust=0, vjust=0)+
  theme_bw()+
  ggtitle('Locations of dams whose maximum capture or release is less than 10 m3')
p1
dev.off()
png(paste0('plots/locations_max1_reservoirs.png'), height = 800, width = 1200)
p1 <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white") + 
  geom_point(data=resdf[(apply(abs(captures), MARGIN=1, FUN = max)<1e-3),], aes(x=lon, y=lat), colour='red')+
  #geom_text(aes(label=Name),hjust=0, vjust=0)+
  theme_bw()+
  ggtitle('Locations of dams whose maximum capture or release is less than 1 m3')
p1
dev.off()

# Evolution of the number of "inactive" reservoirs
regions=region_ind[match(resdf$fips, fips[1:3109])]

df1<-data.frame(Time=rep(time_ind0, each=nrow(resdf)),
                inact0=as.vector((abs(captures) < 1000)),
                inact1=as.vector((abs(captures) < 1e-1)),
                inact2=as.vector((abs(captures) < 1e-2)), 
                inact3=as.vector((abs(captures) < 1e-3)), 
                id=rep(resdf$colid, length(time_ind0)), 
                region=rep(regions, length(time_ind0)))

df1 %>% 
  group_by(Time, region) %>% 
  summarise(inact0 = sum(inact0), inact1 = sum(inact1), inact2 = sum(inact2), inact3 = sum(inact3)) ->df2

df1 %>% 
  group_by(Time) %>% 
  summarise(inact0 = sum(inact0), inact1 = sum(inact1), inact2 = sum(inact2), inact3 = sum(inact3)) ->df3

df2$inact0_prop=df2$inact0/as.vector(rep(table(regions), length(time_ind0)))
df2$inact1_prop=df2$inact1/as.vector(rep(table(regions), length(time_ind0)))
df2$inact2_prop=df2$inact2/as.vector(rep(table(regions), length(time_ind0)))
df2$inact3_prop=df2$inact3/as.vector(rep(table(regions), length(time_ind0)))


png(paste0('plots/ev_reservoirs_less10e6.png'), height = 800, width = 1200)
p <- ggplot(data=df2, aes(x=Time, colour=region))+
  geom_point(aes(y=inact1_prop))+
  theme_bw()+
  ggtitle('Evolution of the proportion of reservoirs with captures/releases of less than 10^6 m3')
  #scale_x_continuous(breaks=c(start_year:end_year))
p
dev.off()

png(paste0('plots/ev_reservoirs_less100.png'), height = 800, width = 1200)
p <- ggplot(data=df2, aes(x=Time, colour=region))+
  geom_point(aes(y=inact1_prop))+
  theme_bw()+
  ggtitle('Evolution of the proportion of reservoirs with captures/releases of less than 100 m3')
  #scale_x_continuous(breaks=c(Time))
p
dev.off()

png(paste0('plots/ev_reservoirs_less10.png'), height = 800, width = 1200)
p <- ggplot(data=df2, aes(x=Time, colour=region))+
  geom_point(aes(y=inact2_prop))+
  theme_bw()+
  ggtitle('Evolution of the proportion of reservoirs with captures/releases of less than 10 m3')
  #scale_x_continuous(breaks=c(start_year:end_year))
p
dev.off()

png(paste0('plots/ev_reservoirs_less1.png'), height = 800, width = 1200)
p <- ggplot(data=df2, aes(x=Time, colour=region))+
  geom_point(aes(y=inact3_prop))+
  theme_bw()+
  ggtitle('Evolution of the proportion of reservoirs with captures/releases of less than 1 m3')
  #scale_x_continuous(breaks=c(start_year:end_year))
p
dev.off()
n_res=nrow(resdf)

# png(paste0('plots/ev_reservoirs_less.png'), height = 800, width = 1200)
# p <- ggplot(data=df3, aes(x=Time))+
#   geom_line(aes(y=inact0/n_res))+
#   geom_line(aes(y=inact1/n_res), color='lightsalmon')+
#   geom_line(aes(y=inact2/n_res), color='cyan3')+
#   geom_line(aes(y=inact3/n_res), color='darkgreen')+
#   theme_bw()+
#   ggtitle('Evolution of the proportion of reservoirs with captures/releases inferior to given threhsolds')
#   #scale_x_continuous(breaks=c(start_year:end_year))
# p
# dev.off()


df33=data.frame(inact=c(df3$inact0, df3$inact1, df3$inact2, df3$inact3), Time=rep(df3$Time, times=4), 
                threshold=as.character(c(rep(1e6, length(time_ind0)),rep(1e3, length(time_ind0)),rep(1e2, length(time_ind0)),
                            rep(1e1, length(time_ind0)))))

png(paste0('plots/ev_reservoirs_less.png'), height = 800, width = 1200)
p <- ggplot(data=df33, aes(x=Time, y=inact/n_res, color=threshold))+geom_line()+
  theme_bw()+
  ggtitle('Evolution of the proportion of reservoirs with captures/releases inferior to given thresholds')
p
dev.off()

png(paste0('plots/abs_captures.png'), height = 800, width = 1200)
plot(time_ind0, apply(abs(captures), MARGIN=2, FUN = sum), xlab="Time", ylab="Volume in [1000m3]",
     main="Evolution of the absolute value of total captures")
dev.off()

png(paste0('plots/sd_captures.png'), height = 800, width = 1200)
plot(apply(captures, MARGIN=2, FUN = sd), xlab="Time", ylab="Volume in [1000m3]",
     main="Evolution of the standard deviation of captures")
dev.off()
sum(abs(captures[,1]))
sum(abs(captures[,10]))


## Comparaison demand vs storage

shapes <- importShapefile("C:/Users/luc/Desktop/awash/data/mapping/US_county_2000-simple")
polydata <- attributes(shapes)$PolyData
polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]
polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]
shapes$id <- polydata$STATE[shapes$PID] * 100 + polydata$COUNTY[shapes$PID] / 10;
names(shapes) <- tolower(names(shapes));

stateshapes <- importShapefile("C:/Users/luc/Desktop/awash/data/mapping/tl_2010_us_state00/tl_2010_us_state00-simple")
statespolydata <- attributes(stateshapes)$PolyData
stateshapes$x <- stateshapes$X
stateshapes$y <- stateshapes$Y
stateshapes$id <- stateshapes$PID


dem_sum=rowSums(dem)

df <- data.frame(fips,dem_sum)
df$storage_cap=NA
for (i in 1:nrow(df)){
  df$storage_cap[i]=sum(resdf$MAXCAP[which(resdf$fips==df$fips[i])])
  
}
df$ratio_cap=df$dem_sum/df$storage_cap


myPalette <- colorRampPalette(rev(brewer.pal(11, "Spectral")))
sc <- scale_colour_gradientn(colours = myPalette(100), limits=c(0, 3))
png(paste0('plots/map_ratio_demand_cap.png'), height = 800, width = 1200)
gplot1 <- ggplot() +
  geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='gray', fill=NA) +
  geom_map(data=df, aes(fill=ratio_cap, map_id=fips), map=shapes) +
  scale_fill_gradient(low="blue", high="red")+
  expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
  theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')+
  ggtitle("Ratio of total demand over maximum storage capacity - contemporary case")
gplot1
dev.off()

# fips_storage=matrix(0, nrow=length(fips), ncol=length(time_ind0))
# for(j in time_ind0){
#   for (i in 1:nrow(fips_storage)){
#     fips_storage[i,j]=sum(captures[which(resdf$fips==df$fips[i]),j])
#     
#   }
#   
# }




## Comparaison between two runs
# result_path1 = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "analyzereservoir_60yrs_12months/")
# result_path2 = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "analyzereservoir_60yrs_12months/")
# 
# sim_name1='XXth'
# sim_name2='XXth'
# 
# setwd(result_path1)
# captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
# failuresin <- read.csv("failuresin.csv", header = F)
# failurecon <- read.csv("failurecon.csv", header = F)
# 
# a1=apply(captures, MARGIN=2, FUN = sum)
# b1=apply(failuresin, MARGIN=2, FUN = sum)
# c1=apply(failurecon, MARGIN=2, FUN = sum)
# 
# 
# setwd(result_path2)
# captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
# failuresin <- read.csv("failuresin.csv", header = F)
# failurecon <- read.csv("failurecon.csv", header = F)
# a2=apply(captures, MARGIN=2, FUN = sum)
# b2=apply(failuresin, MARGIN=2, FUN = sum)
# c2=apply(failurecon, MARGIN=2, FUN = sum)
# 
# df=data.frame(Time=rep(c(start_year:end_year),2), captures=c(a1, a2), failuresin=c(b1, b2), failurescon=c(c1, c2),
#               type=c(rep(sim_name1, 10), rep(sim_name2, 10)))
# df$diff=df$failuresin-df$failurescon
# 
# df=data.frame(Time=rep(c(start_year:end_year),2), captures=c(a1, a2), failuresin=c(b1, b2), failurescon=c(c1, c2),
#               type=c(rep(sim_name1, 10), rep(sim_name2, 10)))
# df$diff=df$failuresin-df$failurescon
# 
# png(paste0('plots/diff.png'), height = 800, width = 1200)
# p<-ggplot(data=df, aes(x=Time))+
#   #geom_line(aes(y=captures, color=type))+
#   geom_line(aes(y=diff, color=type))
# p
# dev.off()

# p<-ggplot(data=df, aes(x=Time))+
#   geom_line(aes(y=failuresin, color=type))+
#   geom_line(aes(y=failurescon, color=type))
# p

