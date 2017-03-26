### Import data from sqlite
# install.packages("RSQLite")
library(DBI)
con <- dbConnect(RSQLite::SQLite(), dbname='database.db')
currencies <- dbGetQuery(con, "SELECT * FROM currency")
vals <- dbGetQuery(con, "SELECT * FROM vals")
vals$id <- NULL # Drop database IDs
rm(con) # Close database connection
vals$datetime <- as.Date(vals$datetime)

### Analysis
# Generates a dataframe with complete daily information for a set of currencies
analysis.data <- function(currencies, data) {
  temp <- lapply(currencies, FUN=function(x) subset(data, currency_slug==x))
  temp <- Reduce(function(df1, df2) merge(df1, df2, by="datetime"), temp)
  colnames(temp) <- c("datetime", sapply(currencies, function(slug) sapply(colnames(vals)[c(1:5,7)], function(x) paste(x, slug, sep="_"))))
  data.frame(temp)
}
# Example
temp <- analysis.data(c("bitcoin","ethereum","dash","pivx"), vals)



