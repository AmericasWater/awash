library(ncdf4)
library(dplyr)
library(png)
library(grid)
library(cowplot)
library(maps)

source("~/projects/research-common/R/ggmap.R")

split.fipsyears <- function(longform, minormax) {
    wideform <- matrix(longform, 3109, length(longform) / 3109)
    medianval <- apply(wideform, 1, median)
    worstval <- apply(wideform, 1, minormax)
    list(median=medianval, worst=worstval)
}

split.fipsyears.xorder <- function(values, fips, minormax) {
    result <- data.frame(values, fips) %>% group_by(fips) %>% summarize(median=median(values), worst=minormax(values))
    list(fips=result$fips, median=result$median, worst=result$worst)
}

plot.relity <- function(fips, relity, suffix) {
    gg <- gg.usmap(relity, fips, relity, extra.polygon.aes=aes(size=1 - borders)) +
        scale_fill_gradientn(name="Reliability", colours=c("#f7fcb9", "#78c679", "#006837"), values=c(0, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_colour_gradientn(name="Reliability", colours=c("#f7fcb9", "#78c679", "#006837"), values=c(0, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_size(range=c(0, .5)) + guides(size=F) +
        theme(legend.justification=c(1,0), legend.position=c(1,0),
              panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
              axis.text.x=element_blank(), axis.text.y=element_blank(),
              plot.margin=unit(rep(0, 4), "cm")) +
        scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
    ggdraw(gg)
    ggsave(paste0("reliable-", suffix, ".pdf"), width=5.9, height=3.2)
}

plot.relity.both <- function(fips, relity.model, relity.excess, suffix) {
    ## gg <- gg.usmap(relity.excess, fips, relity.excess, extra.polygon.aes=aes(size=1 - borders)) +
    ##     scale_fill_gradientn(name="Reliability", colours=c("#f7fcb9", "#78c679", "#006837"), values=c(0, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    ## scale_colour_gradientn(name="Reliability", colours=c("#f7fcb9", "#78c679", "#006837"), values=c(0, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    ## scale_size(range=c(0, .5)) + guides(size=F) +
    ##     theme(legend.justification=c(1,0), legend.position=c(1,0),
    ##           panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
    ##           axis.text.x=element_blank(), axis.text.y=element_blank(),
    ##           plot.margin=unit(rep(0, 4), "cm")) +
    ##     scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
    ## ggdraw(gg)
    ## ggsave(paste0("reliable-", suffix, ".pdf"), width=5.9, height=3.2)
    ## gg <- gg.usmap(relity.model, fips, relity.model, extra.polygon.aes=aes(size=1 - borders)) +
    ##     #scale_colour_gradientn(name="Reliability", colours=c("#000000FF", "#00000080", "#00000000"), values=c(0, .9, 1), labels = scales::percent, limits=c(0, 1)) +
    ##     scale_fill_gradient(name="Reliability", low="#000000FF", high="#00000000", labels=scales::percent, limits=c(0, 1)) +
    ## scale_colour_gradient(name="Reliability", low="#000000FF", high="#00000000", labels=scales::percent, limits=c(0, 1)) +
    ## scale_size(range=c(0, .5)) + guides(size=F) +
    ##     theme(legend.justification=c(1,0), legend.position=c(1,0),
    ##           panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
    ##           axis.text.x=element_blank(), axis.text.y=element_blank(),
    ##           plot.margin=unit(rep(0, 4), "cm")) +
    ##     scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
    ## ggdraw(gg)
    ## ggsave(paste0("reliablemodel-", suffix, ".pdf"), width=5.9, height=3.2)
    gl <- rasterGrob(readPNG("reliability-legend.png"), interpolate=TRUE)
    gg <- gg.usmap(relity.excess, fips, relity.model, extra.polygon.aes=aes(size=1 - borders)) +
        scale_fill_gradientn(name="Reliability\n(Demand)", colours=c("#f7fcb9", "#78c679", "#006837"), values=c(0, .5, 1), labels = scales::percent, limits=c(0, 1)) +
                                        #scale_colour_gradient(name="Reliability\n(Model)", low="#000000", high="#FFFFFF", labels=scales::percent, limits=c(0, 1)) +
    scale_colour_gradientn(name="Reliability\n(Model)", colours=c("#FF0000FF", "#FF000080", "#FF000000"), values=c(0, .9, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_size(range=c(0, .5)) + guides(size=F) +
        theme(legend.justification=c(1,0), legend.position=c(1,0),
              panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
              axis.text.x=element_blank(), axis.text.y=element_blank(),
              plot.margin=unit(rep(0, 4), "cm")) +
        scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
    hh <- ggdraw(gg)
    hh + draw_grob(gl, 0.05, 0.02, 0.27, 0.2)
    ggsave(paste0("reliable-", suffix, ".pdf"), width=5.9, height=3.2)
}

plot.failavail <- function(fips, failurefrac, failurefrac.worst, naturalflow, naturalflow.worst, suffix, force.disjunct=F) {
    naturalflow[failurefrac > 0 & naturalflow > .37] <- .34
    naturalflow.worst[failurefrac.worst > 0 & naturalflow.worst > .37] <- .34

    gl <- rasterGrob(readPNG("failfrac-legend.png"), interpolate=TRUE)
    gg <- gg.usmap(failurefrac, fips, failurefrac.worst, extra.polygon.aes=aes(size=borders)) +
        scale_fill_gradientn(name="Failure\nFraction", colours=c("#91bfdb", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_colour_gradientn(name="Failure\nFraction", colours=c("#91bfdb", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_size(range=c(0, .5)) + guides(size=F) +
        theme(legend.justification=c(1,0), legend.position=c(1,0),
              panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
              axis.text.x=element_blank(), axis.text.y=element_blank(),
              plot.margin=unit(rep(0, 4), "cm")) + scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
    hh <- ggdraw(gg)
    hh + draw_grob(gl, 0.05, 0.02, 0.22, 0.2)
    ggsave(paste0("failfrac-", suffix, ".pdf"), width=5.9, height=3.2)

    gl <- rasterGrob(readPNG("natflowa-legend.png"), interpolate=TRUE)
    gg <- gg.usmap(naturalflow, fips, naturalflow.worst, extra.polygon.aes=aes(size=1 - borders)) +
        scale_fill_gradientn(name="Natural\nFlow\nAvailable", colours=c("#fee090", "#fee090", "#abd9e9", "#74add1", "#313695"), values=c(0, .37, .37001, .685, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_colour_gradientn(name="Natural\nFlow\nAvailable", colours=c("#fee090", "#fee090", "#abd9e9", "#74add1", "#313695"), values=c(0, .37, .37001, .685, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_size(range=c(0, .5)) + guides(size=F) +
        theme(legend.justification=c(1,0), legend.position=c(1,0),
              panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
              axis.text.x=element_blank(), axis.text.y=element_blank(),
              plot.margin=unit(rep(0, 4), "cm")) +
        scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
    hh <- ggdraw(gg)
    hh + draw_grob(gl, 0.05, 0.02, 0.22, 0.2)
    ggsave(paste0("natflowa-", suffix, ".pdf"), width=5.9, height=3.2)
}
