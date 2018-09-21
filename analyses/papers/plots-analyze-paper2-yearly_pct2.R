# Script to analyze the water stress indeces
setwd("~/AW-julia/awash/analyses/papers/")
#setwd("~/Google Drive/AWASH/awash/analyses/papers")
setwd("paper2-yearly/")
suffix <- "-1"
require("ggplot2")
require("reshape")

flowprop <- c("0.0","0.37","0.5")
ee <- 2
yearstot <- 60
ismultiyr <- F
ttperyy <- 1

regiondef <- "climateregion"

widthplots <- 800
wdtp_s <- 500
wdtp_lg <- 800
printplots <- T
screenplots <- T
theme_set(theme_bw())
theme_update(legend.position="bottom")
savePlot <- function(myPlot, file, sizePlot="normal") {
  if(sizePlot == "normal"){
    pdf(paste0(file,".pdf"), width=8,height=6)
  }else{
      pdf(paste0(file,".pdf"), width=14,height=8)}
  print(myPlot)
  dev.off()
}


vrights <- c("-norightconst","-SWGW","-GW","-SW","-norightconst")
voptim <- c("surface","conj","conj","conj","conj")
vreval <- c("zero","zero","zero","zero","zero")
namescenario <- c("current","SWGW","GW","SW","no")

source("../readAWASHresults.R")

tokm3 <- T
if(tokm3){
  result <- result *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}



#source("../readDemand.R")



# _________________________________________________________________________________________
# Building the dataframes.
if(ismultiyr){
df <- melt(apply(result[2:4,,,,], c(1,2,3,5), sum))}else{
  df_d <- melt(apply(result[1,,,], c(2,1,3), sum))
  df_sw <- melt(apply(result[2,,,], c(2,1,3), sum))
  df_gw <- melt(apply(result[3,,,], c(2,1,3), sum))
  df_f <- melt(apply(result[4,,,], c(2,1,3), sum))
  df_new <- cbind(df_d, df_sw$value, df_gw$value, df_f$value)
  names(df_new) <- c("year","fips","scenario","dem", "SW", "GW", "Failure")
  df_new$scenario <- factor(df_new$scenario, levels = namescenario, ordered = TRUE)
  df <- df_new
}

##### National summaries dataframes
df_nat <- aggregate(.~year+scenario, sum, data=df[,-2])
df_nat_vol <- melt(df_nat[,-3], id = c(1,2))
names(df_nat_vol) <- c("year", "scenario", "variable", "volume")
df_nat$SW <- df_nat$SW/df_nat$dem*100
df_nat$GW <- df_nat$GW/df_nat$dem*100
df_nat$Failure <- df_nat$Failure/df_nat$dem*100
df_nat[df_nat$dem==0,4:6] <- 0
df_nat_pct <- melt(df_nat[,-3], id = c(1,2))
names(df_nat_pct) <- c("year", "scenario", "variable", "percent")


##### Regional summaries dataframes
state_ind <- df$fips
for(cc in 1:dim(mc)[1]){state_ind[which(df$fips==mc$fips[cc])] <- as.character(mc$state[cc])}
source("../loadingregion.R")
df_reg <- cbind(df, region_ind)
names(df_reg) <- c("year","fips","scenario","dem", "SW", "GW", "Failure","region")
df_reg <- aggregate(.~year+scenario+region, sum, data=df_reg[,-2])
df_reg_vol <- melt(df_reg[,-4], id = c(1,2,3))
names(df_reg_vol) <- c("year", "scenario", "region", "variable", "volume")
df_reg$SW <- df_reg$SW/df_reg$dem*100
df_reg$GW <- df_reg$GW/df_reg$dem*100
df_reg$Failure <- df_reg$Failure/df_reg$dem*100
df_reg[df_reg$dem==0,5:7] <- 0
df_reg_pct <- melt(df_reg[,-4], id = c(1,2,3))
names(df_reg_pct) <- c("year", "scenario", "region", "variable", "percent")


# _________________________________________________________________________________________
# Plots.

## BOXPLOT
h <- ggplot(df_nat_vol, aes(scenario, volume))
h <- h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ variable, ncol = 3)
if(screenplots){print(h)}
if(printplots){savePlot(h, file=paste0(savingresultspath, "bxplot_nat"))}

h <- ggplot(df_nat_pct, aes(scenario, percent))
h <- h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ variable, ncol = 3)
if(screenplots){print(h)}
if(printplots){savePlot(h, file=paste0(savingresultspath, "bxplot_nat_pct"))}


# facet per region
h <- ggplot(df_reg_vol, aes(scenario, volume))
h <- h+geom_boxplot(aes(fill=scenario)) + facet_grid(variable ~ region, scales = "free_x")#, margins = F))
if(screenplots){print(h)}
if(printplots){savePlot(h, file=paste0(savingresultspath, "bxplot_reg"), "wide")}

h <- ggplot(df_reg_pct, aes(scenario, percent))
h <- h+geom_boxplot(aes(fill=scenario)) + facet_grid(variable ~ region, scales = "free_x")
print(h)
if(printplots){savePlot(h, file=paste0(savingresultspath, "bxplot_reg_pct"),"wide")}



##### Timeseries of yearly Failure
p <- ggplot(data=df_nat_vol,aes(x=year, y=volume)) +
  stat_summary(fun.y=mean, geom="line",  aes(colour=scenario, linetype = scenario)) #+
p <- p + facet_wrap(~ variable, scales = "fixed")
if(printplots){savePlot(p, file=paste0(savingresultspath, "time_nat"))}

p <- ggplot(data=df_nat_pct,aes(x=year, y=percent)) +
  stat_summary(fun.y=mean, geom="line",  aes(colour=scenario, linetype = scenario)) #+
p <- p + facet_wrap(~ variable, scales = "fixed")
if(printplots){savePlot(p, file=paste0(savingresultspath, "time_nat_pct"))}

# facet per region
p <- ggplot(data=df_reg_vol,aes(x=year, y=volume)) +
  stat_summary(fun.y=mean, geom="line",  aes(colour=scenario, linetype = scenario)) #+
p <- p + facet_grid(variable ~ region, scales = "free")
if(printplots){savePlot(p, file=paste0(savingresultspath, "time_reg"), "wide")}

p <- ggplot(data=df_reg_pct,aes(x=year, y=percent)) +
  stat_summary(fun.y=mean, geom="line",  aes(colour=scenario, linetype = scenario)) #+
p <- p + facet_grid(variable ~ region, scales = "free")
if(printplots){savePlot(p, file=paste0(savingresultspath, "time_reg_pct"), "wide")}

# _________________________________________________________________________________________
# 3. Relationship with climate
dfst <- melt(apply(result[2,,,], c(2,1,3), sum))
dfst_ <- melt(apply(result[3,,,], c(2,1,3), sum))
source("../loadingprecip.R")
dfst_r <- melt(apply(Rain_var[,,], c(2,1,3), sum))
dfst <- cbind(dfst, dfst_$value, dfst_r$value)
names(dfst) <- c("year","fips","scenario","SW", "GW", "precip")
state_ind <- dfst$fips
for(cc in 1:dim(mc)[1]){
  state_ind[which(dfst$fips==mc$fips[cc])] <- as.character(mc$state[cc])
}
source("../loadingregion.R")

dfst <- cbind(dfst, region_ind)
names(dfst) <- c("year","fips","scenario","SW", "GW","precip","region")

dfsty <- aggregate(.~year+scenario, sum, data=dfst[,c(1,3:6)])
p <- ggplot(data=dfsty,aes(x=SW, y=GW)) +
  geom_point(aes(colour=precip)) +
  scale_color_gradient2(midpoint=0, low="blue", mid="yellow", high="red", space ="Lab" )
p <- p + facet_wrap(~ scenario, scales = "free")
if(printplots){savePlot(p, file=paste0(savingresultspath, "sw-gw-precip_nat"))}

for(ii in 1:length(levels(dfst$region))){
  dfst_reg <- dfst[dfst$region==levels(dfst$region)[ii],]
  dfsty <- aggregate(.~year+scenario+region, sum, data=dfst_reg)
  p <- ggplot(data=dfsty,aes(x=SW, y=GW)) + geom_point(aes(colour=precip))  +
    scale_color_gradient2(midpoint=0, low="blue", mid="yellow", high="red", space ="Lab")

  p <- p + facet_wrap(~ scenario, scales = "free") +
  labs(title=levels(dfst$region)[ii])
  if(printplots){savePlot(p, file=paste0(savingresultspath, "sw-gw-precip_reg",levels(dfst$region)[ii],""))}
}

# _________________________________________________________________________________________
# 4. Maps.
## MAPPING mean and std SW and Failure maps
namescenario <- paste0(vreval, "reservoir",vrights)
setwd("..")
source("plotting.R")
setwd("paper2-yearly")

if(tokm3){unitvol <- "[km3 yr]"
}else{unitvol <- "[1000m3 yr]"}

result_ <- result
result_[2,,,] <- result_[2,,,]/result_[1,,,]
result_[3,,,] <- result_[3,,,]/result_[1,,,]
result_[4,,,] <- result_[4,,,]/result_[1,,,]
result_[which(is.na(result_))] <- 0
result_ <- result_*100

unitvol <- "pct"

if(ismultiyr){
  for(rr in 1:length(vrights)){for(vv in c(3,4)){
    mapsumup(apply(result_[vv,,,,rr], c(2,1), sum), valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}else{
  for(rr in 1:length(vrights)){for(vv in c(3,4)){
      mapsumup(result_[vv,,,rr], valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}

#vv <- 4
#for(ss in c(1,3,2,4)){
#mapdata(apply(result_[vv,,,ss],1,max), paste(dimnames(result)[[1]][vv], "S",ss))}

#usgs <- read.csv("../../../data/counties/extraction/USGS-2010.csv", header = T)
#sw <- sum(usgs$TO_SW)* 1383/ttperyy*1e-6
#gw <- sum(usgs$TO_GW)* 1383/ttperyy*1e-6
#tot <- sum(usgs$TO_To)* 1383/ttperyy*1e-6

