rm(list=ls(all=TRUE))

# install.packages("RSQLite")
# install.packages("ggplot2")
# install.packages("corrplot")
# install.packages("zoo")
library(DBI)
library(ggplot2)
library(grid)
library(corrplot)
library(zoo)
library(magrittr)

### Import data from sqlite and prepare
con <- dbConnect(RSQLite::SQLite(), dbname='database.db')
coins <- dbGetQuery(con, "SELECT * FROM coin")
vals <- dbGetQuery(con, "SELECT * FROM vals")
vals$id <- NULL # Drop database IDs
coins$id <- NULL # Drop database IDs
rm(con) # Close database connection
vals$datetime <- as.Date(vals$datetime) # Format dates
vals <- vals[!duplicated(vals[,6:7]),] # Remove duplicates/one price per day
interpolate.missing.data <- function(data) {
  coins <- unique(data$coin_slug)
  newrows <- do.call("rbind", lapply(coins, FUN=missing.date.rows, data))
  data <- rbind(data, newrows)
  data <- data[order(data$coin_slug,data$datetime),]; rownames(data) <- 1:nrow(data) # Sort
  for (coin in coins) {
    idx <- colSums(!is.na(data[data$coin_slug==coin,1:5])) > 1
    data[data$coin_slug==coin,c(idx,FALSE,FALSE)] <- na.approx(data[data$coin_slug==coin,c(idx,FALSE,FALSE)], na.rm=FALSE)
  }
  return(data)
}
missing.date.rows <- function(coin, data) {
  dates <- unique(data[data$coin_slug==coin,6])
  alldates <- seq(dates[1],dates[length(dates)],by="+1 day")
  missingdates <- setdiff(alldates, dates)
  return(data.frame(price_usd=rep(NA, length(missingdates)),
                    price_btc=rep(NA, length(missingdates)),
                    volume_usd=rep(NA, length(missingdates)),
                    market_cap_usd=rep(NA, length(missingdates)),
                    available_supply=rep(NA, length(missingdates)),
                    datetime=as.Date(missingdates, origin="1970-01-01"),
                    coin_slug=rep(coin, length(missingdates))))
}
vals <- interpolate.missing.data(vals) # Insert missing dates and interpolate values

### Analysis

# Calculate returns
vals$return <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) c(0,diff(vals[vals$coin_slug==x,]$price_usd)/(vals[vals$coin_slug==x,]$price_usd)[-length(vals[vals$coin_slug==x,]$price_usd)])))
vals$logreturn <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) c(0,log(vals[vals$coin_slug==x,]$price_usd[-1]/vals[vals$coin_slug==x,]$price_usd[-length(vals[vals$coin_slug==x,]$price_usd)]))))

# Calculate market data
market.data <- function(vals) {
  dates <- sort(unique(vals$datetime))
  cap <- sapply(dates, FUN=function(date) sum(vals[vals$datetime==date,4]))
  returns <- c(0,diff(cap)/cap[-length(cap)])
  logreturns <- c(0,log(cap[-1]/cap[-length(cap)]))
  data.frame(datetime=dates, cap=cap, returns=returns, logreturns=logreturns)
}
market <- market.data(vals)

# Calculate Herfindahl index for each day
market$herfindahl <- sapply(market$datetime, FUN=function(date) sum((vals[vals$datetime==date,4]/sum(vals[vals$datetime==date,4]))^2))

# Calculate betas
coin.beta <- function(coin, data, market) {
  dates <- intersect(data[data$coin_slug==coin,]$datetime, market$datetime)
  return(cov(data[data$coin_slug==coin & data$datetime %in% dates,]$return,
             market[market$datetime %in% dates,]$returns)/var(market[market$datetime %in% dates,]$weighted.return))
}
coins$beta <- sapply(coins$slug, FUN=coin.beta, vals[vals$datetime>as.Date("2016-12-31"),], market)

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
corrplot(cor(analysis.return.data(coins[1:25,]$slug,vals[vals$datetime>as.Date("2016-12-31"),])[,-1],
             use = "pairwise.complete.obs"), method="ellipse")

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
  p <- ggplot(market, aes(datetime, returns))
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
plot.return.vs.return("bitcoin", "ethereum", vals[vals$datetime>as.Date("2016-12-31"),])

# Plot return against weighted market return
plot.return.vs.market <- function(coin, data, market) {
  data <- analysis.data(coin, data, market)
  cor_ <- cor(data$return, data$returns)
  p <- ggplot(data, aes(x=return, y=returns))
  p + geom_point() +
    labs(title=paste("Returns: ",coin," vs Market (cor = ",round(cor_, digits=4),")",sep=""), x=paste(coin, "return"), y="Market return") +
    theme(legend.title=element_blank())
}
plot.return.vs.market("ethereum", vals[vals$datetime>as.Date("2016-12-31"),], market)

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

# Plot total market cap and herfindahl index
plot.mcap.herfindahl <- function(market) {
  p1 <- ggplot(market, aes(datetime, cap)) + geom_line() + labs(x="Date", y="Market cap")
  p2 <- ggplot(market, aes(datetime, herfindahl)) + geom_line() + labs(x="Date", y="Herfindahl index")
  ## convert plots to gtable objects
  library(gtable)
  library(grid) # low-level grid functions are required
  g1 <- ggplotGrob(p1)
  #g1 <- gtable_add_cols(g1, unit(0,"mm")) # add a column for missing legend
  g2 <- ggplotGrob(p2)
  g <- rbind(g1, g2, size="first") # stack the two plots
  g$widths <- unit.pmax(g1$widths, g2$widths) # use the largest widths
  # center the legend vertically
  g$layout[grepl("guide", g$layout$name),c("t","b")] <- c(1,nrow(g))
  grid.newpage()
  grid.draw(g)
}
plot.mcap.herfindahl(market)
