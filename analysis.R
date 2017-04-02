# install.packages("RSQLite")
library(DBI)
library(scales)
library(ggplot2)

### Import data from sqlite and prepare
con <- dbConnect(RSQLite::SQLite(), dbname='database.db')
currencies <- dbGetQuery(con, "SELECT * FROM currency")
vals <- dbGetQuery(con, "SELECT * FROM vals")
vals$id <- NULL # Drop database IDs
currencies$id <- NULL # Drop database IDs
rm(con) # Close database connection
vals$datetime <- as.Date(vals$datetime) # Format dates
vals <- vals[!duplicated(vals[,6:7]),]
vals <- vals[order(vals$currency_slug,vals$datetime),] # Sort

### Analysis

# Calculate returns
vals$return <- Reduce(c,sapply(unique(vals$currency_slug), FUN=function(x) c(0,diff(vals[vals$currency_slug==x,]$price_usd)/(vals[vals$currency_slug==x,]$price_usd)[-length(vals[vals$currency_slug==x,]$price_usd)])))

# Calculate weighted market returns
weighted.return <- function(data) {
  dates <- unique(data$datetime)
  returns <- sapply(dates, FUN=function(x) (data[data$datetime==x,]$return %*% data[data$datetime==x,]$market_cap_usd) / sum(data[data$datetime==x,]$market_cap_usd))
  result <- data.frame(datetime=dates, weighted.return=returns)
  result <- result[order(result$datetime),] # Sort
  return(result)
}
market <- weighted.return(vals)

# Calculate betas
currency.beta <- function(currency, data, market) {
  dates <- intersect(data[data$currency_slug==currency,]$datetime, market$datetime)
  return(cov(data[data$currency_slug==currency & data$datetime %in% dates,]$return,
             market[market$datetime %in% dates,]$weighted.return)/var(market[market$datetime %in% dates,]$weighted.return))
}
currencies$beta <- sapply(currencies$slug, FUN=currency.beta, vals, market)

# Plot return against weighted market return
plot.returns <- function(currency, data, market) {
  dates <- intersect(data[data$currency_slug==currency,]$datetime, market$datetime)
  plot(market[market$datetime %in% dates,]$weighted.return ~ data[data$currency_slug==currency & data$datetime %in% dates,]$return,
       xlab=currency, ylab="Weighted market return")
}
plot.returns("bitcoin", vals, market)

# Generates a dataframe with complete daily information for a set of currencies
analysis.data <- function(currencies, data) {
  temp <- lapply(currencies, FUN=function(x) subset(data, currency_slug==x))
  temp <- Reduce(function(df1, df2) merge(df1, df2, by="datetime"), temp)
  colnames(temp) <- c("datetime", sapply(currencies, function(slug) sapply(colnames(vals)[c(1:5,7)], function(x) paste(x, slug, sep="_"))))
  data.frame(temp)
}
# Bitcoin vs Ethereum
temp <- analysis.data(c("bitcoin","ethereum"), vals)
cor(temp$price_usd_bitcoin, temp$price_usd_ethereum)
plot(temp$price_usd_ethereum~temp$price_usd_bitcoin)
# Bitcoin vs Ripple
temp <- analysis.data(c("bitcoin","ripple"), vals)
cor(temp$price_usd_bitcoin, temp$price_usd_ripple)
plot(temp$price_usd_ripple~temp$price_usd_bitcoin)
# Ethereum vs Dash
temp <- analysis.data(c("ethereum","dash"), vals)
cor(temp$price_usd_dash, temp$price_usd_ethereum)
plot(temp$price_usd_dash~temp$price_usd_ethereum)
