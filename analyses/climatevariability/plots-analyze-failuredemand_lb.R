# _________________________________________________________________________________________
######## FAILURE DEMAND ANALYSIS
# This piece of code generates the basic plots to interpret the failures outputted by optimize-surface
# _________________________________________________________________________________________
# 0. Loading all the relevant information
# - required packages
require(tidyr)
require(ggplot2)
require(dplyr)
# - failure filename
filename <- "failure.csv"

# - time
time_ind0 <- 1:10
time_ind <- t(matrix(time_ind0, nrow = length(time_ind0), ncol = 3109)) %>% as.vector() %>% as.factor()

# - county fips, state fips, region index
mastercounties <- read.csv("../../data/global/counties.csv")
fips <- matrix(mastercounties$fips, nrow = 3109, ncol = length(time_ind0)) %>% as.vector()
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

# - failure matrix, swsupply matrix, gwsupply matrix
fmv <- . %>% as.matrix() %>% as.vector()
failure <- read.csv(filename, header = F) %>% fmv

# - water demand
dem_tot <- read.csv("dem_tot.csv", header = F) %>% fmv
fdem_tot <- failure/dem_tot
fdem_tot[which(dem_tot == 0)] <- 0
# - for sectoral analysis: each sector demand
dem_ag <- read.csv("dem_ir.csv", header = F) %>% fmv
dem_do <- read.csv("dem_do.csv", header = F) %>% fmv
dem_in <- read.csv("dem_in.csv", header = F) %>% fmv
dem_ur <- read.csv("dem_ur.csv", header = F) %>% fmv
dem_li <- read.csv("dem_li.csv", header = F) %>% fmv
dem_th <- read.csv("dem_th.csv", header = F) %>% fmv


fdem_ag <- failure*dem_ag/dem_tot
fdem_ag[which(dem_tot == 0)] <- 0
fdem_th <- failure*dem_th/dem_tot
fdem_th[which(dem_tot == 0)] <- 0
fdem_ur <- failure*dem_ur/dem_tot
fdem_ur[which(dem_tot == 0)] <- 0
fdem_do <- failure*dem_do/dem_tot
fdem_do[which(dem_tot == 0)] <- 0
fdem_li <- failure*dem_li/dem_tot
fdem_li[which(dem_tot == 0)] <- 0
fdem_in <- failure*dem_in/dem_tot
fdem_in[which(dem_tot == 0)] <- 0

# form the dataset
df <- data.frame(time_ind, fips, state_ind, region_ind, failure, dem_ag, dem_do, dem_in, dem_ur, dem_li, dem_th, dem_tot)
dd <- rbind(data.frame(time_ind,fips,region_ind,fac="total", dem=dem_tot),
            data.frame(time_ind,fips,region_ind,fac="irrigation", dem=dem_ag),
            data.frame(time_ind,fips,region_ind,fac="thermoelectric", dem=dem_th),
            data.frame(time_ind,fips,region_ind,fac="urban", dem=dem_ur))

ddf <- rbind(data.frame(time_ind,fips,region_ind,fac="total", fdem=fdem_tot),
            data.frame(time_ind,fips,region_ind,fac="irrigation", fdem=fdem_ag),
            data.frame(time_ind,fips,region_ind,fac="thermoelectric", fdem=fdem_th),
            data.frame(time_ind,fips,region_ind,fac="urban", fdem=fdem_ur))

theme_set(theme_minimal())

# _________________________________________________________________________________________
# 1. Timeseries analyses.

cols=c("Agriculture"="darkgreen","Livestock"="orchid","Urban"="gray62","Domestic"="cyan3", "Industrial"="steelblue4",  
       "Thermal"="lightsalmon4", "Total"="black")
ggplot(data=df,aes(x=time_ind)) +
  stat_summary(aes(y=dem_ag, colour="Agriculture"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_ag, colour="Agriculture"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_li, colour="Livestock"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_li, colour="Livestock"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_ur, colour="Urban"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_ur, colour="Urban"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_do, colour="Domestic"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_do, colour="Domestic"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_in, colour="Industrial"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_in, colour="Industrial"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_th, colour="Thermal"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_th, colour="Thermal"), fun.y=sum, geom="point", shape=5, size=1) +
  labs(title="Water demand", x="time", y="volume [1000m3]")+
  scale_colour_manual(name="Sector", values=cols)


ggplot(data=df,aes(x=time_ind)) +
  stat_summary(aes(y=fdem_ag, colour="Agriculture"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_ag, colour="Agriculture"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_li, colour="Livestock"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_li, colour="Livestock"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_ur, colour="Urban"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_ur, colour="Urban"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_do, colour="Domestic"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_do, colour="Domestic"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_in, colour="Industrial"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_in, colour="Industrial"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_th, colour="Thermal"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_th, colour="Thermal"), fun.y=sum, geom="point", shape=5, size=1) +
  labs(title="Failure per sector", x="time", y="volume [1000m3]")+
  scale_colour_manual(name="Sector", values=cols)


ggplot(data=df,aes(x=time_ind)) +
  stat_summary(aes(y=dem_ag, colour="Agriculture"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_ag, colour="Agriculture"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_li, colour="Livestock"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_li, colour="Livestock"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_ur, colour="Urban"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_ur, colour="Urban"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_do, colour="Domestic"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_do, colour="Domestic"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_in, colour="Industrial"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_in, colour="Industrial"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=dem_th, colour="Thermal"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=dem_th, colour="Thermal"), fun.y=sum, geom="point", shape=5, size=1) +
  labs(title="Water demand", x="time", y="volume [1000m3]")+
  scale_colour_manual(name="Sector", values=cols)+
  facet_wrap(~region_ind)


ggplot(data=df,aes(x=time_ind)) +
  stat_summary(aes(y=fdem_ag, colour="Agriculture"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_ag, colour="Agriculture"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_li, colour="Livestock"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_li, colour="Livestock"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_ur, colour="Urban"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_ur, colour="Urban"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_do, colour="Domestic"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_do, colour="Domestic"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_in, colour="Industrial"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_in, colour="Industrial"), fun.y=sum, geom="point", shape=5, size=1) +
  stat_summary(aes(y=fdem_th, colour="Thermal"), fun.y=sum, geom="path",  size=1, group = 1) +
  stat_summary(aes(y=fdem_th, colour="Thermal"), fun.y=sum, geom="point", shape=5, size=1) +
  labs(title="Failure per sector", x="time", y="volume [1000m3]")+
  scale_colour_manual(name="Sector", values=cols)+
  facet_wrap(~region_ind)


# _________________________________________________________________________________________
# 2. Histograms.

X_dem <- log1p(dd$dem)

ggplot(data = dd, aes(x = X_dem, group = fac, color = fac)) + geom_density()+
  scale_x_continuous(breaks=c(quantile(X_dem, 0.1), median(X_dem), quantile(X_dem, 0.9)), 
                     labels=c(formatC(quantile(X_dem, 0.1), format = "e", digits = 1), 
                              formatC(median(X_dem), format = "e", digits = 1), 
                              formatC(quantile(X_dem, 0.9), format = "e", digits = 1)))

ggplot(data = dd, aes(x = X_dem, group = fac, color = fac)) + geom_density() + facet_wrap(~region_ind) +
  scale_x_continuous(breaks=c(quantile(X_dem, 0.1), median(X_dem), quantile(X_dem, 0.99)), 
                     labels=c(formatC(quantile(X_dem, 0.1), format = "e", digits = 0), 
                              formatC(median(X_dem), format = "e", digits = 0), 
                              formatC(quantile(X_dem, 0.99), format = "e", digits = 0)))
# Il faudrait que les axes soient transformes et pas les donnees par le log1p ...
ggplot(data = dd, aes(x = fac, y = (dem), group = fac, color = fac)) + geom_boxplot() + facet_wrap(~region_ind)+
  theme(axis.text.x=element_blank())
# @Luc: Une victoire! ne reste plus qu'a vire les labels tout pourris en dessous des plots ... Ca c'est les plots pour la demande, il faut la meme chose pour 

#ggplot(data = ddf, aes(x = log1p(fdem), group = fac, color = fac)) + geom_density()
#ggplot(data = ddf, aes(x = log1p(fdem), group = fac, color = fac)) + geom_density() + facet_wrap(~region_ind)
# Il faudrait que les axes soient transformes et pas les donnees par le log1p ...
Y_fdem <- log1p(ddf$fdem)
ggplot(data = ddf, aes(x = fac, y = log1p(fdem), group = fac, color = fac)) + geom_boxplot() + facet_wrap(~region_ind)+
  theme(axis.text.x=element_blank())+
  scale_y_continuous(breaks=c(quantile(Y_fdem, 0.1, na.rm=T), median(Y_fdem, na.rm=T), quantile(Y_fdem, 0.99, na.rm=T)), 
                     labels=c(formatC(quantile(Y_fdem, 0.1, na.rm=T), format = "e", digits = 0), 
                              formatC(median(Y_fdem), format = "e", digits = 0), 
                              formatC(quantile(Y_fdem, 0.99, na.rm=T), format = "e", digits = 0)))+
  labs(y='fdem', x='region')

# _________________________________________________________________________________________
# 3. Maps.
f <- read.csv(filename, header = F)
source("plotting.R")

failure_means=rowMeans(f)
mapdata(failure_means, varname = "Mean Failure",breaks=c(0, (max(failure_means)/2), (max(failure_means)*4/5)), 
        limits=c(0,max(failure_means)))

per_cent_failure <- 100*f/dem_tot
per_cent_failure[which(dem_tot == 0)] <- 0

mapdata(log1p(rowSums(per_cent_failure, na.rm = T)), varname = "100% of failure", transtype = 'log1p', 
        breaks=c(0, (max(per_cent_failure, na.rm=T)/10), (max(per_cent_failure, na.rm=T)*4/5)), 
        limits=c(0,max(per_cent_failure, na.rm=T)))

failure_ag <- f*dem_ag/dem_tot
failure_ag[which(dem_tot == 0)] <- 0
mapdata(rowSums(f*dem_ag/dem_tot, na.rm = T), varname = "Failure Ag", transtype = 'log1p', 
        breaks=c(0, (max(f*dem_ag/dem_tot, na.rm=T)/10), (max(f*dem_ag/dem_tot, na.rm=T)*4/5)), 
        limits=c(0,max(f*dem_ag/dem_tot, na.rm=T)))

failure_th <- f*dem_th/dem_tot
failure_th[which(dem_tot == 0)] <- 0
mapdata(rowSums(failure_th, na.rm = T), varname = "Failure Thermo", transtype = 'log1p', 
        breaks=c(0, (max(failure_th, na.rm=T)/10), (max(failure_th, na.rm=T)*4/5)), 
        limits=c(0,max(failure_th, na.rm=T)))

failure_ur <- f*dem_ur/dem_tot
failure_ur[failure_ur==Inf]=0
mapdata(rowSums(failure_ur, na.rm = T), varname = "Failure Urban", transtype = 'log1p', 
        breaks=c(0, (max(failure_ur, na.rm=T)/10), (max(failure_ur, na.rm=T)*4/5)), 
        limits=c(0,max(failure_ur, na.rm=T)))

failure_do <- f*dem_do/dem_tot
failure_do[which(dem_tot == 0)] <- 0
mapdata(rowSums(failure_do, na.rm = T), varname = "Failure Dom", transtype = 'log1p', 
        breaks=c(0, (max(failure_do, na.rm=T)/10), (max(failure_do, na.rm=T)*4/5)), 
        limits=c(0,max(failure_do, na.rm=T)))

failure_li <- f*dem_li/dem_tot
failure_li[which(dem_tot == 0)] <- 0
mapdata(rowSums(failure_li, na.rm = T), varname = "Failure livestock", transtype = 'log1p', 
        breaks=c(0, (max(failure_li, na.rm=T)/10), (max(failure_li, na.rm=T)*4/5)), 
        limits=c(0,max(failure_li, na.rm=T)))

failure_in=f*dem_in/dem_tot
failure_in[which(dem_tot == 0)] <- 0
mapdata(rowSums(failure_in, na.rm = T), varname = "Failure industrial", transtype = 'log1p', 
        breaks=c(0, (max(failure_in, na.rm=T)/10), (max(failure_in, na.rm=T)*4/5)), 
        limits=c(0,max(failure_in, na.rm=T)))

per_cent_failure=100*f/dem_tot
per_cent_failure[per_cent_failure==Inf]=0
mapdata(log1p(rowSums(per_cent_failure, na.rm = T)), varname = "100% of failure", transtype = 'log1p', 
        breaks=c(0, (max(per_cent_failure, na.rm=T)/10), (max(per_cent_failure, na.rm=T)*4/5)), 
        limits=c(0,max(per_cent_failure, na.rm=T)))

# _________________________________________________________________________________________
# 4. Animations.

#png(file="example%02d.png", width=700, height=400)
for (t in c(1:max(time_ind0))){
  mapdata(f[,t], varname = paste("t =",t), transtype = 'log1p',
          breaks=c(0, (mean(unlist(failure), na.rm=T)/10), (mean(unlist(failure))*4/5)), 
          limits=c(0,max(unlist(failure), na.rm=T)))
}
#dev.off()
# should be compiled in a gif using: convert -delay 80 *.png failure.gif
# @Luc: would you know how to set the scale so that it is the same on all plots = max(failure)?

# http://r-statistics.co/Top50-Ggplot2-Visualizations-MasterList-R-Code.html
# https://plot.ly/ggplot2/animations/

# _________________________________________________________________________________________
# 5. Interative plots with plotly
# https://plot.ly/r/bubble-maps/ to create the bubble maps