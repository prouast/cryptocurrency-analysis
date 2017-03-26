# Import sqlite database

# install.packages("RSQLite")
library("RSQLite")
con <- dbConnect(drv="SQLite", dbname="database.db")
alltables <- dbListTables(con)
currencies <- dbGetQuery(con, "SELECT * FROM currency")
vals <- dbGetQuery(con, "SELECT * FROM vals")