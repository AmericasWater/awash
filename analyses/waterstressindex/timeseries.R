setwd("~/research/water/awash/analyses/waterstressindex")

library(ggplot2)
library(dplyr)

preptbl <- function(byfips, suffix) {
    df <- read.csv(byfips)
    tbl <- data.frame(timestep=df$timestep, fips=df$fips, model=suffix)
    tbl[, paste0('supersource.excess')] <- df$supersource.excess
    tbl
}

tbl.local <- preptbl("fipstime-monthly-excess-local.csv", 'local')
#tbl.nocan <- preptbl("fipstime-monthly-excess-nores-nocanal.csv", 'nocan')
tbl.canal <- preptbl("fipstime-monthly-excess-nores.csv", 'canal')
tbl.wires <- preptbl("fipstime-monthly-excess-withres.csv", 'wires')

tbl <- rbind(tbl.local, tbl.canal, tbl.wires) # tbl.nocan,
tbl$model <- factor(tbl$model, levels=c('local', 'canal', 'wires'))

tbl2 <- tbl %>% group_by(timestep, model) %>% summarize(supersource.excess=ifelse(all(is.na(supersource.excess)), NA, sum(supersource.excess, na.rm=T)))
tbl2.annual <- tbl2 %>% group_by(year=1950 + floor((timestep - 1) / 12), model) %>% summarize(totalfail=ifelse(all(is.na(supersource.excess)), NA, sum(supersource.excess, na.rm=T)), peakfail=ifelse(all(is.na(supersource.excess)), NA, max(supersource.excess, na.rm=T)))

ggplot() +
    geom_line(data=tbl2, aes(1949 + (timestep + 9) / 12, supersource.excess, colour=model)) +
    geom_smooth(data=tbl2.annual, aes(year, peakfail, colour=model), method='lm', formula=y ~ 1, se=F) +
    theme_minimal() + scale_colour_discrete(name="Scenario", breaks=c('local', 'canal', 'wires'), labels=c("Local runoff", "River networks", "Rivers and reservoirs")) +
    xlab(NULL) + ylab("Demand Failure (1000 m^3)") + scale_x_continuous(expand=c(0, 0)) +
    scale_y_continuous(expand=c(0, 0), limits=c(0, 2.21e7))

ggsave(paste0("time-failfrac-monthly-excess-compare.pdf"), width=10, height=4)


mean(tbl2$supersource.excess[tbl2$model == 'local'], na.rm=T)
mean(tbl2$supersource.excess[tbl2$model == 'canal'], na.rm=T)
mean(tbl2$supersource.excess[tbl2$model == 'wires'], na.rm=T)

range(tbl2.annual$totalfail[tbl2.annual$model == 'local'], na.rm=T)
range(tbl2.annual$totalfail[tbl2.annual$model == 'wires'], na.rm=T)

mean(tbl2.annual$totalfail[tbl2.annual$model == 'local'], na.rm=T)
mean(tbl2.annual$totalfail[tbl2.annual$model == 'wires'], na.rm=T)

sd(tbl2.annual$totalfail[tbl2.annual$model == 'wires'], na.rm=T)

mean(tbl2.annual$peakfail[tbl2.annual$model == 'local'], na.rm=T)
mean(tbl2.annual$peakfail[tbl2.annual$model == 'wires'], na.rm=T)
