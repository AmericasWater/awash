setwd("~/research/water/model/awash/analyses/agcheck")

dfbycy <- read.csv("byyear.csv")

library(ggplot2)

df1 <- data.frame(crop=rep(dfbycy$crop, 4), isobs=rep(c(T, F, T, F), each=nrow(dfbycy)), isirrig=rep(c(T, T, F, F), each=nrow(dfbycy)), yield=c(dfbycy$obsirrigatedyield, dfbycy$estirrigatedyield, dfbycy$obsrainfedyield, dfbycy$estrainfedyield))
df2 <- data.frame(crop=rep(dfbycy$crop, 2), isirrig=rep(c(T, F), each=nrow(dfbycy)), obsyield=c(dfbycy$obsirrigatedyield, dfbycy$obsrainfedyield), estyield=c(dfbycy$estirrigatedyield, dfbycy$estrainfedyield))

df2$obsyield[df2$obsyield == -1] <- NA

ggplot(df2, aes(x=obsyield, y=estyield)) +
    facet_grid(isirrig ~ crop) +
    geom_point()
