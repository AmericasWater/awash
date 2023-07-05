setwd("~/research/water/awash6/prepare/reservoirs")

df <- read.csv("costs.csv")

plot(df$Height..m., df$Estimated.2008.Construction.Cost..INEEL....M., log="xy", xlab="Dam height", ylab="Costs (M$2008)")

df$logcost <- log(df$Estimated.2008.Construction.Cost..INEEL....M.)
df$logheight <- log(df$Height..m.)
summary(lm(logcost ~ logheight, data=df))

library(ggplot2)
ggplot(df, aes(Height..m., Estimated.2008.Construction.Cost..INEEL....M.)) +
    geom_point() + stat_smooth(method='lm', fullrange=T) +
    scale_x_log10() + scale_y_log10() + xlab("Height (m)") + ylab("Construction cost ($M(2008))") +
    theme_bw()

df$logcost2 <- log(df$Removal.Cost.Inflated.to.2008.using.USACE.Index...M.)
summary(lm(logcost2 ~ logheight, data=df))

df <- read.csv("removals.csv")

df$logcost <- log(df$Inflated.Removal.Cost...M.)
df$logheight <- log(df$Dam.Height..m.)
df$logrezsize <- log(df$Reservoir.Size..Ha.)
mod <- lm(logcost ~ logheight + logrezsize + Built..year. + Removal.Complete..year., data=df[!is.na(df$Built..year.) & !is.na(df$Removal.Complete..year.) & !is.na(df$logrezsize),])

library(MASS)

stepAIC(mod)

mod1 <- lm(logcost ~ logheight, data=df)
mod2 <- lm(logcost ~ logheight + Removal.Complete..year., data=df)

library(stargazer)

stargazer(list(mod1, mod2), covariate.labels=c("Log height", "Removal year", "Constant"), dep.var.labels="Log Cost ($2008M)")

plot(df$Dam.Height..m., df$Inflated.Removal.Cost...M., log="xy", xlab="Dam height", ylab="Removal Costs (M$2008)", pch=16)
lines(c(.01, 100), exp(mod2$coeff[1] + log(c(.01, 100)) * mod2$coeff[2] + mod2$coeff[3] * 2010), lty=2)
##lines(c(.01, 100), exp(mod1$coeff[1] + log(c(.01, 100)) * mod1$coeff[2]), lty=2)
