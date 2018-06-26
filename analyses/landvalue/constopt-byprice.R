setwd("~/research/awash/analyses/landvalue")

df <- read.csv("constopt-byprice.csv")

df$year <- NA
df$year[df$filepath == "currentprofits-pfixed-lybymc.csv"] <- 2010
df$year[df$filepath == "all2050profits-pfixed-notime-histco-lybymc.csv"] <- 2050
df$year[df$filepath == "all2070profits-pfixed-notime-histco-lybymc.csv"] <- 2070

df$switchcosts <- df$exclcosts - df$objective

library(ggplot2)

df$choice <- factor(df$choice, levels=c("optimal", "observed"))

ggplot(subset(df, is.na(costs) | costs %in% c(0, Inf) | round(log10(costs), 3) == round(log10(costs))), aes(year, objective, colour=costs, group=costs, linetype=choice)) +
    geom_line()

ggplot(df, aes(year, objective, colour=costs, group=costs, linetype=choice)) +
    geom_line() + theme_minimal() + xlab(NULL) + ylab("Total profits") + scale_colour_continuous(name="Switching costs") + scale_linetype_discrete(name=NULL)
ggsave("profits-byprice.pdf", width=7, height=3)

ggplot(df, aes(year, switchcosts, colour=costs, group=costs, linetype=choice)) +
    geom_line() + theme_minimal() + xlab(NULL) + ylab("Total profits") + scale_colour_continuous(name="Switching costs") + scale_linetype_discrete(name=NULL)
ggsave("switch-byprice.pdf", width=7, height=3)
