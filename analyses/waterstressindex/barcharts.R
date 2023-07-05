setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)

df.local <- read.csv("fipstime-monthly-excess-local.csv")
df.nocan <- read.csv("fipstime-monthly-excess-nores-nocanal.csv")
df.canal <- read.csv("fipstime-monthly-excess-nores.csv")
df.wires <- read.csv("fipstime-monthly-excess-withres.csv")
df.local$suffix <- 'local'
df.nocan$suffix <- 'nocan'
df.canal$suffix <- 'canal'
df.wires$suffix <- 'wires'

df <- rbind(df.local, df.nocan, df.canal, df.wires)
df$year <- floor((df$timestep - 1) / 12) + 1950

df2 <- df %>% filter(year < 2011) %>% group_by(fips, year, suffix) %>% summarize(failurefrac.excess.worst=max(failurefrac.excess), natflowav.excess.worst=min(natflowav.excess), failurefrac.excess=mean(failurefrac.excess), natflowav.excess=mean(natflowav.excess))

## Calculate median worst
df2.medianworst <- df2 %>% group_by(fips, suffix) %>% summarize(failurefrac.excess.worst.median=median(failurefrac.excess.worst, na.rm=T), failurefrac.excess.worst.worst=max(failurefrac.excess.worst, na.rm=T))
df2.mw.byscenario <- df2.medianworst %>% group_by(suffix) %>% summarize(failurefrac.excess.worst.median=mean(failurefrac.excess.worst.median[is.finite(failurefrac.excess.worst.median)] > 0), failurefrac.excess.worst.worst=mean(failurefrac.excess.worst.worst[is.finite(failurefrac.excess.worst.worst)] > 0))


library(maps)
data(state.fips)

df2$statefips <- floor(df2$fips / 1000)
df2 <- df2 %>% left_join(state.fips, by=c("statefips"="fips"))
state_ind <- df2$abb
regiondef <- "climateregion"

source("../papers/loadingregion.R")
df2$region <- region_ind

df3 <- df2 %>% group_by(year, region, suffix) %>% summarize(failurefrac.excess.worst.mean=mean(failurefrac.excess.worst, na.rm=T), natflowav.excess.worst.mean=mean(natflowav.excess.worst, na.rm=T), failurefrac.excess.mean=mean(failurefrac.excess, na.rm=T), natflowav.excess.mean=mean(natflowav.excess, na.rm=T))

df4 <- df3 %>% group_by(suffix, region) %>% summarize(ymin=c(min(failurefrac.excess.worst.mean, na.rm=T), min(natflowav.excess.worst.mean, na.rm=T), min(failurefrac.excess.mean, na.rm=T), min(natflowav.excess.mean, na.rm=T)),
                                              ymax=c(max(failurefrac.excess.worst.mean, na.rm=T), max(natflowav.excess.worst.mean, na.rm=T), max(failurefrac.excess.mean, na.rm=T), max(natflowav.excess.mean, na.rm=T)),
                                              yp25=c(quantile(failurefrac.excess.worst.mean, .25, na.rm=T), quantile(natflowav.excess.worst.mean, .25, na.rm=T), quantile(failurefrac.excess.mean, .25, na.rm=T), quantile(natflowav.excess.mean, .25, na.rm=T)),
                                              yp75=c(quantile(failurefrac.excess.worst.mean, .75, na.rm=T), quantile(natflowav.excess.worst.mean, .75, na.rm=T), quantile(failurefrac.excess.mean, .75, na.rm=T), quantile(natflowav.excess.mean, .75, na.rm=T)),
                                              yp50=c(quantile(failurefrac.excess.worst.mean, .5, na.rm=T), quantile(natflowav.excess.worst.mean, .5, na.rm=T), quantile(failurefrac.excess.mean, .5, na.rm=T), quantile(natflowav.excess.mean, .5, na.rm=T)),
                                              ymean=c(mean(failurefrac.excess.worst.mean, na.rm=T), mean(natflowav.excess.worst.mean, na.rm=T), mean(failurefrac.excess.mean, na.rm=T), mean(natflowav.excess.mean, na.rm=T)),
                                              metric=c('Failure fraction', 'Natural flow available', 'Failure fraction', 'Natural flow available'),
                                              overtime=c('Worst month', 'Worst month', 'Annual average', 'Annual average'))

df4$scenario <- NA
df4$scenario[df4$suffix == 'local'] <- "Local runoff"
df4$scenario[df4$suffix == 'nocan'] <- "No canals"
df4$scenario[df4$suffix == 'canal'] <- "River networks"
df4$scenario[df4$suffix == 'wires'] <- "Rivers and reservoirs"

library(ggplot2)

ggplot(subset(df4, suffix != 'nocan'), aes(overtime, ymean, colour=scenario, group=scenario)) +
    facet_grid(region ~ metric) + theme_bw() +
    geom_point(position=position_dodge(width=.9)) +
    geom_errorbar(aes(ymin=yp50, ymax=yp50), width=.8, position=position_dodge(width=.9)) +
    geom_errorbar(aes(ymin=yp25, ymax=yp75), width=.4, position=position_dodge(width=.9)) +
    geom_linerange(aes(ymin=ymin, ymax=ymax), position=position_dodge(width=.9)) +
    scale_y_continuous(labels=scales::percent) + xlab(NULL) + ylab(NULL) +
    scale_fill_discrete(name="Scenario") + scale_colour_discrete(name="Scenario")

ggplot(subset(df4, suffix != 'nocan' & metric == 'Failure fraction' & region == "Northeast"), aes(overtime, ymean, colour=scenario, group=scenario)) +
    facet_wrap(~ region) + theme_bw() +
    geom_point(position=position_dodge(width=.9)) +
    geom_errorbar(aes(ymin=yp50, ymax=yp50), width=.8, position=position_dodge(width=.9)) +
    geom_errorbar(aes(ymin=yp25, ymax=yp75), width=.4, position=position_dodge(width=.9)) +
    geom_linerange(aes(ymin=ymin, ymax=ymax), position=position_dodge(width=.9)) +
    scale_y_continuous(labels=scales::percent) + xlab(NULL) + ylab(NULL) +
    scale_fill_discrete(name="Scenario") + scale_colour_discrete(name="Scenario")

df5 <- data.frame(year=rep(df3$year), region=rep(df3$region), suffix=rep(df3$suffix),
                  metric=rep(c('Failure fraction', 'Natural flow available', 'Failure fraction', 'Natural flow available'), each=nrow(df3)),
                  overtime=rep(c('Worst month', 'Worst month', 'Annual average', 'Annual average'), each=nrow(df3)),
                  value=c(df3$failurefrac.excess.worst.mean, df3$natflowav.excess.worst.mean, df3$failurefrac.excess.mean, df3$natflowav.excess.mean))

df5$scenario <- NA
df5$scenario[df5$suffix == 'local'] <- "Local runoff"
df5$scenario[df5$suffix == 'nocan'] <- "No canals"
df5$scenario[df5$suffix == 'canal'] <- "River networks"
df5$scenario[df5$suffix == 'wires'] <- "Rivers and reservoirs"

df5$region <- factor(df5$region, levels=c('Northwest', 'East North Central', 'Northeast',
                                          'West', 'West North Central', 'Central',
                                          'Southwest', 'South', 'Southeast'))

gp <- ggplot(subset(df5, suffix != 'nocan' & metric == 'Failure fraction'), aes(overtime, value, colour=scenario, group=paste(scenario, overtime))) +
    facet_wrap(~ region) + theme_bw() +
    geom_boxplot() +
    scale_y_continuous(labels=scales::percent) + xlab(NULL) + ylab(NULL) +
    scale_fill_discrete(name="Scenario") + scale_colour_discrete(name="Scenario")
ggsave("failfrac-byregion.pdf", gp, width=8, height=6)

gp <- ggplot(subset(df5, suffix != 'nocan' & metric == 'Natural flow available'), aes(overtime, value, colour=scenario, group=paste(scenario, overtime))) +
    facet_wrap(~ region) + theme_bw() +
    geom_boxplot() +
    scale_y_continuous(labels=scales::percent) + xlab(NULL) + ylab(NULL) +
    scale_fill_discrete(name="Scenario") + scale_colour_discrete(name="Scenario")
ggsave("natflowav-byregion.pdf", gp, width=8, height=6)

## Construct table by state

df3 <- df2 %>% group_by(year, statefips, suffix) %>% summarize(failurefrac.excess.worst.mean=mean(failurefrac.excess.worst, na.rm=T), natflowav.excess.worst.mean=mean(natflowav.excess.worst, na.rm=T), failurefrac.excess.mean=mean(failurefrac.excess, na.rm=T), natflowav.excess.mean=mean(natflowav.excess, na.rm=T))

df4 <- df3 %>% group_by(suffix, statefips) %>% summarize(yp25=c(quantile(failurefrac.excess.worst.mean, .25, na.rm=T), quantile(natflowav.excess.worst.mean, .25, na.rm=T), quantile(failurefrac.excess.mean, .25, na.rm=T), quantile(natflowav.excess.mean, .25, na.rm=T)),
                                                         yp75=c(quantile(failurefrac.excess.worst.mean, .75, na.rm=T), quantile(natflowav.excess.worst.mean, .75, na.rm=T), quantile(failurefrac.excess.mean, .75, na.rm=T), quantile(natflowav.excess.mean, .75, na.rm=T)),
                                              metric=c('Failure fraction', 'Natural flow available', 'Failure fraction', 'Natural flow available'),
                                              overtime=c('Worst month', 'Worst month', 'Annual average', 'Annual average'))

df4$value <- paste0(round(100 * df4$yp25), " - ", round(100 * df4$yp75), "%")

statefips <- read.csv("statefips.csv")

library(reshape2)
library(xtable)

df5 <- dcast(df4[df4$metric == 'Failure fraction' & df4$suffix != 'canal',], statefips ~ suffix + overtime)
df6 <- df5 %>% left_join(statefips, by=c('statefips'='fips'))
print(xtable(df6[, c('State', names(df6)[2:7])]), include.rownames=F)

df5 <- dcast(df4[df4$metric == 'Natural flow available' & df4$suffix != 'canal',], statefips ~ suffix + overtime)
df6 <- df5 %>% left_join(statefips, by=c('statefips'='fips'))
print(xtable(df6[, c('State', names(df6)[2:7])]), include.rownames=F)
