CREATE TABLE IF NOT EXISTS currency (
	id					INTEGER		PRIMARY KEY,
	name				CHAR(50)	NOT NULL,
	symbol				CHAR(4) 	NOT NULL
);

CREATE TABLE IF NOT EXISTS vals (
	id					INTEGER 	PRIMARY KEY,
	rank				INT			NOT NULL,
	price_usd			DECIMAL		NOT NULL,
	price_btc			DECIMAL		NOT NULL,
	volume_24h_usd		DECIMAL		NOT NULL,
	market_cap_usd		DECIMAL		NOT NULL,
	available_supply	DECIMAL		NOT NULL,
	total_supply		DECIMAL		NOT NULL,
	percent_change_1h	DECIMAL		NOT NULL,
	percent_change_24h	DECIMAL		NOT NULL,
	percent_change_7d	DECIMAL		NOT NULL,
	last_updated		INT			NOT NULL,
	currency_id 		INT			NOT NULL,
	FOREIGN KEY(currency_id) REFERENCES currency(id) ON DELETE CASCADE ON UPDATE CASCADE
);