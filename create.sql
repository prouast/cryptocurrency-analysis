CREATE TABLE IF NOT EXISTS currency ( 
	id		INTEGER		PRIMARY KEY,
	name	CHAR(50)	NOT NULL,
	symbol	CHAR(4) 	UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS vals (
	id					INTEGER 	PRIMARY KEY,
	rank				INTEGER		NOT NULL,
	price_usd			DECIMAL		NOT NULL,
	volume_24h_usd		DECIMAL		NOT NULL,
	market_cap_usd		DECIMAL		NOT NULL,
	available_supply	DECIMAL		NOT NULL,
	total_supply		DECIMAL		NOT NULL,
	percent_change_1h	DECIMAL		NOT NULL,
	percent_change_24h	DECIMAL		NOT NULL,
	percent_change_7d	DECIMAL		NOT NULL,
	datestamp			TEXT		NOT NULL,
	currency_symbol		CHAR(4)		NOT NULL,
	FOREIGN KEY(currency_symbol) REFERENCES currency(symbol) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS stats (
	id									INTEGER	PRIMARY KEY,
	total_market_cap_usd				DECIMAL	NOT NULL,
 	total_24h_volume_usd				DECIMAL	NOT NULL,
  	bitcoin_percentage_of_market_cap	DECIMAL	NOT NULL,
  	active_currencies					INTEGER	NOT NULL,
  	active_assets						INTEGER	NOT NULL,
  	active_markets						INTEGER	NOT NULL
);