library(dplyr)
library(ggplot2)
library(ggmap)
library(maps)
library(maptools)
library(tmap)      # package for plotting
library(readxl)    # for reading Excel
library(tmaptools) 
data(wrld_simpl)

result_path = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "paleo_10yrs_12months/")
setwd(result_path)

## Input run parameters
start_year=2001
end_year=2010
nyears=end_year-start_year+1
nmonths = 1
time_ind0 <- c(1:nyears*nmonths)

captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
max(abs(captures))
failuresin <- read.csv("failuresin.csv", header = F)
failurecon <- read.csv("failurecon.csv", header = F)

a1=apply(captures, MARGIN=2, FUN = sum)
b1=apply(failuresin, MARGIN=2, FUN = sum)
c1=apply(failurecon, MARGIN=2, FUN = sum)

result_path = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "paleo_10yrs_12months/")
setwd(result_path)

## Input run parameters
start_year=2001
end_year=2010
nyears=end_year-start_year+1
nmonths = 1
time_ind0 <- c(1:nyears*nmonths)

captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
max(abs(captures))
failuresin <- read.csv("failuresin.csv", header = F)
failurecon <- read.csv("failurecon.csv", header = F)

a2=apply(captures, MARGIN=2, FUN = sum)
b2=apply(failuresin, MARGIN=2, FUN = sum)
c2=apply(failurecon, MARGIN=2, FUN = sum)

df=data.frame(Time=rep(c(start_year:end_year),2), captures=c(a1, a2), failuresin=c(b1, b2), failurescon=c(c1, c2),
              type=c(rep('XXth', 10), rep('paleo', 10)))
df$diff=df$failuresin-df$failurescon

p<-ggplot(data=df, aes(x=Time))+
  geom_line(aes(y=captures, color=type))+
  geom_line(aes(y=diff, color=type))
p


p<-ggplot(data=df, aes(x=Time))+
  geom_line(aes(y=failuresin, color=type))+
  geom_line(aes(y=failurescon, color=type))
p

