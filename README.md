# cryptocurrency-analysis

## About

Having followed the cryptocurrency market for a while now, I decided to do some exploring in the data available from [coinmarketcap](https://coinmarketcap.com).
Especially in light of the increasing number of successful coins and [decreasing Bitcoin dominance in terms of market capitalisation](https://coinmarketcap.com/charts/#btc-percentage), I assume many investors are eager to understand the dynamics in this market.

To replicate, first head over to [coinmarketcap-scraper](https://github.com/prouast/coinmarketcap-scraper);
this lets you download data from [coinmarketcap](https://coinmarketcap.com) into a local database.
The script `analysis.R` can then be run on this database.

## Progress

*Data updated 03/09/2017. Some improvements, more to come.*

This is a work in progress. Steps taken so far:

1. Obtain and clean daily closing prices for each coin. This includes interpolation for missing data.

2. Use daily closing prices to calculate daily overall market statistics. For the sake of these calculations, the overall market is interpreted as an index/portfolio.

  - **Overall market capitalisation**: The sum of all coin valuations, i.e., closing prices multiplied with circulating supply as given by coinmarketcap. *Please note that this is a controversial metric.*

  - **Overall market return**: We use logarithmic returns to make daily changes in overall market value easily comparable. [More information.](https://en.wikipedia.org/wiki/Rate_of_return#Logarithmic_or_continuously_compounded_return)

  - **Overall market volatility**: The annualized overall market volatility illustrates the degree in variation of the changes in overall market capitalisation. For each day, the value is based on the logarithmic overall market returns of the last 30 days. [More information.](https://en.wikipedia.org/wiki/Volatility_(finance))

  - **Herfindahl index**: To illustrate the change in competition between coins. The Herfindahl index measures competition in a market by summing the squares of all competitor market shares. It ranges from 1/N (highly competitive) to 1 (high concentration), where N is the number of competitors. [More information.](https://en.wikipedia.org/wiki/Herfindahl_index)

    Here, we can observe how the market capitalisation has increased in 2017 by a factor of up to 20x.
    Up until the recent correction, this development was mirrored by an increase in competition. More recently, this development has stagnated.
    In the data on returns and volatility we find volatility clustering, which is common in financial time series: Times of relative calm, and times of sudden price movements.
    Looking at the annualized volatility series, the clusters of high volatility have generally been decreasing in magnitude. The hype of 2017 has caused slightly higher volatility again, however less than we observe for some periods between 2013 and 2015.
    Note that the annualized volatilities of stock indices such as the S&P 500 are typically much lower, compared to the early crypto days up to an **order of magnitude**.

	   ![Market statistics](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Market-statistics.png?style=centerme)

3. Calculate statistics for each individual coin.

  - **Market capitalisation**: A given coin's valuation, i.e., closing price multiplied with circulating supply as given by coinmarketcap. *Please note that this is a controversial metric.*

  - **Return**: The daily logarithmic return of a given coin.

  - **Volatility**: The annualized volatility of a given coin; based on the logarithmic return from the last 30 days.

    Example: **Bitcoin**.

    ![Bitcoin statistics](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Bitcoin-statistics.png?style=centerme)

4. Comparing different coins directly.

  - Using the already calculated statistics, we can plot daily market capitalisations, returns and volatilities of arbitrary coins on a time axis.

    Example: **Bitcoin, Ethereum and Ripple**.

    ![Comparing bitcoin, ethereum and ripple](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Coin-statistics.png?style=centerme)

  - We can also investigate the correlations between the daily returns of arbitrary coins. Correlation measures the linear relationship between two sets of data. A high positive value when comparing the daily returns of two coins indicates a strong positive linear relationship of the returns in the past.

    To illustrate the idea of correlation between two coin returns: **Plotting Bitcoin vs Ethereum returns**. Here, every point represents one day. Notice the slightly positive linear relationship? *Note that this plot is based on data from 2017 only.*

	  ![Returns bitcoin vs ethereum](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Bitcoin-vs-ethereum-returns.png?style=centerme)

	- To get a better idea of the current relationships between coin returns, we can look at pairwise correlations between all coins. The (symmetric) correlation matrix visualises the correlation for each pair of variables - from perfect positive linear relationship (blue) to perfect negative linear relationship (red).

    **Visualisation of the correlation matrix for top 25 cryptocurrencies**. *Note that this plot is based on data from 2017 only.*

	  ![Corrplot](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Corrplot.png?style=centerme)

5. Comparing individual coins with the overall market.

  - Similarly to a previous plot, we can investigate the correlation of arbitrary coin returns with the market return.

    Example: **Plotting Ethereum vs Market return**. *Note that this plot is based on data from 2017 only.*

    ![Returns eitcoin vs market](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Ethereum-vs-market-return.png?style=centerme)

  - Calculate coin `beta` to characterise the behaviour of each coin return with respect to the market return. Beta represents the covariance of coin returns and market returns, scaled by the variance of the market returns. See [Wikipedia](https://en.wikipedia.org/wiki/Capital_asset_pricing_model) for more information.

  - Investors use the information encoded in the beta coefficient to characterise an asset's volatility and tendency to move in accordance with the market index. `beta = 1` indicates that the asset moves exactly like the market index. [More information.](https://en.wikipedia.org/wiki/Beta_(finance)) Here, the market is dominated by bitcoin, hence bitcoin's beta is very close to 1 and a coin's beta can also be interpreted as a comparison to bitcoin's movement.

  - Here, we plot coin betas against market capitalisations for the top 20 coins in terms of market capitalisation. *Note that this plot is based on data from 2017 only.*

    ![Beta vs Mcap](https://raw.githubusercontent.com/prouast/cryptocurrency-analysis/master/Beta-vs-mcap.png?style=centerme)
