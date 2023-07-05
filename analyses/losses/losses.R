setwd("~/research/water/network4")
load("flowmodel.RData")

aa = submodels$alpha
aa[aa < 0] <- NA
aa[aa > 1] <- 1

library(ggplot2)

plotdf <- data.frame(source=submodels$source, alpha=aa, dist=submodels$dist, drop=submodels$drop, avg=rowSums(submodels[, 4:14]) / 11)

ggplot(plotdf, aes(alpha)) +
    geom_histogram() + scale_y_log10()

ggplot(plotdf, aes(dist, alpha)) +
    geom_smooth(method='lm') +
    geom_point() + scale_x_log10() + scale_y_log10()

logdist <- log(plotdf$dist)
logdist[!is.finite(logdist)] <- NA
summary(lm(alpha ~ logdist, data=plotdf))

logalpha <- log(plotdf$alpha)
summary(lm(logalpha ~ logdist, data=plotdf))
loglevel <- log(plotdf$avg)
summary(lm(logalpha ~ logdist + loglevel, data=plotdf))
logdrop <- log(plotdf$drop)
logdrop[!is.finite(logdrop)] <- NA
summary(lm(logalpha ~ logdist + logdrop + loglevel, data=plotdf))

logslope <- log(plotdf$drop / plotdf$dist)
logslope[!is.finite(logslope)] <- NA
summary(lm(logalpha ~ logdist + logslope + loglevel, data=plotdf))

summary(lm(logalpha ~ logslope + loglevel, data=plotdf))

mod <- lm(logalpha ~ logdist + logdrop + loglevel, data=plotdf)

## logmalpha <- log(1 - plotdf$alpha)
## logmalpha[!is.finite(logmalpha)] <- NA
## mod <- lm(logmalpha ~ logdist + logdrop + loglevel, data=plotdf)

## summary(lm(logmalpha ~ logdist + logdrop + loglevel, data=plotdf))

dists <- exp(seq(log(quantile(plotdf$dist, .05, na.rm=T)), log(quantile(plotdf$dist, .95, na.rm=T)), length.out=100))
levels <- exp(seq(log(quantile(plotdf$avg[plotdf$avg >= 0], .05, na.rm=T)), log(quantile(plotdf$avg[plotdf$avg >= 0], .95, na.rm=T)), length.out=100))
drops <- exp(seq(log(quantile(plotdf$drop[plotdf$drop >= 0], .05, na.rm=T)), log(quantile(plotdf$drop[plotdf$drop >= 0], .95, na.rm=T)), length.out=100))


df <- expand.grid(dist=dists, level=levels)
df$alpha <- exp(predict(mod, data.frame(logdist=log(df$dist), loglevel=log(df$level), logdrop=as.numeric(log(quantile(plotdf$drop, .5, na.rm=T))))))
df$alpha[df$alpha > 1] <- 1

ggplot(df, aes(dist / 1000, level, fill=alpha)) +
    geom_raster() + scale_x_log10(expand=c(0, 0), breaks=c(2, 5, 10, 20, 50)) + scale_y_log10(expand=c(0, 0)) +
    xlab("River segment distance (km)") + ylab("Average annual flow (cu. m. / s)") +
    scale_fill_continuous(name="Flow\nFactor")




logkmloss <- log((1 - plotdf$alpha) / plotdf$dist)
summary(lm(logkmloss ~ logslope + loglevel, data=plotdf))

mod <- lm(logkmloss ~ logslope + loglevel, data=plotdf)
slopes <- exp(seq(quantile(logslope, .05, na.rm=T), quantile(logslope, .95, na.rm=T), length.out=100))

df <- expand.grid(slope=slopes, level=levels)
df$kmloss <- exp(predict(mod, data.frame(logslope=log(df$slope), loglevel=log(df$level))))

ggplot(df, aes(slope, level, fill=kmloss)) +
    geom_raster() + scale_x_log10() + scale_y_log10()
