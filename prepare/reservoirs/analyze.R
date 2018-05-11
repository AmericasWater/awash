setwd("~/h_space/research/water/reservoirs")

df <- read.csv("costs.csv")

plot(df$Height..m., df$Estimated.2008.Construction.Cost..INEEL....M., log="xy", xlab="Dam height", ylab="Costs (M$2008)")

df$logcost <- log(df$Estimated.2008.Construction.Cost..INEEL....M.)
df$logheight <- log(df$Height..m.)
summary(lm(logcost ~ logheight, data=df))

df$logcost2 <- log(df$Removal.Cost.Inflated.to.2008.using.USACE.Index...M.)
summary(lm(logcost2 ~ logheight, data=df))

df <- read.csv("removals.csv")

df$logcost <- log(df$Inflated.Removal.Cost...M.)
df$logheight <- log(df$Dam.Height..m.)
df$logrezsize <- log(df$Reservoir.Size..Ha.)
mod <- lm(logcost ~ logheight + logrezsize + Built..year. + Removal.Complete..year., data=df[!is.na(df$Removal.Complete..year.) & !is.na(df$logrezsize),])

library(MASS)

stepAIC(mod)

plot(df$Dam.Height..m., df$Inflated.Removal.Cost...M., log="xy", xlab="Dam height", ylab="Removal Costs (M$2008)")

summary(lm(logcost ~ logheight, data=df))
