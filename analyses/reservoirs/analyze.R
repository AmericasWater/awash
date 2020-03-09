setwd("~/research/water/awash/analyses/reservoirs")

df <- read.csv("storage.csv")

library(dplyr)
df2 <- df %>% group_by(startyear, time) %>% summarize(stotal=sum(storage), smaxtotal=sum(storagemax), smean=mean(storage / storagemax, na.rm=T), smedo0=median(storage[storage > 0 & storage <= storagemax] / storagemax[storage > 0 & storage <= storagemax], na.rm=T), smeano0=mean(storage[storage > 0 & storage <= storagemax] / storagemax[storage > 0 & storage <= storagemax], na.rm=T), qhi=quantile(storage / storagemax, .95, na.rm=T), qlo=quantile(storage / storagemax, .05, na.rm=T), qhio0=quantile(storage[storage > 0 & storage <= storagemax] / storagemax[storage > 0 & storage <= storagemax], .95, na.rm=T), qloo0=quantile(storage[storage > 0 & storage <= storagemax] / storagemax[storage > 0 & storage <= storagemax], .05, na.rm=T))

df2$moment <- df2$startyear + (df2$time - .5) / 12

library(ggplot2)

ggplot(df2, aes(moment, smeano0)) +
    geom_line() + geom_ribbon(aes(ymin=qloo0, ymax=qhio0), alpha=.5) +
    theme_bw() + scale_y_continuous(expand=c(0, 0), labels=scales::percent) +
    scale_x_continuous(expand=c(0, 0)) +
    xlab(NULL) + ylab("Portion of reservoir storage used")

df3 <- df %>% group_by(resid) %>% summarize(storage=mean(storage), storagemax=mean(storagemax))
quantile(df3$storage / df3$storagemax, na.rm=T)

df3$storage[df3$storage < 0] <- 0
df3$storage[df3$storagemax > 0 & df3$storage / df3$storagemax > 1] <- df3$storagemax[df3$storagemax > 0 & df3$storage / df3$storagemax > 1]

write.csv(df3, "storage0.csv", row.names=F)
