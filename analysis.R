### Import data from sqlite
# install.packages("RSQLite")
library(DBI)
con <- dbConnect(RSQLite::SQLite(), dbname='database.db')
currencies <- dbGetQuery(con, "SELECT * FROM currency")
vals <- dbGetQuery(con, "SELECT * FROM vals")
vals$id <- NULL # Drop database IDs
rm(con) # Close database connection
vals$datetime <- as.Date(vals$datetime)

### Plots with bitcoin
plot(vals[which(vals$currency_slug=='bitcoin'),]$price_usd, type="l")