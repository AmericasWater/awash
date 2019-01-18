# Script to analyze the water stress indeces
setwd("~/AW-julia/awash/analyses/papers/paper1")

reval <- "zero"
flowprop <- c("0.0","0.37","0.5")
ee <- 3
yearstot <- 60
ismultiyr <- T
ttperyy <- 12

regiondef <- "climateregion"

widthplots <- 800
wdtp_s <- 500
wdtp_lg <- 800
printplots <- T
screenplots <- T
theme_set(theme_bw())
theme_update(legend.position="bottom")



vrights <- c("-nocanal-norightconst","-norightconst","-norightconst")
voptim <- c("surface","surface","surface")
vreval <- c("zero","zero","full")
namescenario <- paste0(vreval, "reservoir",vrights)
namescenario <- c("w/o canal, w/o res","w/ canal, w/o res", "w/ canal, w/ res")

source("../readAWASHresults.R")

tokm3 <- T
if(tokm3){
  result <- result *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}



#source("../readDemand.R")



# _________________________________________________________________________________________
# 1. Yearly failure analysis
# build the dataframe. 
library(reshape)
dffailure <- melt(apply(result[4,,,,], c(1,2,4), sum))
names(dffailure) <- c("year","fips","scenario","failure")

state_ind <- dffailure$fips
source("../loadingregion.R")

dffailure <- cbind(dffailure, region_ind)
names(dffailure) <- c("year","fips","scenario","failure","region")


##### Boxplot of yearly failure
dfbx <- aggregate(failure~year+scenario, sum, data=dffailure)
dfbx$scenario <- factor(dfbx$scenario, levels = c("w/o canal, w/o res", "w/ canal, w/o res", "w/ canal, w/ res"), ordered = TRUE)
h <- ggplot(dfbx, aes(scenario, failure))  
print(h+geom_boxplot(aes(fill=scenario)))

if(printplots){dev.print(file=paste0(savingresultspath, "bxplot_nat.png"), device=png, width=wdtp_s)}

# facet per region
dfbx <- aggregate(failure~year+scenario+region, sum, data=dffailure)
dfbx$scenario <- factor(dfbx$scenario, levels = c("w/o canal, w/o res", "w/ canal, w/o res", "w/ canal, w/ res") ,ordered = TRUE)
h <- ggplot(dfbx, aes(scenario, failure))  
print(h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ region, ncol = 3))

if(printplots){dev.print(file=paste0(savingresultspath, "bxplot_reg.png"), device=png, width=wdtp_lg)}


##### Timeseries of yearly Failure
p <- ggplot(data=dffailure,aes(x=year, y=failure)) +
  stat_summary(fun.y=sum, geom="line",  aes(colour=scenario)) +
  labs(title="Failure to meet water demand", x="year", y=paste("volume", unitvol))
print(p)
if(printplots){dev.print(file=paste0(savingresultspath, "time_nat.png"), device=png, width=wdtp_s)}

# facet per region
print(p + facet_wrap( ~ region, ncol = 3))
if(printplots){dev.print(file=paste0(savingresultspath, "time_reg.png"), device=png, width=wdtp_lg)}


# _________________________________________________________________________________________
# 2. Seasonnal analysis
dffmonth <- melt(result[4,,,,])

state_ind <- dffmonth$fips
source("../loadingregion.R")

dffmonth <- cbind(dffmonth, region_ind)
names(dffmonth) <- c("year","fips","month","scenario","failure","region")
#dffmonth$month <- factor(dffmonth$month, levels = c("Oct","Nov","Dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep"),ordered = TRUE)
#dffmonth$scenario <- factor(dffmonth$scenario, levels = c("w/o canal, w/o res", "w/ canal, w/o res", "w/ canal, w/ res") ,ordered = TRUE)

##### Boxplot of monthly failure
dfbx <- aggregate(failure~year+month+scenario, sum, data=dffmonth)
dfbx$month <- factor(dfbx$month, levels = c("Oct","Nov","Dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep"),ordered = TRUE)
dfbx$scenario <- factor(dfbx$scenario, levels = c("w/o canal, w/o res", "w/ canal, w/o res", "w/ canal, w/ res") ,ordered = TRUE)
h <- ggplot(dfbx, aes(month, failure))  
print(h+geom_boxplot(aes(fill=scenario)))
if(printplots){dev.print(file=paste0(savingresultspath, "season_nat.png"), device=png, width=wdtp_s)}

##### Boxplot of monthly failure per region
dfbx <- aggregate(failure~year+month+scenario+region, sum, data=dffmonth)
dfbx$month <- factor(dfbx$month, levels = c("Oct","Nov","Dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep"),ordered = TRUE)
dfbx$scenario <- factor(dfbx$scenario, levels = c("w/o canal, w/o res", "w/ canal, w/o res", "w/ canal, w/ res") ,ordered = TRUE)
h <- ggplot(dfbx, aes(month, failure))  
print(h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ region, ncol = 3))
if(printplots){dev.print(file=paste0(savingresultspath, "season_reg.png"), device=png, width=wdtp_lg)}






# _________________________________________________________________________________________
# 3. Maps.
## MAPPING mean and std SW and Failure maps
namescenario <- paste0(vreval, "reservoir",vrights)
setwd("..")
source("plotting.R")
setwd("paper1")

if(tokm3){unitvol <- "[km3 yr]"
}else{unitvol <- "[1000m3 yr]"}


if(ismultiyr){
  for(rr in 1:length(vrights)){for(vv in c(4)){
    mapsumup(apply(result[vv,,,,rr], c(2,1), sum), valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}else{
  for(rr in 1:length(vrights)){for(vv in c(4)){
      mapsumup(result[vv,,,rr], valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}
