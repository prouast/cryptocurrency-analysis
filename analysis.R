rm(list=ls(all=TRUE)) # Remove everything from environment

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

### 1. Import and clean daily closing prices for each coin

# Import from sqlite
con <- dbConnect(RSQLite::SQLite(), dbname='database.db') # Database connection
coins <- dbGetQuery(con, "SELECT * FROM coin") # Import coins
vals <- dbGetQuery(con, "SELECT * FROM vals") # Import values
rm(con) # Close database connection

# Clean and prepare data
vals$id <- NULL # Drop database IDs
coins$id <- NULL # Drop database IDs
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
vals <- interpolate.missing.data(vals) # For missing dates, insert fields and interpolate values (takes some time)

### 2. Calculate overall market statistics

## Calculate market statistics
# returns: return(t) = (price(t) - price(t-1)) / price(t-1)
# logreturns: logreturn(t) = ln(price(t)/price(t-1))
# annualized volatility: sd(logreturns per x days)*sqrt(trading days=365)
# herfindahl: sum of squares of competitor market shares
market.data <- function(data) {
  dates <- sort(unique(data$datetime))
  cap <- sapply(dates, FUN=function(date) sum(data[data$datetime==date,4]))
  returns <- c(0,diff(cap)/cap[-length(cap)])
  logreturns <- c(0,log(cap[-1]/cap[-length(cap)]))
  volatility.30d <- sapply(1:length(logreturns), FUN=function(i) sd(logreturns[(max(i-30,0):i)]))*sqrt(365)
  volatility.90d <- sapply(1:length(logreturns), FUN=function(i) sd(logreturns[(max(i-90,0):i)]))*sqrt(365)
  herfindahl <- sapply(dates, FUN=function(date) sum((data[vals$datetime==date,4]/sum(data[data$datetime==date,4]))^2))
  data.frame(datetime=dates, cap=cap, return=returns, logreturn=logreturns, volatility.30d=volatility.30d, volatility.90d=volatility.90d, herfindahl=herfindahl)
}
market <- market.data(vals)

# Plot market cap, market return, market volatility and herfindahl index
plot.market <- function(market) {
  p1 <- ggplot(market, aes(datetime, cap)) +
    geom_line() +
    labs(x="Date", y="Market cap", title="Overall market") +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank())
  p2 <- ggplot(market, aes(datetime, logreturn)) +
    geom_line() +
    labs(x="Date", y="Log return") +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank())
  p3 <- ggplot(market, aes(datetime, volatility.30d)) +
    geom_line() +
    labs(x="Date", y="Annualized volatility") +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank())
  p4 <- ggplot(market, aes(datetime, herfindahl)) + geom_line() + labs(x="Date", y="Herfindahl index")
  ## convert plots to gtable objects
  library(gtable)
  library(grid) # low-level grid functions are required
  g1 <- ggplotGrob(p1)
  g2 <- ggplotGrob(p2)
  g3 <- ggplotGrob(p3)
  g4 <- ggplotGrob(p4)
  g <- rbind(g1, g2, g3, g4, size="first") # stack the plots
  g$widths <- unit.pmax(g1$widths, g2$widths, g3$widths, g4$widths) # use the largest widths
  # center the legend vertically
  g$layout[grepl("guide", g$layout$name),c("t","b")] <- c(1,nrow(g))
  grid.newpage()
  grid.draw(g)
}
plot.market(market)

### 3. Calculate individual coin statistics

# Fetch latest market capitalisation per coin
coins$mcap <- sapply(coins$slug, FUN=function(x) vals[vals$coin_slug==x & vals$datetime==max(vals[vals$coin_slug==x,]$datetime),]$market_cap_usd)
coins <- coins[order(coins$mcap,coins$slug, decreasing=TRUE),]; rownames(coins) <- 1:nrow(coins) # Sort

# Calculate returns
vals$return <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) c(0,diff(vals[vals$coin_slug==x,]$price_usd)/(vals[vals$coin_slug==x,]$price_usd)[-length(vals[vals$coin_slug==x,]$price_usd)])))
vals$logreturn <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) c(0,log(vals[vals$coin_slug==x,]$price_usd[-1]/vals[vals$coin_slug==x,]$price_usd[-length(vals[vals$coin_slug==x,]$price_usd)]))))

# Calculate volatility (takes too long - do on demand in plot function)
#vals$volatility.30d <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) sapply(1:length(vals[vals$coin_slug==x,]$logreturn), FUN=function(i) sd(vals[vals$coin_slug==x,]$logreturn[(max(i-30,0):i)]))))
#vals$volatility.90d <- Reduce(c,sapply(unique(vals$coin_slug), FUN=function(x) sapply(1:length(vals[vals$coin_slug==x,]$logreturn), FUN=function(i) sd(vals[vals$coin_slug==x,]$logreturn[(max(i-90,0):i)]))))

# Plot coin cap, return and volatility
plot.coin <- function(data, slug) {
  data <- data[data$coin_slug==slug,]
  data$volatility.30d <- sapply(1:nrow(data), FUN=function(i) sd(data$logreturn[(max(i-30,0):i)]))*sqrt(365)
  p1 <- ggplot(data, aes(datetime, market_cap_usd)) +
    geom_line() +
    labs(x="Date", y="Market cap", title=slug) +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank())
  p2 <- ggplot(data, aes(datetime, logreturn)) +
    geom_line() + labs(x="Date", y="Log return") +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank())
  p3 <- ggplot(data, aes(datetime, volatility.30d)) + geom_line() + labs(x="Date", y="Annualized volatility")
  ## convert plots to gtable objects
  library(gtable)
  library(grid) # low-level grid functions are required
  g1 <- ggplotGrob(p1)
  g2 <- ggplotGrob(p2)
  g3 <- ggplotGrob(p3)
  g <- rbind(g1, g2, g3, size="first") # stack the plots
  g$widths <- unit.pmax(g1$widths, g2$widths, g3$widths) # use the largest widths
  # center the legend vertically
  g$layout[grepl("guide", g$layout$name),c("t","b")] <- c(1,nrow(g))
  grid.newpage()
  grid.draw(g)
}
plot.coin(vals, "bitcoin")

### 4. Comparing different coins directly

# Plot coin cap, return and volatility for multiple coins
plot.coins <- function(data, slugs) {
  data <- data[data$coin_slug %in% slugs,]
  data$volatility.30d <- Reduce(c,sapply(unique(data$coin_slug), FUN=function(x) sapply(1:length(data[data$coin_slug==x,]$logreturn), FUN=function(i) sd(data[data$coin_slug==x,]$logreturn[(max(i-30,0):i)]))))*sqrt(365)
  p1 <- ggplot(data, aes(datetime, market_cap_usd, color=factor(coin_slug))) +
    geom_line() +
    labs(x="Date", y="Market cap", title=paste(slugs, collapse=", ")) +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank(), legend.title=element_blank())
  p2 <- ggplot(data, aes(datetime, logreturn, color=factor(coin_slug))) +
    geom_line() +
    labs(x="Date", y="Log return") +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank(), legend.title=element_blank())
  p3 <- ggplot(data, aes(datetime, volatility.30d, color=factor(coin_slug))) +
    geom_line() +
    labs(x="Date", y="Annualized volatility")
  ## convert plots to gtable objects
  library(gtable)
  library(grid) # low-level grid functions are required
  g1 <- ggplotGrob(p1)
  g2 <- ggplotGrob(p2)
  g3 <- ggplotGrob(p3)
  g <- rbind(g1, g2, g3, size="first") # stack the plots
  g$widths <- unit.pmax(g1$widths, g2$widths, g3$widths) # use the largest widths
  # center the legend vertically
  g$layout[grepl("guide", g$layout$name),c("t","b")] <- c(1,nrow(g))
  grid.newpage()
  grid.draw(g)
}
plot.coins(vals, c("bitcoin","ethereum", "ripple"))

# Generates a dataframe with complete daily information for a set of coins
analysis.data <- function(coins, data, market=NULL) {
  temp <- lapply(coins, FUN=function(x) subset(data, coin_slug==x))
  temp <- Reduce(function(df1, df2) merge(df1, df2, by="datetime"), temp)
  if (length(coins) > 1)
    colnames(temp) <- c("datetime", sapply(coins, function(slug) sapply(colnames(data)[c(1:5,7:9)], function(x) paste(x, slug, sep="_"))))
  if (!is.null(market))
    temp <- merge(temp, market, by="datetime")
  data.frame(temp)
}

# Plot returns against each other
plot.return.vs.return <- function(coin1, coin2, data) {
  data <- analysis.data(c(coin1, coin2), data)
  cor_ <- cor(data[[paste("logreturn_",coin1,sep="")]], data[[paste("logreturn_",coin2,sep="")]])
  p <- ggplot(data, aes_string(x=paste("logreturn_",coin1,sep=""), y=paste("logreturn_",coin2,sep="")))
  p + geom_point() +
    labs(title=paste("Returns: ",coin1," vs ",coin2," (cor = ",round(cor_, digits=4),")",sep=""), x=paste(coin1, "Return"), y=paste(coin2, "Return")) +
    theme(legend.title=element_blank())
}
plot.return.vs.return("bitcoin", "ethereum", vals[vals$datetime>as.Date("2016-12-31"),])

# Generates a dataframe with daily returns for a set of coins
analysis.return.data <- function(coins, data) {
  data <- reshape(data[data$coin_slug %in% coins,c(6,7,9)], direction="wide", idvar="datetime", timevar="coin_slug")
  colnames(data) <- c("datetime", sort(coins))
  data <- data[,c("datetime", coins)]
  return(data)
}

# Plot the correlation matrix for top 25 coin returns
corrplot(cor(analysis.return.data(coins[1:25,]$slug,vals[vals$datetime>as.Date("2016-12-31"),])[,-1],
             use = "pairwise.complete.obs"), method="ellipse")

# Plot the correlation of two coins over time
plot.corr.timeline <- function(coin1, coin2, mindays, maxdays, data) {
  data <- analysis.data(c(coin1, coin2), data)
  data$corr <- sapply(1:nrow(data), FUN=function(i) if(i<mindays) return(NA) else cor(data[max(1,i-maxdays):i,9],data[max(1,i-maxdays):i,17]))
  p <- ggplot(data, aes(datetime, corr))
  p + geom_line() + labs(x="Date", y="Correlation", title=paste("Correlation timeline: ", paste(c(coin1, coin2), collapse=", ")))
}
plot.corr.timeline("ethereum", "bitcoin", 30, 90, vals)

### 5. Comparing coins with overall market

# Plot return against weighted market return
plot.return.vs.market <- function(coin, data, market) {
  data <- analysis.data(coin, data, market)
  cor_ <- cor(data$logreturn.x, data$logreturn.y)
  p <- ggplot(data, aes(x=logreturn.x, y=logreturn.y))
  p + geom_point() +
    labs(title=paste("Returns: ",coin," vs Market (cor = ",round(cor_, digits=4),")",sep=""), x=paste(coin, "return"), y="Market return") +
    theme(legend.title=element_blank())
}
plot.return.vs.market("ethereum", vals[vals$datetime>as.Date("2016-12-31"),], market)

# Calculate betas
coin.beta <- function(coin, data, market) {
  dates <- intersect(data[data$coin_slug==coin,]$datetime, market$datetime)
  return(cov(data[data$coin_slug==coin & data$datetime %in% dates,]$logreturn,
             market[market$datetime %in% dates,]$logreturn)/var(market[market$datetime %in% dates,]$logreturn))
}
coins$beta <- sapply(coins$slug, FUN=coin.beta, vals[vals$datetime>as.Date("2016-12-31"),], market)

# Plot betas of top currencies against latest market cap
plot.beta.vs.mcap.num <- function(num, coins) {
  data <- coins[order(coins$mcap, decreasing=TRUE),] # Sort
  data <- data[0:num,]
  p <- ggplot(data, aes(x=mcap, y=beta))
  p + geom_point() +
    scale_x_log10() +
    geom_text(aes(label=name),hjust=0, vjust=0) +
    labs(title="Beta vs Market capitalisation", x="Market capitalisation [USD] (log scale)", y="Beta") +
    theme(legend.title=element_blank())
}
plot.beta.vs.mcap.num(25, coins)

# Plot betas over time
plot.beta.timeline <- function(coins, mindays, maxdays, data, market) {
  data <- data[data$coin_slug %in% coins,]
  dates <- intersect(data$datetime, market$datetime)
  result <- data.frame(datetime=as.Date(rep(dates, times=length(coins)), origin="1970-01-01"), coin=rep(coins,each=length(dates)))
  result$beta <- Reduce(c, sapply(coins,
                           function(coin) sapply(dates,
                                          function(date) if(nrow(data[data$coin_slug==coin & date-maxdays<data$datetime & data$datetime<=date,])<mindays) return(NA) else coin.beta(coin, data[data$coin_slug==coin & date-maxdays<data$datetime & data$datetime<=date,], market))))
  p <- ggplot(result, aes(datetime, beta, color=factor(coin)))
  p + geom_line() + labs(x="Date", y="Beta", title=paste("Beta timeline: ", paste(coins, collapse=", "))) + theme(legend.title=element_blank())
}
plot.beta.timeline(c("bitcoin","ethereum","ripple"), 30, 90, vals, market)
