# Import sqlite database

# install.packages("RSQLite")
library(DBI)
con <- dbConnect(RSQLite::SQLite(), dbname='database.db')
currencies <- dbGetQuery(con, "SELECT * FROM currency")
vals <- dbGetQuery(con, "SELECT * FROM vals")
