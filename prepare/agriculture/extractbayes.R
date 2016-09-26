setwd("~/projects/water/model/awash/prepare/agriculture")

fips <- read.csv("~/Dropbox/Agriculture Weather/posterior_distributions/fips_usa.csv")
crops <- c("Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat")

in.filenames <- c("coeff_alpha", "coeff_beta1", "coeff_beta2", "coeff_beta3", "coeff_beta4")
out.columns <- c("intercept", "time", "wreq", "gdds", "kdds")

for (crop in crops[-1]) { # XXX: [-1]
    df <- data.frame(fips=c(), coef=c(), mean=c(), serr=c())
    
    for (ii in 1:length(in.filenames)) {
        print(in.filenames[ii])
        values <- read.table(paste0("~/Dropbox/Agriculture Weather/posterior_distributions/", crop, "/", in.filenames[ii], ".txt"), header=F)
        values <- values[, 1:3111]

        averages <- as.numeric(colMeans(values))
        ranges <- as.numeric(apply(values, 2, sd))

        df <- rbind(df, data.frame(fips=fips$FIPS, coef=out.columns[ii], mean=averages, serr=ranges))
    }

    write.csv(df, paste0("../../data/agriculture/bayesian/", crop, ".csv"), row.names=F)
}

