# cryptocurrency-analysis

## About

Having followed the cryptocurrency market for a while now, I decided to do some exploring in the data available from [coinmarketcap](https://coinmarketcap.com).
Especially in light of the increasing number of successful coins and [decreasing Bitcoin dominance in terms of market capitalisation](https://coinmarketcap.com/charts/#btc-percentage), I assume many investors are eager to understand the dynamics in this market.

## Progress

*Data from 09/04/2017*

This is a work in progress. Steps taken so far:

1. Obtain and clean data from [coinmarketcap](https://coinmarketcap.com) using [coinmarketcap-scraper](https://github.com/prouast/coinmarketcap-scraper)

2. Calculate **daily returns** for each coin.

	- Using this data, we can plot the returns for arbitrary coins on a time axis. Example: **Returns for bitcoin, ethereum and ripple**

	![Returns for bitcoin, ethereum and ripple](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Coin-returns.png?style=centerme)

	- This also allows us to investigate the correlations between arbitrary coins. Example: **Plotting bitcoin vs ethereum returns**
	
	![Returns for bitcoin vs ethereum](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Bitcoin-vs-ethereum-returns.png?style=centerme)

	- Finally, we can look at pairwise correlations between all coins: **Visualisation of the correlation matrix for top 20 cryptocurrencies**
	
	![Corrplot](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Corrplot.png?style=centerme)

3. Calculate overall **market returns** by weighting individual returns with market capitalisations.
   This series is initially dominated by bitcoin, with more altcoin influence as their market capitalisations increase.

	- Corresponding to the first plot, we can now give a plot of the overall **Market return** across time:

	![Market return](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Market-return.png?style=centerme)

	- Similarly, we can investigate the correlation of arbitrary coins with the market return. Example: **Plotting ethereum vs market return**
	
	![Market return](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Ethereum-vs-market-return.png?style=centerme)
	
4. Calculate coin `beta` to characterise the behaviour of each coin return with respect to the market return.

	- Beta represents the covariance of coin returns and market returns, scaled by the variance of the market returns.
	  See [Wikipedia](https://en.wikipedia.org/wiki/Capital_asset_pricing_model) for more information.
	  	  
	- Here, we plot coin betas against market capitalisations for the top 15 coins in terms of market capitalisation.
	
	![Beta vs Mcap](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Ethereum-vs-market-return.png?style=centerme)