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

### 1. Import and clean daily closing prices for each currency

# Import from sqlite
con <- dbConnect(RSQLite::SQLite(), dbname='database.db') # Database connection
currencies <- dbGetQuery(con, "SELECT * FROM currency") # Import currencies
vals <- dbGetQuery(con, "SELECT * FROM val") # Import values
rm(con) # Close database connection

# Clean and prepare data
vals$id <- NULL # Drop database IDs
currencies$id <- NULL # Drop database IDs
vals$datetime <- as.Date(vals$datetime) # Format dates
vals <- vals[!duplicated(vals[,6:7]),] # Remove duplicates/one price per day
interpolate.missing.data <- function(data) {
  currencies <- unique(data$currency_slug)
  newrows <- do.call("rbind", lapply(currencies, FUN=missing.date.rows, data))
  data <- rbind(data, newrows)
  data <- data[order(data$currency_slug,data$datetime),]; rownames(data) <- 1:nrow(data) # Sort
  for (currency in currencies) {
    idx <- colSums(!is.na(data[data$currency_slug==currency,1:5])) > 1
    data[data$currency_slug==currency,c(idx,FALSE,FALSE)] <- na.approx(data[data$currency_slug==currency,c(idx,FALSE,FALSE)], na.rm=FALSE)
  }
  return(data)
}
missing.date.rows <- function(currency, data) {
  dates <- unique(data[data$currency_slug==currency,6])
  alldates <- seq(dates[1],dates[length(dates)],by="+1 day")
  missingdates <- setdiff(alldates, dates)
  return(data.frame(price_usd=rep(NA, length(missingdates)),
                    price_btc=rep(NA, length(missingdates)),
                    volume_usd=rep(NA, length(missingdates)),
                    market_cap_usd=rep(NA, length(missingdates)),
                    available_supply=rep(NA, length(missingdates)),
                    datetime=as.Date(missingdates, origin="1970-01-01"),
                    currency_slug=rep(currency, length(missingdates))))
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
  ggsave("Market-statistics.png", g, width=8, height=6, dpi=100, units="in")
}
plot.market(market)

### 3. Calculate individual currency statistics

# Fetch latest market capitalisation per currency
currencies$mcap <- sapply(currencies$slug, FUN=function(x) vals[vals$currency_slug==x & vals$datetime==max(vals[vals$currency_slug==x,]$datetime),]$market_cap_usd)
currencies <- currencies[order(currencies$mcap,currencies$slug, decreasing=TRUE),]; rownames(currencies) <- 1:nrow(currencies) # Sort

# Calculate returns
vals$return <- Reduce(c,sapply(unique(vals$currency_slug), FUN=function(x) c(0,diff(vals[vals$currency_slug==x,]$price_usd)/(vals[vals$currency_slug==x,]$price_usd)[-length(vals[vals$currency_slug==x,]$price_usd)])))
vals$logreturn <- Reduce(c,sapply(unique(vals$currency_slug), FUN=function(x) c(0,log(vals[vals$currency_slug==x,]$price_usd[-1]/vals[vals$currency_slug==x,]$price_usd[-length(vals[vals$currency_slug==x,]$price_usd)]))))

# Calculate volatility (takes too long - do on demand in plot function)
#vals$volatility.30d <- Reduce(c,sapply(unique(vals$currency_slug), FUN=function(x) sapply(1:length(vals[vals$currency_slug==x,]$logreturn), FUN=function(i) sd(vals[vals$currency_slug==x,]$logreturn[(max(i-30,0):i)]))))
#vals$volatility.90d <- Reduce(c,sapply(unique(vals$currency_slug), FUN=function(x) sapply(1:length(vals[vals$currency_slug==x,]$logreturn), FUN=function(i) sd(vals[vals$currency_slug==x,]$logreturn[(max(i-90,0):i)]))))

# Plot currency cap, return and volatility
plot.currency <- function(data, slug) {
  data <- data[data$currency_slug==slug,]
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
  ggsave("Bitcoin-statistics.png", g, width=8, height=6, dpi=100, units="in")
}
plot.currency(vals, "bitcoin")

### 4. Comparing different currencies directly

# Plot currency cap, return and volatility for multiple currencies
plot.currencies <- function(data, slugs) {
  data <- data[data$currency_slug %in% slugs,]
  data$volatility.30d <- Reduce(c,sapply(unique(data$currency_slug), FUN=function(x) sapply(1:length(data[data$currency_slug==x,]$logreturn), FUN=function(i) sd(data[data$currency_slug==x,]$logreturn[(max(i-30,0):i)]))))*sqrt(365)
  p1 <- ggplot(data, aes(datetime, market_cap_usd, color=factor(currency_slug))) +
    geom_line() +
    labs(x="Date", y="Market cap", title=paste(slugs, collapse=", ")) +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank(), legend.title=element_blank())
  p2 <- ggplot(data, aes(datetime, logreturn, color=factor(currency_slug))) +
    geom_line() +
    labs(x="Date", y="Log return") +
    theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank(), legend.title=element_blank())
  p3 <- ggplot(data, aes(datetime, volatility.30d, color=factor(currency_slug))) +
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
  ggsave("Coin-statistics.png", g, width=8, height=6, dpi=100, units="in")
}
plot.currencies(vals, c("bitcoin","ethereum", "ripple"))

# Generates a dataframe with complete daily information for a set of currencies
analysis.data <- function(currencies, data, market=NULL) {
  temp <- lapply(currencies, FUN=function(x) subset(data, currency_slug==x))
  temp <- Reduce(function(df1, df2) merge(df1, df2, by="datetime"), temp)
  if (length(currencies) > 1)
    colnames(temp) <- c("datetime", sapply(currencies, function(slug) sapply(colnames(data)[c(1:5,7:9)], function(x) paste(x, slug, sep="_"))))
  if (!is.null(market))
    temp <- merge(temp, market, by="datetime")
  data.frame(temp)
}

# Plot returns against each other
plot.return.vs.return <- function(currency1, currency2, data) {
  data <- analysis.data(c(currency1, currency2), data)
  cor_ <- cor(data[[paste("logreturn_",currency1,sep="")]], data[[paste("logreturn_",currency2,sep="")]])
  p <- ggplot(data, aes_string(x=paste("logreturn_",currency1,sep=""), y=paste("logreturn_",currency2,sep="")))
  p + geom_point() +
    labs(title=paste("Returns: ",currency1," vs ",currency2," (cor = ",round(cor_, digits=4),")",sep=""), x=paste(currency1, "Return"), y=paste(currency2, "Return")) +
    theme(legend.title=element_blank())
  ggsave("Bitcoin-vs-ethereum-returns.png", width=8, height=4, dpi=100, units="in")
}
plot.return.vs.return("bitcoin", "ethereum", vals[vals$datetime>as.Date("2016-12-31"),])  

# Generates a dataframe with daily returns for a set of currencies
analysis.return.data <- function(currencies, data) {
  data <- reshape(data[data$currency_slug %in% currencies,c(6,7,9)], direction="wide", idvar="datetime", timevar="currency_slug")
  colnames(data) <- c("datetime", sort(currencies))
  data <- data[,c("datetime", currencies)]
  return(data)
}

# Plot the correlation matrix for top 25 currency returns
png(filename="Corrplot.png", width=800, height=700, units="px")
corrplot(cor(analysis.return.data(currencies[1:25,]$slug,vals[vals$datetime>as.Date("2016-12-31"),])[,-1],
             use = "pairwise.complete.obs"), method="ellipse")
dev.off()

# Plot the correlation of two currencies over time
plot.corr.timeline <- function(currency1, currency2, mindays, maxdays, data) {
  data <- analysis.data(c(currency1, currency2), data)
  data$corr <- sapply(1:nrow(data), FUN=function(i) if(i<mindays) return(NA) else cor(data[max(1,i-maxdays):i,9],data[max(1,i-maxdays):i,17]))
  p <- ggplot(data, aes(datetime, corr))
  p + geom_line() + labs(x="Date", y="Correlation", title=paste("Correlation timeline: ", paste(c(currency1, currency2), collapse=", ")))
  ggsave("Corr-timeline.png", width=8, height=4, dpi=100, units="in")
}
plot.corr.timeline("bitcoin", "ethereum", 30, 90, vals)

### 5. Comparing currencies with overall market

# Plot return against weighted market return
plot.return.vs.market <- function(currency, data, market) {
  data <- analysis.data(currency, data, market)
  cor_ <- cor(data$logreturn.x, data$logreturn.y)
  p <- ggplot(data, aes(x=logreturn.x, y=logreturn.y))
  p + geom_point() +
    labs(title=paste("Returns: ",currency," vs Market (cor = ",round(cor_, digits=4),")",sep=""), x=paste(currency, "return"), y="Market return") +
    theme(legend.title=element_blank())
  ggsave("Ethereum-vs-market-return.png", width=8, height=4, dpi=100, units="in")
}
plot.return.vs.market("ethereum", vals[vals$datetime>as.Date("2016-12-31"),], market)

# Calculate betas
currency.beta <- function(currency, data, market) {
  dates <- intersect(data[data$currency_slug==currency,]$datetime, market$datetime)
  return(cov(data[data$currency_slug==currency & data$datetime %in% dates,]$logreturn,
             market[market$datetime %in% dates,]$logreturn)/var(market[market$datetime %in% dates,]$logreturn))
}
currencies$beta <- sapply(currencies$slug, FUN=currency.beta, vals[vals$datetime>as.Date("2016-12-31"),], market)

# Plot betas of top currencies against latest market cap
plot.beta.vs.mcap.num <- function(num, currencies) {
  data <- currencies[order(currencies$mcap, decreasing=TRUE),] # Sort
  data <- data[0:num,]
  p <- ggplot(data, aes(x=mcap, y=beta))
  p + geom_point() +
    scale_x_log10() +
    geom_text(aes(label=name),hjust=0, vjust=0) +
    labs(title="Beta vs Market capitalisation", x="Market capitalisation [USD] (log scale)", y="Beta") +
    theme(legend.title=element_blank())
  ggsave("Beta-vs-mcap.png", width=8, height=5, dpi=100, units="in")
}
plot.beta.vs.mcap.num(25, currencies)

# Plot betas over time
plot.beta.timeline <- function(currencies, mindays, maxdays, data, market) {
  data <- data[data$currency_slug %in% currencies,]
  dates <- intersect(data$datetime, market$datetime)
  result <- data.frame(datetime=as.Date(rep(dates, times=length(currencies)), origin="1970-01-01"), currency=rep(currencies,each=length(dates)))
  result$beta <- Reduce(c, sapply(currencies,
                           function(currency) sapply(dates,
                                          function(date) if(nrow(data[data$currency_slug==currency & date-maxdays<data$datetime & data$datetime<=date,])<mindays) return(NA) else currency.beta(currency, data[data$currency_slug==currency & date-maxdays<data$datetime & data$datetime<=date,], market))))
  p <- ggplot(result, aes(datetime, beta, color=factor(currency)))
  p + geom_line() + labs(x="Date", y="Beta", title=paste("Beta timeline: ", paste(currencies, collapse=", "))) + theme(legend.title=element_blank())
  ggsave("Beta-timeline.png", width=8, height=4, dpi=100, units="in")
}
plot.beta.timeline(c("bitcoin","ethereum","ripple"), 30, 90, vals, market)
