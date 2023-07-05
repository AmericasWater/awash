setwd("~/research/water/awash/analyses/waterstressindex")
library(dplyr)

for (suffix in c('loca', 'nores-nocanal', 'nores', 'withres')) {
    df <- read.csv(paste0("fipstime-monthly-excess-", suffix, ".csv"))
    df$year <- floor((df$timestep - 1) / 12) + 1950

    df2 <- df %>% filter(year < 2011) %>% group_by(fips, year) %>% summarize(supersource.sw.worst=max(supersource.sw), failurefrac.excess.worst=max(failurefrac.excess), natflowav.excess.worst=min(natflowav.excess), supersource.sw=sum(supersource.sw), failurefrac.excess=mean(failurefrac.excess), natflowav.excess=mean(natflowav.excess))


