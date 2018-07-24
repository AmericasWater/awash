
## Parameters to change
result_path = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "paper3/")
nlocs=3109
start_year=1451
end_year=2000
ttperyy=1
vrights=c("norightconst")
voptim <- c("surface")
vreval <- c("zero")
namescenario <- paste0(vreval, "-",vrights)
flowprop <- c("0.5")
simyrs=50
periods=seq(start_year, end_year, by=simyrs)
nperiods=length(periods)
ee=1
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
setwd(result_path)
source("../plotting1.R")


yearstot=end_year-start_year+1
ismultiyr=0
if (yearstot>1) {ismultiyr=1}


time_ind0 <- 1:(yearstot*ttperyy)
dir.create('plots', showWarnings=F)


source("../readAWASHresults1.R")
tokm3 <- T
if(tokm3){
  result <- result *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}




result_files=list.files("paleo_1451-2000")
result=array(dim=c(nlocs, simyrs*ttperyy, nperiods))
for(k in 1:nperiods){
  result[,,k]=as.matrix(read.csv(paste0("paleo_1451-2000/",result_files[k]), header=F))
}

names(result)=c("fips", "year", "period", "failures")

dfbx=as.data.frame(apply(result, MARGIN=c(2,3), FUN=sum))
start_years=seq(start_year, end_year-simyrs+1, by=simyrs)
end_years=seq(start_year+simyrs-1, end_year, by=simyrs)
colnames(dfbx)=paste0(start_years, "-", end_years)
dfbx=melt(dfbx)
colnames(dfbx)=c("Period", "Failures")
h <- ggplot(data=dfbx, aes(x=Period, y=Failures))+geom_boxplot()+
  ggtitle("Boxplots of failures per period of 50 years")+
  xlab("Period")+
  ylab("Failures ([1000 m3]")+
  theme_bw()
png("plots/boxplot_failures.png", width=800, height=400)
print(h)
dev.off()


dfbx$Time=time_ind0+start_year
h <- ggplot(data=dfbx, aes(x=Time, y=Failures))+
  geom_line(color="#CC79A7", size=1)+
  ggtitle("Time series of failures (runs per period of 50 years)")+
  xlab("Time")+
  ylab("Failures ([1000 m3]")+
  theme_bw()
png("plots/ts_failures.png", width=800, height=400)
print(h)
dev.off()

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

df=melt(result)
names(df)=c("fips", "Year", "Period", "Failures")
df$Time=time_ind
df$Region=region_ind
dem=matrix(dem, nrow = 3109, ncol = length(time_ind0)) %>% as.vector()
df$dem=dem
df$per_cent=100*df$Failures/df$dem
df$per_cent[df$per_cent==Inf]=0

h <- ggplot(data=df[df$Region=="IV",])+geom_boxplot(aes(x=Period, y=Failures))+
  ggtitle("Boxplots of failures per period of 50 years")+
  xlab("Period")+
  ylab("Failures ([1000 m3]")+
  theme_bw()+ facet_wrap( ~ Region, ncol = 3)
h


for (t in c(1:max(time_ind0))){
  png(file=paste0("plots/map_percent", t, ".png"), width=700, height=400)
  mapdata(df$per_cent[df$Time==t], varname = paste("t =",t),
          breaks=c(0, 25, 50, 75),
          limits=c(0,100))
  dev.off()
}

counter=0
for (t in c(1:max(time_ind0))){
  png(file=paste0("plots/",t,".map", ".png"), width=700, height=400)
  mapdata(df$Failures[df$Time==t], varname = paste("t =",t),
          breaks=c(0, (median(failure)/2), (mean(failure)*4/5)),
          limits=c(0,max(failure)))
  dev.off()
  counter=counter+1
}











# 
# a=result[4,,,,]
# 
# dffailure <- melt(apply(result[4,,,,], c(1,2,4), sum))
# names(dffailure) <- c("year","fips","scenario","failure")
# 
# state_ind <- dffailure$fips


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
#captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
#storage <- as.matrix(read.csv("storage.csv", header = F)) # reservoir level
#smax <- matrix(as.matrix(read.csv("storagecapmax.csv", header = F)), nrow = dim(captures)[1], ncol = dim(captures)[2])#*(1-0.05)^12

fmv <- . %>% as.matrix() %>% as.vector()
failure <- read.csv("failure-surface-propenv0.5-rescapzero-norightconst-1451.csv", header = F) %>% fmv
#failurecon <- read.csv("failurecon.csv", header = F)

dem_tot=read.csv("dem_tot.csv", header=F)


df <- data.frame(time_ind, fips, state_ind, region_ind, failure, dem_tot)

# _________________________________________________________________________________________
# 1. Timeseries analyses.
# @Luc: add line between the losange
cols <- c("per county"="cyan3","national"="lightsalmon2")
png(file="plots/ts1.png", width=700, height=400)
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(name="", values=cols) + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  theme_minimal()
p
dev.off()

png(file="plots/ts2.png", width=700, height=400)
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p
dev.off()

# @Luc: add line between the losange
png(file="plots/ts3.png", width=700, height=400)
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=mean, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=mean, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Average failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p
dev.off()

png(file="plots/histo.png", width=700, height=400)
p<-ggplot(data = df)+
  facet_wrap(~region_ind) +
  geom_histogram(aes(x = log1p(failure)),binwidth = 1)
p
dev.off()


failure <- read.csv("failure-surface-propenv0.5-rescapzero-norightconst-1451.csv", header = F)
source("../plotting.R")
a=failure/dem_tot


failure_means=rowMeans(failure)

png(file="plots/map1.png", width=700, height=400)
mapdata(failure_means, varname = "Mean Failure (volume in 1000 m3)",
        breaks=c(0, (max(failure_means)/2), (max(failure_means)*4/5)), 
        limits=c(0,max(failure_means)))
dev.off()
per_cent_failure=100*failure/dem_tot
per_cent_failure[per_cent_failure==Inf]=0
#per_cent_failure[per_cent_failure==Inf]=0

png(file="plots/map2.png", width=700, height=400)
mapdata2(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure")
dev.off()

png(file="plots/map3.png", width=700, height=400)
mapdata(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure",
        breaks=c(0, (max(per_cent_failure, na.rm=T)/2), (max(per_cent_failure, na.rm=T)*4/5)), 
        limits=c(0,max(per_cent_failure, na.rm=T)))
dev.off()



std_failure=apply(failure, MARGIN=1, FUN=sd)
png(file="plots/map_std.png", width=700, height=400)
mapdata(std_failure, varname = "Std of failure", 
        breaks=c(0, (max(std_failure, na.rm=T)/2), (max(std_failure, na.rm=T)*4/5)), 
        limits=c(0,max(std_failure, na.rm=T)))
dev.off()

# png(file="plots/example.png", width=700, height=400)
# for (t in c(1:max(time_ind0))){
#   mapdata(failure[,t], varname = paste("t =",t), 
#           breaks=c(0, (median(failure)/2), (mean(failure)*4/5)), 
#           limits=c(0,max(failure)))
# }
# dev.off()






















