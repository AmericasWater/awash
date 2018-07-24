
## Parameters to change

starty=1451
endy=2000
simyrs=50

ttperyy=1
flowprop <- c("0.5")

nlocs=3109
vrights=c("norightconst")
voptim <- c("surface")
vreval <- c("zero")


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
library(reshape)
data(wrld_simpl)
w_d = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/")
setwd(w_d)
source("../plotting.R")





start_periods=seq(start_year, end_year, by=simyrs)
nperiods=length(periods)
yearstot=end_year-start_year+1
run_names <- paste0(vreval, "-",vrights)




time_ind0 <- 1:(yearstot*ttperyy)
dir.create('plots/yearly/yearly', showWarnings=F)


source("../../readAWASHresults.R")
tokm3 <- T
if(tokm3){
  result <- result *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}




#result_files=list.files()
result_files=failure_file
result=array(dim=c(nlocs, simyrs*ttperyy, nperiods))
for(k in 1:nperiods){
  result[,,k]=as.matrix(read.csv(result_files[k], header=F))
}

names(result)=c("fips", "year", "period", "failures")

dfbx=as.data.frame(apply(result, MARGIN=c(2,3), FUN=sum))

colnames(dfbx)=paste0(start_years, "-", end_years)
dfbx=melt(dfbx)
colnames(dfbx)=c("Period", "Failures")
h <- ggplot(data=dfbx, aes(x=Period, y=Failures))+geom_boxplot()+
  ggtitle("Boxplots of failures per period of 50 years")+
  xlab("Period")+
  ylab("Failures ([1000 m3]")+
  theme_bw()
png("plots/yearly/boxplot_failures.png", width=800, height=400)
print(h)
dev.off()


dfbx$Time=time_ind0+start_year
h <- ggplot(data=dfbx, aes(x=Time, y=Failures))+
  geom_line(color="#CC79A7", size=1)+
  ggtitle("Time series of failures (runs per period of 50 years)")+
  xlab("Time")+
  ylab("Failures ([1000 m3]")+
  theme_bw()
png("plots/yearly/ts_failures.png", width=800, height=400)
print(h)
dev.off()

# - county fips, state fips, region indexes
mastercounties <- read.csv("../../../../data/global/counties.csv")
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

df=melt(result)
names(df)=c("fips", "Year", "Period", "Failures")
df$Time=time_ind
df$Region=region_ind
dem=matrix(dem, nrow = 3109, ncol = length(time_ind0)) %>% as.vector()
df$dem=dem
df$per_cent=100*df$Failures/df$dem
df$per_cent[df$per_cent==Inf]=0



df1=aggregate(Failures~Year+Region, sum, data=df)
h <- ggplot(data=df1, aes(x=Year, y=Failures))+
  geom_line(size=1)+
  ggtitle("Time series of failures")+
  xlab("Time")+
  ylab("Failures ([1000 m3]")+
  theme_bw()+ facet_wrap( ~ Region, ncol = 3)
h
png("plots/yearly/ts_failures.png", width=800, height=400)
print(h)
dev.off()


h <- ggplot(data=df)+geom_boxplot(aes(x=Region, y=per_cent, color=Region))+
  ggtitle("Boxplots of failures per period of 50 years")+
  xlab("Time")+
  ylab("Failures ([1000 m3]")+
  theme_bw()#+ facet_wrap( ~ Region, ncol = 3)
h


for (t in c(1:max(time_ind0))){
  png(file=paste0("plots/yearly/map_percent", t, ".png"), width=700, height=400)
  mapdata(df$per_cent[df$Time==t], varname = paste("t =",t),
          breaks=c(0, 25, 50, 75),
          limits=c(0,100))
  dev.off()
}

# counter=0
# for (t in c(1:max(time_ind0))){
#   png(file=paste0("plots/yearly/",t,".map", ".png"), width=700, height=400)
#   mapdata(df$Failures[df$Time==t], varname = paste("t =",t),
#           breaks=c(0, (median(failure)/2), (mean(failure)*4/5)),
#           limits=c(0,max(failure)))
#   dev.off()
#   counter=counter+1
# }








