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
filename <- "failurecon.csv"

# - time
time_ind0 <- 1:12
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
dem_tot <- read.csv("totaldemand.csv", header = F) %>% fmv
fdem_tot <-failure/dem_tot

# - for sectoral analysis: each sector demand
dem_ag <- read.csv("dem_ag.csv", header = F) %>% fmv
dem_do <- read.csv("dem_do.csv", header = F) %>% fmv
dem_in <- read.csv("dem_in.csv", header = F) %>% fmv
dem_ur <- read.csv("dem_ur.csv", header = F) %>% fmv
dem_li <- read.csv("dem_li.csv", header = F) %>% fmv
dem_th <- read.csv("dem_th.csv", header = F) %>% fmv


fdem_ag <-failure*dem_ag/dem_tot
fdem_th <-failure*dem_th/dem_tot
fdem_ur <-failure*dem_ur/dem_tot
fdem_do <-failure*dem_do/dem_tot
fdem_li <-failure*dem_li/dem_tot
fdem_in <-failure*dem_in/dem_tot


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
ggplot(df,aes(x=time_ind, y=dem_tot)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(color="national")) + geom_line(aes(x=time_ind, y=dem_tot, color="per county", group=fips)) + geom_line(aes(x=time_ind, y=dem_ag, color="agriculture", group=fips)) + geom_line(aes(x=time_ind, y=dem_th, color="thermoelectric", group=fips)) +
  scale_color_discrete(name="Demand") + labs(title="Failure to meet water demand", x="time", y="volume [1000m3]")
# @Luc: could it be possible to plot all of the sector demand at the national level? This is only dem_tot ... we don't care for the fips level demand ...

ggplot(df,aes(x=time_ind, y=dem_tot)) + geom_line(aes(x=time_ind, y=dem_tot, color="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(color="national")) +
  scale_color_discrete(name="Failure") + labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind)
# @Luc: samething here, for each region, I'd like to know the demand for each sector aggregated at the region level in function of time. 

ggplot(data=dd, aes(x=time_ind, y=dem)) + geom_line(aes(group = fips, color=fac)) + facet_wrap(~fac)
# La ce que j'aurais voulu faire c'est d'avoir un facet_wrap sur les regions et d'avoir pour chacune la courbe totale pour chaque region de chaque type de demande ...

# _________________________________________________________________________________________
# 2. Histograms.
ggplot(data = dd, aes(x = log1p(dem), group = fac, color = fac)) + geom_density()
ggplot(data = dd, aes(x = log1p(dem), group = fac, color = fac)) + geom_density() + facet_wrap(~region_ind)
# Il faudrait que les axes soient transformes et pas les donnees par le log1p ...
ggplot(data = dd, aes(x = fac, y = (dem), group = fac, color = fac)) + geom_boxplot() + facet_wrap(~region_ind)
# @Luc: Une victoire! ne reste plus qu'a vire les labels tout pourris en dessous des plots ... Ca c'est les plots pour la demande, il faut la meme chose pour 

ggplot(data = ddf, aes(x = log1p(fdem), group = fac, color = fac)) + geom_density()
ggplot(data = ddf, aes(x = log1p(fdem), group = fac, color = fac)) + geom_density() + facet_wrap(~region_ind)
# Il faudrait que les axes soient transformes et pas les donnees par le log1p ...
ggplot(data = ddf, aes(x = fac, y = log1p(fdem), group = fac, color = fac)) + geom_boxplot() + facet_wrap(~region_ind)

# _________________________________________________________________________________________
# 3. Maps.
failure <- read.csv(filename, header = F)
source("plotting.R")
mapdata(rowMeans(failure), varname = "Mean Failure")
mapdata(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure", transtype = 'log1p')

f <- failure
mapdata(rowSums(f*dem_ag/dem_tot, na.rm = T), varname = "Failure Ag", transtype = 'log1p')
mapdata(rowSums(f*dem_th/dem_tot, na.rm = T), varname = "Failure Thermo", transtype = 'log1p')
mapdata(rowSums(f*dem_ur/dem_tot, na.rm = T), varname = "Failure Urban", transtype = 'log1p')
mapdata(rowSums(f*dem_do/dem_tot, na.rm = T), varname = "Failure Dom", transtype = 'log1p')
mapdata(rowSums(f*dem_li/dem_tot, na.rm = T), varname = "Failure livestock", transtype = 'log1p')
mapdata(rowSums(f*dem_in/dem_tot, na.rm = T), varname = "Failure industrial", transtype = 'log1p')
mapdata(log1p(rowSums(100*f/dem_tot, na.rm = T)), varname = "100% of failure", transtype = 'log1p')

# _________________________________________________________________________________________
# 4. Animations.

#png(file="example%02d.png", width=700, height=400)
for (t in c(1:12)){
  mapdata(failure[,t], varname = paste("t =",t), transtype = 'log1p')
}
#dev.off()
# should be compiled in a gif using: convert -delay 80 *.png failure.gif
# @Luc: would you know how to set the scale so that it is the same on all plots = max(failure)?

# http://r-statistics.co/Top50-Ggplot2-Visualizations-MasterList-R-Code.html
# https://plot.ly/ggplot2/animations/

# _________________________________________________________________________________________
# 5. Interative plots with plotly
# https://plot.ly/r/bubble-maps/ to create the bubble maps