setwd("~/research/water/awash6/analyses/addeds")
##load("../../data/counties/waternet/waternet.RData")
load("../../data/paleo/waternet/waternet.RData")

library(ncdf4)

ncin <- nc_open("../../data/cache/counties/contributing_runoff_by_gage.nc")
gages <- ncvar_get(ncin, "gage_id")
flows <- ncvar_get(ncin, "totalflow")

gage.names <- rep("", 22587)
for (ii in 2:length(gages))
    gage.names <- paste(gage.names, strsplit(gages[ii], "")[[1]], sep="")

gage.names <- gsub("\" *", "", gage.names)

network$next.name <- paste(network$collection[network$nextpt], network$colid[network$nextpt], sep='.')
network$next.name[is.na(network$nextpt)] <- NA

get.flows <- function(name) {
    flows[gage.names == name, ]
}

network$contrib <- NA
for (ii in 1:nrow(network)) {
    print(ii)
    if (is.na(network$nextpt[ii]))
        next

    yy <- get.flows(network$next.name[ii])
    xx <- get.flows(paste(network$collection[ii], network$colid[ii], sep='.'))

    network$contrib[ii] <- tryCatch({
        lm(yy ~ 0 + xx)$coeff[1]
    }, error=function(e) {
        NA
    })
}

library(ggplot2)

ggplot(network, aes(contrib)) +
    geom_histogram() + scale_x_log10(limits=c(.1, 10)) +
    theme_minimal() + xlab("Scaling of downstream, given upstream")

write.csv(data.frame(source=paste(network$collection, network$colid, sep='.'),
                     sink=network$next.name, factor=network$contrib),
          file="contribs.csv", row.names=F)
