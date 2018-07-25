setwd("~/research/water/awash/analyses/waterstressindex")
library(dplyr)
library(ggplot2)

suffix <- "nores"

df <- read.csv(paste0("stress-monthly-", suffix, ".csv"))

ggplot(df, aes(x=startyear + (time - .5) / 12, group=minefp, colour=as.factor(minefp), fill=as.factor(minefp))) +
    geom_bar() + scale_x_continuous(expand=c(0, 0)) +
    scale_y_continuous(expand=c(0, 0)) + coord_cartesian(ylim=c(1000, 3109)) +
    scale_fill_discrete(name=NULL) + scale_colour_discrete(name=NULL) +
    xlab(NULL) + ylab("Counties with available flow")
ggsave(paste0("time-natflowa-monthly-", suffix, ".pdf"), width=7, height=4)

df <- read.csv("stress-monthly-nores.csv")
df$assump <- "No Res."
df <- rbind(df, cbind(data.frame(assump="With Res."), read.csv("stress-monthly-withres.csv")))

timedf <- df %>% group_by(startyear, time, assump) %>% summarize(supersource=sum(supersource), minefp=mean(minefp))

yeardf <- timedf %>% group_by(startyear, assump) %>% summarize(peakfail=max(supersource))

ggplot() +
    geom_line(data=timedf, aes(startyear + (time - .5) / 12, supersource, colour=assump)) +
    geom_smooth(data=yeardf, aes(startyear, peakfail, colour=assump), method="lm", formula=y ~ 1, se=F) +
    theme_minimal() + scale_colour_discrete(name="Assumption") +
    xlab(NULL) + ylab("Demand Failure (1000 m^3)")
ggsave(paste0("time-failfrac-monthly-compare.pdf"), width=7, height=4)
