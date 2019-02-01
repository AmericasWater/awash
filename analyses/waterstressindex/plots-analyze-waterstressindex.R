# Script to analyze the water stress indeces
indexgw <- as.matrix(read.csv("wsi_indexgw.csv", header = F))
indexsw <- as.matrix(read.csv("wsi_indexsw.csv", header = F))
WaSSI <- as.matrix(read.csv("wsi_indexWaSSI.csv", header = F))
WaSSli <- as.matrix(read.csv("wsi_indexWaSSli.csv", header = F))
#W <- as.matrix(read.csv(".csv", header = F))
failure <- read.csv("failure.csv", header = F)

setwd("../climatevariability/analyzefailuredemand/")
source("../plotting.R")
setwd("../../waterstressindex/")
yearstot <- dim(failure)[2]

printplots <- T
widthplots <- 800

# STRESS MAPS
mapdata(rowSums(failure), "failure")
if(printplots){dev.print(file="failure.png", device=png, width=widthplots)}

maptime <- function(valeur, valeurname){
  vallim <- valeur
  if(sum(abs(vallim) ==Inf, na.rm = T)>0){
    vallim[which(abs(vallim) == Inf)] <- NaN}
  limi <- round(c(min((vallim), na.rm = T), max((vallim), na.rm = T)))
  br <- signif(seq(min((vallim), na.rm = T), max((vallim), na.rm = T), (max((vallim), na.rm = T)-min((vallim), na.rm = T))/4),3)
  mapdata((rowMeans(valeur, na.rm = T)), paste(valeurname,"mean"), limits = limi, breaks = br)
  if(printplots){dev.print(file=paste0(valeurname,"mean.png"), device=png, width=widthplots)}
  for(tt in 1:yearstot){
    mapdata((valeur[,tt]), paste(valeurname,"year",tt), limits = limi, breaks = br)
    if(printplots){dev.print(file=paste0(valeurname,"_",tt,".png"), device=png, width=widthplots)}
    }
}

maptime(WaSSI, "WaSSI")
maptime(WaSSli, "WaSSli")
maptime(indexgw, "GW stress")

maptime(log1p(WaSSI), "log1p WaSSI")
maptime(log1p(WaSSli), "log1p WaSSli")
maptime(log1p(indexgw), "log1p GW stress")

maptime(log(WaSSI), "log WaSSI")
maptime(log(WaSSli), "log WaSSli")
maptime(log(indexgw), "log GW stress")


# plotting index curves with time
plottime <- function(valeur, valeurname){
  vallim <- valeur
  if(sum(abs(vallim) ==Inf, na.rm = T)>0){
    vallim[which(abs(vallim) == Inf)] <- NaN}
  limi <- c(min((vallim), na.rm = T), max((vallim), na.rm = T))
  plot(valeur[1,], ylim = limi, type = "l", xlab = "year", ylab = valeurname)
  for(tt in 2:3109){lines(valeur[tt,])}
  lines(colMeans(valeur, na.rm = T), col = "red")
  if(printplots){dev.print(file=paste0(valeurname,".png"), device=png, width=widthplots)}
}
par(mfrow = c(3,1))
plottime(WaSSI, "WaSSI")
plottime(WaSSli, "WaSSli")
plottime(WaSSI - WaSSli, "WaSSI - WaSSli")
plottime(log1p(WaSSI), "log1p WaSSI")
plottime(log1p(WaSSli), "log1p WaSSli")
plottime(log1p(WaSSI - WaSSli), "log1p WaSSI - WaSSli")

# analyzing the stress at the gauge level
load("../../data/counties/waternet/waternet.RData")
plot(network$lon, network$lat, col = rowSums(indexsw))
# number of gauges not the same ...


## To generate the gifs || system("") does not seem to work ...
# convert -delay 20 -loop 0 log\ GW\ stress_* logGWstress.gif
# convert -delay 20 -loop 0 log1p\ GW\ stress_* log1pGWstress.gif
# convert -delay 20 -loop 0 GW\ stress_* GWstress.gif
# 
# convert -delay 20 -loop 0 log\ WaSSI_* logWaSSI.gif
# convert -delay 20 -loop 0 log1p\ WaSSI_* log1pWaSSI.gif
# convert -delay 20 -loop 0 WaSSI_* WaSSI.gif
# 
# convert -delay 20 -loop 0 log\ WaSSli_* logWaSSli.gif
# convert -delay 20 -loop 0 log1p\ WaSSli_* log1pWaSSli.gif
# convert -delay 20 -loop 0 WaSSli_* WaSSli.gif