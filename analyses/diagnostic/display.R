setwd("~/research/awash-uncertain/analyses/diagnostic")

df1 <- read.csv("../../results/diagnostic-master.csv")
df2 <- read.csv("../../results/diagnostic-paleo.csv")

df1$branch <- "master"
df2$branch <- "uncertain"

df <- rbind(df1, df2)
df$group <- factor(df$group, levels=rev(df1$group[!duplicated(df1$group)]))
df$variable <- as.character(df$variable)
df$variable[df$variable == "garbage"] <- "Garbage Collection (s)"
df$variable[df$variable == "elapsed"] <- "Elapsed Time (s)"
df$variable[df$variable == "allocated"] <- "Allocated memory (byte)"

library(ggplot2)

ggplot(subset(df, task == "profiling"), aes(group, value, fill=branch)) +
    facet_grid(~ variable, scales="free") +
    geom_bar(stat="identity", position="dodge") +
    coord_flip()

df$fullname <- paste(df$group, df$variable)
df$fullname <- factor(df$fullname, levels=rev(df$fullname[!duplicated(df$fullname)]))

ggplot(subset(df, task == "outputs"), aes(fullname, value, fill=branch)) +
    geom_bar(stat="identity", position="dodge") +
    scale_y_log10() +
    coord_flip()
