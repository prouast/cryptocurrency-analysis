rm(list=ls(all=TRUE))

# install.packages("RSQLite")
# install.packages("ggplot2")
# install.packages("corrplot")
library(DBI)
library(ggplot2)
library(corrplot)

### Import data from sqlite and prepare
con <- dbConnect(RSQLite::SQLite(), dbname='database.db')
coins <- dbGetQuery(con, "SELECT * FROM coin")
vals <- dbGetQuery(con, "SELECT * FROM vals")
vals$id <- NULL # Drop database IDs
coins$id <- NULL # Drop database IDs
rm(con) # Close database connection
vals$datetime <- as.Date(vals$datetime) # Format dates
vals <- vals[!duplicated(vals[,6:7]),] # Remove duplicates/one price per day
vals <- vals[order(vals$coin_slug,vals$datetime),]; rownames(vals) <- 1:nrow(vals) # Sort

### Analysis

# Calculate returns
vals$return <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) c(0,diff(vals[vals$coin_slug==x,]$price_usd)/(vals[vals$coin_slug==x,]$price_usd)[-length(vals[vals$coin_slug==x,]$price_usd)])))
vals$logreturn <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) c(0,log(vals[vals$coin_slug==x,]$price_usd[-1]/vals[vals$coin_slug==x,]$price_usd[-length(vals[vals$coin_slug==x,]$price_usd)]))))

# Calculate weighted market returns
weighted.return <- function(data) {
  dates <- unique(data$datetime)
  returns <- sapply(dates, FUN=function(x) (data[data$datetime==x,]$return %*% data[data$datetime==x,]$market_cap_usd) / sum(data[data$datetime==x,]$market_cap_usd))
  logreturns <- sapply(dates, FUN=function(x) (data[data$datetime==x,]$logreturn %*% data[data$datetime==x,]$market_cap_usd) / sum(data[data$datetime==x,]$market_cap_usd))
  result <- data.frame(datetime=dates, weighted.return=returns, weighted.logreturn=logreturns)
  result <- result[order(result$datetime),] # Sort
  return(result)
}
market <- weighted.return(vals)

# Calculate betas
coin.beta <- function(coin, data, market) {
  dates <- intersect(data[data$coin_slug==coin,]$datetime, market$datetime)
  return(cov(data[data$coin_slug==coin & data$datetime %in% dates,]$return,
             market[market$datetime %in% dates,]$weighted.return)/var(market[market$datetime %in% dates,]$weighted.return))
}
coins$beta <- sapply(coins$slug, FUN=coin.beta, vals, market)

# Fetch latest market capitalisation per coin
coins$mcap <- sapply(coins$slug, FUN=function(x) vals[vals$coin_slug==x & vals$datetime==max(vals[vals$coin_slug==x,]$datetime),]$market_cap_usd)
coins <- coins[order(coins$mcap,coins$slug, decreasing=TRUE),]; rownames(coins) <- 1:nrow(coins) # Sort

### Plots

# Generates a dataframe with complete daily information for a set of coins
analysis.data <- function(coins, data, market=NULL) {
  temp <- lapply(coins, FUN=function(x) subset(data, coin_slug==x))
  temp <- Reduce(function(df1, df2) merge(df1, df2, by="datetime"), temp)
  if (length(coins) > 1)
    colnames(temp) <- c("datetime", sapply(coins, function(slug) sapply(colnames(vals)[c(1:5,7:9)], function(x) paste(x, slug, sep="_"))))
  if (!is.null(market))
    temp <- merge(temp, market, by="datetime")
  data.frame(temp)
}

# Generates a dataframe with daily returns for a set of coins
analysis.return.data <- function(coins, data) {
  data <- reshape(data[data$coin_slug %in% coins,c(6:8)], direction="wide", idvar="datetime", timevar="coin_slug")
  colnames(data) <- c("datetime", sort(coins))
  data <- data[,c("datetime", coins)]
  return(data)
}
corrplot(cor(analysis.return.data(coins[1:50,]$slug,vals)[,-1], use = "pairwise.complete.obs"), method="ellipse")

# Plot return timelines
plot.return.timeline <- function(coins, data) {
  p <- ggplot(data[data$coin_slug %in% coins,], aes(datetime, return, color=factor(coin_slug)))
  p + geom_line() + 
    labs(title="Cryptocurrency returns", x="Date", y="Return") +
    theme(legend.title=element_blank())
}
plot.return.timeline(c("bitcoin","ethereum","ripple"), vals)

# Plot market return timeline
plot.market.return.timeline <- function(market) {
  p <- ggplot(market, aes(datetime, weighted.return))
  p + geom_line() + 
    labs(title="Cryptocurrency market return", x="Date", y="Return") +
    theme(legend.title=element_blank())
}
plot.market.return.timeline(market)

# Plot returns against each other
plot.return.vs.return <- function(coin1, coin2, data) {
  data <- analysis.data(c(coin1, coin2), data)
  cor_ <- cor(data[[paste("return_",coin1,sep="")]], data[[paste("return_",coin2,sep="")]])
  p <- ggplot(data, aes_string(x=paste("return_",coin1,sep=""), y=paste("return_",coin2,sep="")))
  p + geom_point() +
    labs(title=paste("Returns: ",coin1," vs ",coin2," (cor = ",round(cor_, digits=4),")",sep=""), x=paste(coin1, "Return"), y=paste(coin2, "Return")) +
    theme(legend.title=element_blank())
}
plot.return.vs.return("bitcoin", "ethereum", vals)

# Plot return against weighted market return
plot.return.vs.market <- function(coin, data, market) {
  data <- analysis.data(coin, data, market)
  cor_ <- cor(data$return, data$weighted.return)
  p <- ggplot(data, aes(x=return, y=weighted.return))
  p + geom_point() +
    labs(title=paste("Returns: ",coin," vs Market (cor = ",round(cor_, digits=4),")",sep=""), x=paste(coin, "return"), y="Market return") +
    theme(legend.title=element_blank())
}
plot.return.vs.market("ethereum", vals, market)

# Plot betas of top currencies against latest market cap
plot.beta.vs.mcap.num <- function(num, coins) {
  data <- coins[order(coins$mcap, decreasing=TRUE),] # Sort
  data <- data[0:num,]
  breaks <-  10**(1:10 * 0.5)
  p <- ggplot(data, aes(x=mcap, y=beta))
  p + geom_point() +
    scale_x_log10() +
    geom_text(aes(label=name),hjust=0, vjust=0) +
    labs(title="Beta vs Market capitalisation", x="Market capitalisation [USD] (log scale)", y="Beta") +
    theme(legend.title=element_blank())
}
plot.beta.vs.mcap.num(25, coins)
