setwd("~/research/awash/analyses/landvalue")

df <- read.csv("farmvalue-limited.csv")
quantile(df$esttoadd)
quantile(df$esttoadd_changeirr)
