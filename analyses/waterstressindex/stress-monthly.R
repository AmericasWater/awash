setwd("~/research/awash/analyses/waterstressindex")
library(dplyr)
library(ggplot2)

suffix <- "nores"

df <- read.csv(paste0("stress-monthly-", suffix, ".csv"))

timedf <- df %>% group_by(startyear, time) %>% summarize(supersource=sum(supersource), minefp=mean(minefp))

ggplot(timedf, aes(startyear + (time - .5) / 12)) +
    geom_line(aes(y=supersource)) + theme_minimal()

ggplot(df, aes(x=startyear + (time - .5) / 12, group=minefp, colour=as.factor(minefp), fill=as.factor(minefp))) +
    geom_bar() + scale_x_continuous(expand=c(0, 0)) +
    scale_y_continuous(expand=c(0, 0)) + coord_cartesian(ylim=c(1000, 3109))
