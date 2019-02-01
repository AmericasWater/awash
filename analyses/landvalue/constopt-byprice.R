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
    geom_line() + theme_minimal() + xlab(NULL) + ylab("Total profits") + scale_colour_continuous(name="Switching\ncosts ($/Ha)", trans="sqrt", breaks=c(0, 100, 400, 900)) + scale_linetype_discrete(name=NULL)
ggsave("profits-byprice.pdf", width=7, height=3)

ggplot(df, aes(costs, switchcosts / exclcosts)) +
    facet_grid(year ~ .) + geom_hline(yintercept=0) +
    geom_line() + theme_minimal() + xlab("Switching costs ($/Ha)") + ylab("Incurred switching costs (% additional)") + scale_y_continuous(labels=scales::percent) + scale_x_continuous(expand=c(0, 0))
ggsave("switch-byprice.pdf", width=5, height=3)

df$switchfrac <- df$switchcosts / df$exclcosts
for (year in c(2010, 2050, 2070)) {
    print(max(df$switchfrac[df$year == year]))
    print(df$costs[df$switchfrac == max(df$switchfrac[df$year == year])])
}

## Find where get half of benefits
for (year in c(2010, 2050, 2070)) {
    opto <- df$exclcosts[df$choice == "optimal" & df$costs == 0 & df$year == year]
    obso <- df$exclcosts[df$choice == "observed" & df$year == year]
    print(opto / obso)
    half <- (opto + obso) / 2
    subdf <- df[df$year == year,]
    print(subdf$costs[which.min(abs(subdf$exclcosts - half))])
}
