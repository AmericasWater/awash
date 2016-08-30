setwd("~/research/water/model/awash/analyses/agcheck")

dfbycy <- read.csv("byyear.csv")

library(ggplot2)

df1 <- data.frame(crop=rep(dfbycy$crop, 4), isobs=rep(c(T, F, T, F), each=nrow(dfbycy)), isirrig=rep(c(T, T, F, F), each=nrow(dfbycy)), yield=c(dfbycy$obsirrigatedyield, dfbycy$estirrigatedyield, dfbycy$obsrainfedyield, dfbycy$estrainfedyield))
df2 <- data.frame(crop=dfbycy$crop, obsyield=c(dfbycy$obsirrigatedyield[dfbycy$crop == 'soybeans'], dfbycy$obsrainfedyield[dfbycy$crop %in% c('barley', 'hay', 'sorghum')]), estyield=c(dfbycy$estirrigatedyield[dfbycy$crop == 'soybeans'], dfbycy$estrainfedyield[dfbycy$crop %in% c('barley', 'hay', 'sorghum')]))

df2$obsyield[df2$obsyield == -1] <- NA

ggplot(df2, aes(x=obsyield, y=estyield)) +
    facet_wrap(~ crop, scales="free") +
    geom_point(alpha=.1) + stat_smooth(method=lm) +
    theme_bw() + xlab("Observed Yield") + ylab("Estimated Yield")

dfbyww <- read.csv("irrigation.csv")

ggplot(dfbyww, aes(x=obsirrigation, y=estirrigation)) + stat_smooth(method=lm) +
    geom_point(alpha=.1) + theme_bw() + xlab("Observed Irrigation") + ylab("Estimated Irrigation")
