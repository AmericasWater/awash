setwd("~/research/water/awash/prepare/reservoirs")

library(readxl)
library(ggplot2)
library(scales)

df = read_excel("reservoirs_database.xlsx", 1)

ggplot(df, aes(HEIGHT, MAXCAP)) +
    geom_point() + geom_smooth() + geom_smooth(method='lm', colour=muted('red')) +
    scale_y_log10(name="Maximum capacity (acre-ft)") + scale_x_continuous(name="Dam height (ft)", expand=c(0, 0)) +
    theme_bw()

ggplot(df, aes(HEIGHT, MAXCAP)) +
    geom_point() + geom_smooth() + geom_smooth(method='lm', colour=muted('red')) +
    scale_y_log10(name="Maximum capacity (acre-ft)") + scale_x_log10(name="Dam height (ft)") +
    theme_bw()

summary(lm(log(MAXCAP) ~ HEIGHT, data=df))

MAXCAP.1000m3 <- df$MAXCAP * 1.2334818553199934
HEIGHT.m <- df$HEIGHT * 0.3048

summary(lm(log(MAXCAP.1000m3) ~ HEIGHT.m, data=df))
