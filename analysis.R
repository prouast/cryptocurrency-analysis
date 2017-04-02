rm(list=ls(all=TRUE))

# install.packages("RSQLite")
# install.packages("ggplot2")
library(DBI)
library(ggplot2)

### Import data from sqlite and prepare
con <- dbConnect(RSQLite::SQLite(), dbname='database.db')
currencies <- dbGetQuery(con, "SELECT * FROM currency")
vals <- dbGetQuery(con, "SELECT * FROM vals")
vals$id <- NULL # Drop database IDs
currencies$id <- NULL # Drop database IDs
rm(con) # Close database connection
vals$datetime <- as.Date(vals$datetime) # Format dates
vals <- vals[!duplicated(vals[,6:7]),] # Remove duplicates
vals <- vals[order(vals$currency_slug,vals$datetime),] # Sort

### Analysis

# Calculate returns
vals$return <- Reduce(c,sapply(unique(vals$currency_slug), FUN=function(x) c(0,diff(vals[vals$currency_slug==x,]$price_usd)/(vals[vals$currency_slug==x,]$price_usd)[-length(vals[vals$currency_slug==x,]$price_usd)])))
vals$logreturn <- Reduce(c,sapply(unique(vals$currency_slug), FUN=function(x) c(0,log(vals[vals$currency_slug==x,]$price_usd[-1]/vals[vals$currency_slug==x,]$price_usd[-length(vals[vals$currency_slug==x,]$price_usd)]))))

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
currency.beta <- function(currency, data, market) {
  dates <- intersect(data[data$currency_slug==currency,]$datetime, market$datetime)
  return(cov(data[data$currency_slug==currency & data$datetime %in% dates,]$return,
             market[market$datetime %in% dates,]$weighted.return)/var(market[market$datetime %in% dates,]$return))
}
currencies$beta <- sapply(currencies$slug, FUN=currency.beta, vals, market)

### Plots

# Generates a dataframe with complete daily information for a set of currencies
analysis.data <- function(currencies, data, market=NULL) {
  temp <- lapply(currencies, FUN=function(x) subset(data, currency_slug==x))
  temp <- Reduce(function(df1, df2) merge(df1, df2, by="datetime"), temp)
  if (length(currencies) > 1)
    colnames(temp) <- c("datetime", sapply(currencies, function(slug) sapply(colnames(vals)[c(1:5,7:9)], function(x) paste(x, slug, sep="_"))))
  if (!is.null(market))
    temp <- merge(temp, market, by="datetime")
  data.frame(temp)
}

# Plot return timelines
plot.return.timeline <- function(currencies, data) {
  p <- ggplot(data[data$currency_slug %in% currencies,], aes(datetime, return, color=factor(currency_slug)))
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
plot.return.vs.return <- function(currency1, currency2, data) {
  data <- analysis.data(c(currency1, currency2), data)
  cor_ <- cor(data[[paste("return_",currency1,sep="")]], data[[paste("return_",currency2,sep="")]])
  p <- ggplot(data, aes_string(x=paste("return_",currency1,sep=""), y=paste("return_",currency2,sep="")))
  p + geom_point() +
    labs(title=paste("Returns: ",currency1," vs ",currency2," (cor = ",round(cor_, digits=4),")",sep=""), x=paste(currency1, "Return"), y=paste(currency2, "Return")) +
    theme(legend.title=element_blank())
}
plot.return.vs.return("bitcoin", "ethereum", vals)

# Plot return against weighted market return
plot.return.vs.market <- function(currency, data, market) {
  data <- analysis.data(currency, data, market)
  cor_ <- cor(data$return, data$weighted.return)
  p <- ggplot(data, aes(x=return, y=weighted.return))
  p + geom_point() +
    labs(title=paste("Returns: ",currency," vs Market (cor = ",round(cor_, digits=4),")",sep=""), x=paste(currency, "return"), y="Market return") +
    theme(legend.title=element_blank())
}
plot.return.vs.market("ethereum", vals, market)

# Plot betas against latest market cap
# TODO
