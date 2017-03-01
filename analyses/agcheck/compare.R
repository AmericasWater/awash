setwd("~/research/water/model/awash/analyses/agcheck")

dfbycy <- read.csv("byyear.csv")

library(ggplot2)

dfbycy2 <- subset(dfbycy, fips > 8000 & fips < 9000)

df1 <- data.frame(crop=rep(dfbycy2$crop, 4), isobs=rep(c(T, F, T, F), each=nrow(dfbycy2)), isirrig=rep(c(T, T, F, F), each=nrow(dfbycy2)), yield=c(dfbycy2$obsirrigatedyield, dfbycy2$estirrigatedyield, dfbycy2$obsrainfedyield, dfbycy2$estrainfedyield))
df2 <- data.frame(crop=c(as.character(dfbycy2$crop[dfbycy2$crop == 'soybeans']), as.character(dfbycy2$crop[dfbycy2$crop %in% c('barley', 'hay', 'sorghum')]), paste0('irrigated', dfbycy2$crop[dfbycy2$crop %in% c('maize', 'wheat')]), paste0('rainfed', dfbycy2$crop[dfbycy2$crop %in% c('maize', 'wheat')])), obsyield=c(dfbycy2$obsirrigatedyield[dfbycy2$crop == 'soybeans'], dfbycy2$obsrainfedyield[dfbycy2$crop %in% c('barley', 'hay', 'sorghum')], dfbycy2$obsirrigatedyield[dfbycy2$crop %in% c('maize', 'wheat')], dfbycy2$obsrainfedyield[dfbycy2$crop %in% c('maize', 'wheat')]), estyield=c(dfbycy2$estirrigatedyield[dfbycy2$crop == 'soybeans'], dfbycy2$estrainfedyield[dfbycy2$crop %in% c('barley', 'hay', 'sorghum')], dfbycy2$estirrigatedyield[dfbycy2$crop %in% c('maize', 'wheat')], dfbycy2$estrainfedyield[dfbycy2$crop %in% c('maize', 'wheat')]))

df2$obsyield[df2$obsyield == -1] <- NA
df2 <- subset(df2, !is.na(obsyield))

ggplot(df2, aes(x=obsyield, y=estyield)) +
    facet_wrap(~ crop, scales="free", ncol=4) +
    geom_point(alpha=.1) + stat_smooth(method=lm) +
    theme_bw() + xlab("Observed Yield") + ylab("Estimated Yield")

dfbyww <- read.csv("irrigation.csv")
dfbyww2 <- subset(dfbyww, fips > 8000 & fips < 9000)

ggplot(dfbyww2, aes(x=obsirrigation, y=estirrigation)) + stat_smooth(method=lm, formula=y ~ 0 + x) +
    geom_point(alpha=.1) + theme_bw() + xlab("Observed Irrigation") + ylab("Estimated Irrigation")


## Look at differences by fips for hay
bycy <- data.frame(fips=c(), obs=c(), est=c())
for (ff in unique(dfbycy$fips[dfbycy$crop == "hay" & dfbycy$fips > 8000 & dfbycy$fips < 9000])) {
    print(ff)
    subdf <- subset(dfbycy, fips == ff & crop == "hay" & obsrainfedyield > 0)
    bycy <- rbind(bycy, data.frame(fips=ff, obs=mean(subdf$obsrainfedyield), est=mean(subdf$estrainfedyield)))
}

ggplot(bycy, aes(obs, est)) +
    geom_point() + geom_segment(x=0, xend=2.5, y=0, yend=2.5, alpha=.5) +
    xlim(0, 2.5) + ylim(0, 2.5) +
    xlab("Observed Yield") + ylab("Estimated Yield") + ggtitle("Hay Modeling Comparison")

