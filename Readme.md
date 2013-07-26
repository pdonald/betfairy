Betfair API-NG
==============

Quick start
-----------

```javascript
var betfair = require('betfairy');

betfair.login({ username: 'abc', password: '123', appKey: 'xxx' }, function(err, session) {
  if (err) throw err; // BetfairError with message, exception
  session.listMarketCatalogue(params, function(err, markets) {
    if (err) throw err; // BetfairError
    console.log("Got %d markets in %d ms", markets.length, this.duration);
  });
});
```

API
---

## Session

`betfairy.Session` has the following properties.

* appKey
* sessionToken
* locale
* currency
* auth
* options
* lastInvocationId

### Create

You can create a new instance directly:
```javascript
var session = new betfairy.Session(options);
```
Or use a helper method:
```javascript
var session = betfairy.createSession(options); // aliases: openSession, newSession
```
If you prefer callbacks:
```javascript
betfairy.createSession(options, function(session) {
    // ...
});
```

`options` values are copied, it is not referenced.

```javascript
var options = {
  appKey: '123',
  sessionToken: 'asfasdfasdf134=', // if you have it, you don't need to log in
  locale: 'en', // it will be used for all api calls that support it
  currency: 'EUR', // it will be used for all api calls that support it
  username: 'user',
  password: 'pass',
  vendorSoftwareId: 123, // if you have one
  productId: 82, // free api
  locationId: 0
};
```

### Login

Use `session.login(options [, callback])` to log in. If you already had specified the username and password in `options`, you can use `session.login([callback])`, you can access them with `session.auth`. There's also `session.login(username, password [, vendorSotwareId [, productId [, locationId [, callback]]]])`.

The signature of `callback` is `callback(err, session)`.

If neither `productId` nor `vendorSotwareId` are specified, `productId` will be 82 which will use the Free Betfair API.

If you prefer, you can use a convenience method to create a session and login in just one function call:

```javascript
betfairy.login(options, function(err, session) {
  // ...
});
```

### Betting API

All Betting API methods are on the `session` object. If you want to be explicit, you can use `session.betting`.

```javascript
session.listEvents(function(err, events) { });
session.betting.listEvents(function(err, events) { });
```

The following methods have been implemented and unit tested:

* listEventTypes
* listEvents
* listCompetitions
* listCountries
* listVenues
* listTimeRanges
* listMarketTypes
* listMarketCatalogue
* listMarketBook

All methods accept two arguments: `params` and optionally `callback`. If a method has an optional `locale` or `currency`, the one set in `options` will be used if there's one, otherwise the default (usually, set in account preferences) will be used.

New or unsupported methods can be called like this:

```javascript
session.betting.invokeMethod('newMethod', params, callback);
```

There is a limit of how much information you can request. If the request weight is higher than 200, you will get an error. You can use the non-API method `listMarketCatalogueByMarketIds` to load information about many markets in one function call that will batch market ids and issue multiple requests so that they never exceed the max weight.

```javascript
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
```

### Accounts API

All methods are available on `session` or `session.account`.

The follwing methods have been implemented:

* getAccountFunds
* getAccountDetails
* createDeveloperApp
* getDeveloperKeys

## Invocation

Each API method returns an invocation object. You can use it to debug the API call. It's also bound to the callback function as `this`.

```javascript
var invocation = session.listEvents(params, function(err, events) {
  console.log("Took %d ms", this.duration); // this = invocation
});
console.log(invocation.request);
```

Invocation object looks like this:

```javascript
var invocation = {
  id: 1, // sequential call id
  service: 'betting',
  method: 'listEvents',
  params: { filter: {} },
  request: {
    url: 'https://...',
    json: { /* ... */ },
    headers: { /* ... */ },
  },
  sent: new Date(),
  
  // these are populated when the response is received
  received: new Date(),
  duration: 200, // in milliseconds
  response: { /* ... */ }, // response.body is the returned json
  responseId: 1, /* should be the same as id */
  result: [ /* events */ ],
  error: new betfairy.Error() // if there was an error
};
```

## Error Handling

_TODO_

MarketMonitor
-------------

```javascript
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
```
