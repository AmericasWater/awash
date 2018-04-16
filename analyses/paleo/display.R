library(ggplot2)

setwd("~/research/water/awash6/analyses")

df <- read.csv("paleohist.csv")

ggplot(df, aes(month, flows)) +
    facet_grid(dataset ~ ., scales="free") +
    geom_line() + theme_minimal()
