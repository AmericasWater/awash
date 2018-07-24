## Load libraries and set-up wd
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
result_path = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "paper3/")
setwd(result_path)
source("../plotting.R")
## Read-in Paleo runs without reservoirs for 1451-2000
nlocs=3109
start_year=1451
end_year=2000
ttperyy=1
simyrs=50
periods=seq(start_year, end_year, by=simyrs)
nperiods=length(periods)
yearstot=end_year-start_year+1
ismultiyr=0
if (yearstot>1) {ismultiyr=1}
time_ind0 <- 1:(yearstot*ttperyy)

result_files=list.files("paleo_1451-2000")
result=array(dim=c(nlocs, simyrs*ttperyy, nperiods))
for(k in 1:nperiods){
  result[,,k]=as.matrix(read.csv(paste0("paleo_1451-2000/",result_files[k]), header=F))
}

names(result)=c("Fips", "Year", "Period", "Failures")
tokm3 <- T
if(tokm3){
  result <- result *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}

df_paleo1=as.data.frame(apply(result, MARGIN=c(2,3), FUN=sum))
start_years=seq(start_year, end_year-simyrs+1, by=simyrs)
end_years=seq(start_year+simyrs-1, end_year, by=simyrs)
colnames(df_paleo1)=paste0(start_years, "-", end_years)
df_paleo1=melt(df_paleo1)
colnames(df_paleo1)=c("Period", "Failures")
p <- ggplot(data=df_paleo1, aes(x=Period, y=Failures))+geom_boxplot()+
  ggtitle("Boxplots of failures per period of 50 years")+
  xlab("Period")+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
#png("plots/boxplot_failures.png", width=800, height=400)
print(p)
#dev.off()


df_paleo1$Type="Paleo"

p <- ggplot(data=df_paleo1, aes(x=Type, y=Failures))+geom_boxplot()+
  ggtitle(paste0("Boxplots of failures ", start_year, " - ", end_year))+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
#png("plots/boxplot_failures.png", width=800, height=400)
print(p)
#dev.off()

p <- ggplot(data=df_paleo1, aes(Failures))+geom_density()+
  ggtitle(paste0("Density estimation of failures ", start_year, " - ", end_year))+
  xlab(paste0(start_year, " - ", end_year))+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
#png("plots/boxplot_failures.png", width=800, height=400)
print(p)
#dev.off()



df_paleo1$Time=time_ind0+start_year
h <- ggplot(data=df_paleo1, aes(x=Time, y=Failures))+
  geom_line(color="#CC79A7", size=1)+
  ggtitle("Time series of failures (runs per period of 50 years)")+
  xlab("Time")+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
#png("plots/ts_failures.png", width=800, height=400)
print(h)
#dev.off()

result_counties=read.csv(paste0("counties/failure-surface-propenv0.5-rescapzero-norightconst-yearly-1950.csv"), header=F)

if(tokm3){
  result_counties <- result_counties *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}
df_counties1=data.frame(Period=rep("1950-2000", ncol(result_counties)))
df_counties1$Failures=apply(result_counties, MARGIN=2, FUN=sum)
df_counties1$Type="Counties"
df_counties1$Time=c(1950:2000)


h <- ggplot()+
  geom_line(data=df_paleo1, aes(x=Time, y=Failures),color="#CC79A7", size=1)+
  geom_line(data=df_counties1, aes(x=Time, y=Failures),color="green", size=1)+
  ggtitle("Time series of failures (runs per period of 50 years)")+
  xlab("Time")+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
h

df_all1=rbind(df_paleo1, df_counties1)
p <- ggplot(data=df_all1, aes(x=Type, y=Failures))+geom_boxplot()+
  ggtitle(paste0("Boxplots of failures "))+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
#png("plots/boxplot_failures.png", width=800, height=400)
print(p)
#dev.off()

p <- ggplot(data=df_all1, aes(Failures))+geom_density(aes(color=Type))+
  ggtitle(paste0("Density estimation of failures "))+
  xlab(paste0(start_year, " - ", end_year))+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
#png("plots/boxplot_failures.png", width=800, height=400)
print(p)
#dev.off()

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

df_paleo2=melt(result)
names(df_paleo2)=c("fips", "Year", "Period", "Failures")
df_paleo2$Time=time_ind
df_paleo2$Region=region_ind

if(ismultiyr){
  dem <- replicate(ttperyy*simyrs,dem_[,1])
  #  dem <- replicate(yearstot,dem)
}else{
  dem <- replicate(ttperyy*yearstot,dem_[,1])
}
dem=matrix(dem, nrow = 3109, ncol = length(time_ind0)) %>% as.vector()
df_paleo2$dem=dem*1e-6
df_paleo2$per_cent=100*df_paleo2$Failures/df_paleo2$dem
df_paleo2$per_cent[df_paleo2$per_cent==Inf]=0





df_paleo2 %>% group_by(fips) %>%
  summarise(Failures_m=mean(Failures, na.rm=T),Failures_sd=sd(Failures, na.rm=T),
            per_cent_m=mean(per_cent, na.rm=T),per_cent_sd=sd(per_cent, na.rm=T)) -> df_paleo_map


mapdata(df_paleo_map$per_cent_m, varname = "Mean % Failure",
        breaks=c(0, (max(df_paleo_map$per_cent_m, na.rm=T)/2), (max(df_paleo_map$per_cent_m, na.rm=T)*4/5)), 
        limits=c(0,max(df_paleo_map$per_cent_m, na.rm=T)))





result_files="failure-surface-propenv0.5-rescapzero-norightconst-yearly-1950.csv"
result_counties=array(dim=c(nlocs, 51, 1))
result_counties[,,1]=as.matrix(read.csv(paste0("counties/","failure-surface-propenv0.5-rescapzero-norightconst-yearly-1950.csv"), header=F))
if(tokm3){
  result_counties <- result_counties *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}
df_counties2=melt(result_counties)
names(df_counties2)=c("fips", "Year", "Period", "Failures")
time_ind0 <- 1:51
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

df_counties2$Time=time_ind
df_counties2$Region=region_ind
dem_ <- as.matrix(read.csv("../../../data/counties/extraction/USGS-2010.csv", header = T)[,31]) * 1383/ttperyy

dem <- rep(dem_, 51)

length(dem)

df_counties2$dem=dem
df_counties2$per_cent=100*df_counties2$Failures/df_counties2$dem
df_counties2$per_cent[df_counties2$per_cent==Inf]=0

df_paleo2$Type="Paleo"
df_counties2$Type="Counties"
df_all2=rbind(df_paleo2, df_counties2)

sum(df_all1$Failures)
sum(df_all2$Failures)


sum(df_counties1$Failures)
sum(df_counties2$Failures)

df_all2 %>% group_by(Type, Region, Time) %>%
  summarise(Failures=sum(Failures, na.rm=T)) -> df_all3
h <- ggplot(data=df_all3)+geom_boxplot(aes(x=Type, y=Failures, color=Type))+
  ggtitle("Boxplots of failures")+
  xlab("Type")+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
h


h <- ggplot(data=df_all3)+geom_boxplot(aes(x=Type, y=Failures, color=Type))+
  ggtitle("Boxplots of failures")+
  xlab("Type")+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()+ facet_wrap( ~ Region, ncol = 3)
h


p <- ggplot(data=df_all1, aes(x=Type, y=Failures))+geom_boxplot()+
  ggtitle(paste0("Boxplots of failures ", start_year, " - ", end_year))+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
#png("plots/boxplot_failures.png", width=800, height=400)
print(p)




data=as.matrix(read.csv(paste0("paleo_1564-1573/", "failure-surface-propenv0.5-rescapzero-norightconst-yearly-1564.csv"), header=F))

  
result_drought=array(dim=c(nlocs, ncol(data), 1))
result_drought[,,1]=data
if(tokm3){
  result_drought <- result_drought *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}

time_ind0 <- 1:ncol(data)
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
df_drought=melt(result_drought)
names(df_drought)=c("fips", "Year", "Period", "Failures")
df_drought$Time=time_ind
df_drought$Region=region_ind

dem_ <- as.matrix(read.csv("../../../data/counties/extraction/USGS-2010.csv", header = T)[,31]) * 1383/ttperyy

dem <- rep(dem_, ncol(data))

length(dem)

df_drought$dem=dem
df_drought$per_cent=100*df_drought$Failures/df_drought$dem
df_drought$per_cent[df_drought$per_cent==Inf]=0

df_drought$Type="Paleo"




df_drought %>% group_by(Type, Region, Time) %>%
  summarise(Failures=sum(Failures, na.rm=T)) -> df_drought2
h <- ggplot(data=df_drought2)+geom_boxplot(aes(x=Type, y=Failures, color=Type))+
  ggtitle("Boxplots of failures")+
  xlab("Type")+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
h

h <- ggplot(data=df_drought2)+geom_boxplot(aes(x=Type, y=Failures, color=Type))+
  ggtitle("Boxplots of failures")+
  xlab("Type")+
  ylab(paste0("Failures ", unitvol))+facet_wrap(~Region)+
  theme_bw()
h



drought_list=c("1451-1458","1564-1573","1666-1671","1805-1807","1818-1828","1889-1900","1929-1940","1951-1964","2001-2003")
nd=length(drought_list)
start_dyears=c(1451, 1564, 1666, 1805, 1818, 1889, 1929, 1951, 2001)



DF=data.frame(matrix(ncol = 9, nrow = 0))
colnames(DF) <- c("fips",     "Year",     "Period",   "Failures", "Time",     "Region",   "dem",      "per_cent", "Type")

for(k in 1:nd){
  data=as.matrix(read.csv(paste0("paleo_", drought_list[k],"/", "failure-surface-propenv0.5-rescapzero-norightconst-yearly-",start_dyears[k],
  ".csv"), header=F))
  
  result_drought=array(dim=c(nlocs, ncol(data), 1))
  result_drought[,,1]=data
  if(tokm3){
    result_drought <- result_drought *1e-6
    unitvol <- "[km3/yr]"
  }else{unitvol <- "[1000m3/yr]"}
  
  time_ind0 <- 1:ncol(data)
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
  df_drought=melt(result_drought)
  names(df_drought)=c("fips", "Year", "Period", "Failures")
  df_drought$Time=time_ind
  df_drought$Region=region_ind
  
  dem_ <- as.matrix(read.csv("../../../data/counties/extraction/USGS-2010.csv", header = T)[,31]) * 1383/ttperyy
  
  dem <- rep(dem_, ncol(data))
  
 
  
  df_drought$dem=dem*1e-6
  df_drought$per_cent=100*df_drought$Failures/df_drought$dem
  df_drought$per_cent[df_drought$per_cent==Inf]=0
  
  df_drought$Type="Paleo"
  df_drought$Period=drought_list[k]
  
  DF=rbind(DF, df_drought)
}

DF %>% group_by(Type, Period, Region, Time) %>%
  summarise(Failures=sum(Failures, na.rm=T)) -> DF_drought2
h <- ggplot(data=DF_drought2)+geom_boxplot(aes(x=Type, y=Failures, color=Type))+
  ggtitle("Boxplots of failures")+
  xlab("Type")+
  ylab(paste0("Failures ", unitvol))+
  theme_bw()
h

h <- ggplot(data=DF_drought2)+geom_boxplot(aes(x=Period, y=Failures, color=Period))+
  ggtitle("Boxplots of failures")+
  xlab("Type")+
  ylab(paste0("Failures ", unitvol))+facet_wrap(~Region)+
  theme_bw()
h


DF %>% group_by(fips, Period) %>%
  summarise(Failures_m=mean(Failures, na.rm=T),Failures_sd=sd(Failures, na.rm=T),
            per_cent_m=mean(per_cent, na.rm=T),per_cent_sd=sd(per_cent, na.rm=T)) -> df_drought_map

period="1451-1458"
a=df_drought_map[df_drought_map$Period==period,]$per_cent_m
mapdata(df_drought_map[df_drought_map$Period==period,]$per_cent_m, varname = "Mean % Failure",
        breaks=c(0, (max(df_drought_map$per_cent_m, na.rm=T)/2), (max(df_drought_map$per_cent_m, na.rm=T)*4/5)), 
        limits=c(0,max(df_drought_map$per_cent_m, na.rm=T)))

