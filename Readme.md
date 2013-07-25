Betfair API-NG
===

Getting started is easy.

    var betfairy = require('betfairy');

    betfairy.login({ username: 'abc', password: '123', appKey: 'xxx' }, function(err, session) {
      if (err) throw err;
      session.listMarketCatalogue(...)
    });

Real life example.

    var settings = {
      appKey: 'aasdkfljsdf',
      username: 'user',
      password: 'pass',
      locale: 'en',
      currency: 'GBP',
      sessionToken: 'asdfasdf' // if you have a session token, there's no need to login
    };

    var params = {
      filter: {
        eventTypeIds: [ 1 ],
        marketTypeCodes: [ 'MATCH_ODDS' ],
        marketStartTime: {
            from: new Date(),
            to: new Date(+new Date()+86400000) // +24h
        }
      }
      maxResults: 100
    };

    var session = betfairy.openSession(settings);
    session.login(function(err) {
      if (err) throw err; // BetfairError with message, exception, response, request
      session.listMarketCatalogue(params, function(err, markets) {
        if (err) throw err; // BetfairError
        console.log("Got %d markets", markets.length);
      });
    });

Extra methods:

    var marketIds = [ '1.123', '1.456', ... ]; // lots of them

    var params = {
      filter: {
        eventTypeIds: [ 1 ],
        marketTypeCodes: [ 'MATCH_ODDS' ],
      },
      marketProjection: [ 'COMPETITION', 'EVENT', 'EVENT_TYPE', 'MARKET_START_TIME', 'MARKET_DESCRIPTION', 'RUNNER_DESCRIPTION' ]
    };

    session.listMarketCatalogueByMarketIds(marketIds, params,
      function done(err, markets) { console.log("Got %d markets", markets.length); },
      function partial(err, markets) { console.log("Got %d out of %d markets", markets.length, marketIds.length); });

MarketMonitor
---

Usage example.

    session.login('user', 'pass', function(err) {
      if (err) throw err;
      monitorMarkets(session);
    });

    function monitorMarkets(session) {
      var mgr = betfairy.MarketMonitor({
        interval: 15 * 60 * 1000, // 15 min, get all markets, can be function() { return 15000; }
        timerLoopInterval: 200,
        filter: { ... } // can be function e.g. soccer matches for the next 24 hours
      });

      mgr.on('error', function(err) { throw err; });

      mgr.on('add', function(market) { mgr.subscribe(market, 10 * 60 * 1000 /* 10 min */); });
      mgr.on('remove', function(market) { mgr.unsubscribe(market); });
      mgr.on('load', function(markets, newMarketIds, removedMarketId) { console.log('got so many new markets!') });

      mgr.on('update', function(market) {
        if (market.prices.totalMatched > 100000 /* 100k */) {
          mgr.subscribe(market, 1000); // every second now
        }

        if (market.startTime - new Date() < 2*60*60 /* < 2h */) {
          mgr.subscribe(market, 500); // 500ms
        }

        console.log(market.prices);
      });

      mgr.start()
    }