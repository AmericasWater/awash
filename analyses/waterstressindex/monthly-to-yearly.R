setwd("~/research/water/awash/analyses/waterstressindex")
library(dplyr)

source("vsenv-lib.R")

for (suffix in c('local', 'nores-nocanal', 'nores', 'withres')) {
    df <- read.csv(paste0("fipstime-monthly-excess-", suffix, ".csv"))
    df$year <- floor((df$timestep - 1) / 12) + 1950

    df2 <- df %>% filter(year < 2011) %>% group_by(fips, year) %>% summarize(supersource.sw.worst=max(supersource.sw), failurefrac.excess.worst=max(failurefrac.excess), natflowav.excess.worst=min(natflowav.excess), supersource.sw=sum(supersource.sw), failurefrac.excess=mean(failurefrac.excess), natflowav.excess=mean(natflowav.excess))

    df3 <- df2 %>% group_by(fips) %>% summarize(failurefrac.excess.worst.median=median(failurefrac.excess.worst, na.rm=T), failurefrac.excess.worst.worst=max(failurefrac.excess.worst, na.rm=T), natflowav.excess.worst.median=median(natflowav.excess.worst, na.rm=T), natflowav.excess.worst.worst=min(natflowav.excess.worst, na.rm=T), failurefrac.excess.median=median(failurefrac.excess, na.rm=T), failurefrac.excess.worst=max(failurefrac.excess, na.rm=T), natflowav.excess.median=median(natflowav.excess, na.rm=T), natflowav.excess.worst=min(natflowav.excess, na.rm=T))

    plot.failavail(df3$fips, df3$failurefrac.excess.median, df3$failurefrac.excess.worst, df3$natflowav.excess.median, df3$natflowav.excess.worst, paste0("annual-excess-", suffix))
    plot.failavail(df3$fips, df3$failurefrac.excess.worst.median, df3$failurefrac.excess.worst.worst, df3$natflowav.excess.worst.median, df3$natflowav.excess.worst.worst, paste0("annual-worst-excess-", suffix))
}
