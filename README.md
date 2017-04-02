# cryptocurrency-analysis

## About

Having followed the cryptocurrency market for a while now, I decided to do some exploring in the data available from [coinmarketcap](https://coinmarketcap.com).
Especially in light of the ever increasing number of successful coins and [decreasing Bitcoin dominance in terms of market capitalisation](https://coinmarketcap.com/charts/#btc-percentage), I assume many investors are eager to understand the dynamics of this market.

## Progress

This is a work in progress. Steps taken so far:

1. Obtain and clean data from [coinmarketcap](https://coinmarketcap.com) using [coinmarketcap-scraper](https://github.com/prouast/coinmarketcap-scraper)

2. Calculate **daily returns** for each coin

	**Returns for bitcoin, ethereum and ripple**

	![Returns for bitcoin, ethereum and ripple](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Coin-returns.png?style=centerme)

	**Plotting bitcoin vs ethereum returns**
	
	![Returns for bitcoin vs ethereum](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Bitcoin-vs-ethereum-returns.png?style=centerme)

	**Visualisation of the correlation matrix for top 20 cryptocurrencies**
	
	![Corrplot](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Corrplot.png?style=centerme)

3. Calculate overall **market returns** by weighting individual returns with market capitalisations. This series is initially dominated by bitcoin, with more altcoin influence as their market capitalisations increase. 

	**Market return**

	![Market return](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Market-return.png?style=centerme)

	**Plotting ethereum vs market return**
	
	![Market return](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Ethereum-vs-market-return.png?style=centerme)