# Betfair API-NG

Betfair API-NG node.js module.

betfairy is pronounced as bet fairy.

## Quick start

```javascript
var betfair = require('betfairy');

var auth = {
  username: 'user',
  password: 'pass',
  appKey: 'Y0urAppl1c4t10nK3y',
  key: 'betfair.key',
  cert: 'betfair.crt'
};

var params = {
  filter: { eventTypeIds: [ 1 /* Soccer */ ], marketTypeCodes: [ 'MATCH_ODDS' ] },
  marketProjection: [ 'EVENT', 'COMPETITION' ],
  sort: 'FIRST_TO_START',
  maxResults: 100
};

betfair.login(auth, function(err) {
  if (err) throw err; // BetfairError with message, exception, code
  session.listMarketCatalogue(params, function(err, markets) {
    if (err) throw err; // BetfairError
    console.log("Got %d markets in %d ms", markets.length, this.duration);
  });
});
```

## Features

- [error handling](#error-handling)
- [statistics and debug information about API calls](#invocation)
- [fluent API](#fluent-api)
- [utilities for common tasks](#extensions)
- unit tests

JSON-RPC is used. Currently only read-only methods have been implemented.

## API

### Session

`betfairy.Session` will have the following public properties when initialized.

* `appKey` - your application key
* `appName` - your application name, used at login by Betfair for troubleshooting
* `sessionToken` - session token, assigned at login or if you have one you can bypass logging in
* `locale` - locale to use when not specified, two letter code e.g. `en`, `it`
* `currency` - currency to use when not specified, three letter code e.g. `GBP`, `EUR`
* `auth` - authentication details to use when logging in
* `auth.username` - your Betfair account username
* `auth.password` - your Betfair account password
* `auth.key` - path to or `Buffer` of your private key file
* `auth.cert` - path to or `Buffer` of your certificate
* `auth.pfx` - path to or `Buffer` of the file with your private key and certificate
* `auth.passphrase` - passphrase if your private key has one

#### Create

You can create a new instance directly

```javascript
var session = new betfairy.Session(options);
```

or use a helper method

```javascript
var session = betfairy.createSession(options); // aliases: openSession, newSession
```

and you can also use a callback

```javascript
betfairy.createSession(options, function(session) {
    // ...
});
```

`options` values are copied. You can have auth details (`username`, `password`, etc.) directly in `options` but they will be in `session.auth`.

```javascript
var options = {
  appName: 'bot',
  appKey: '123',
  username: 'user',
  password: 'pass',
  key: 'betfair.key', // will become fs.readFileSync('betfair.key')
  cert: 'betfairy.crt', // will become fs.readFileSync('betfair.crt')
  sessionToken: 'asfasdfasdf134=', // if you have it, you don't need to log in
  locale: 'en', // it will be used for all api calls that support it and don't have a value in params
  currency: 'EUR' // it will be used for all api calls that support it and don't have a value in params
};
```

#### Login

Use `session.login(options[, callback])` to log in. If you included auth details when creating a session, you can use `session.login([callback])`.

`callback` is `callback(err, session)`.

If you prefer, you can use a convenience method to create a session and login in just one function call:

```javascript
betfairy.login(options, function(err, session) {
  // ...
});
```

### Betting API

All Betting API methods are on the `session` object. If you want to be explicit, you can use `session.betting`.

```javascript
session.listEvents(function(err, events) { /* ... */ });
session.betting.listEvents(function(err, events) { /* ... */ });
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

### Accounts API

All methods are available on `session` and `session.account`.

The follwing methods have been implemented:

* getAccountFunds
* getAccountDetails
* createDeveloperApp
* getDeveloperKeys

New or unsupported methods can be called like this:

```javascript
session.account.invokeMethod('newMethod', params, callback);
```

### Invocation

Each API method returns an invocation object. You can use it to debug the API call. It's also bound to the callback function as `this`.

```javascript
var invocation = session.listEvents(params, function(err, events) {
  console.log("Took %d ms", this.duration); // this = invocation
});
console.log(invocation.request);
```

Invocation has the following properties:

* `id` of the invocation
* `request` - request that was sent to the API
* `request.host`, `request.path`, `request.headers`, etc. - request information
* `request.body` - original request body, can be JSON
* `request.bodyRaw` - actual serialized request body
* `request.req` - the underlying `https.ClientRequest` object
* `request.started` - date right before the request was start being sent
* `request.finished` - date when sending the request was finished
* `request.duration` - how long it took to perform the request
* `request.error` - the error, if there is one, that occured
* `response` - response from the API
* `response.statusCode`, `response.headers` - response information
* `response.body` - parsed response body, can be JSON
* `response.bodyRaw` - received response body
* `response.compressed` - whether compression was used
* `response.compressionRatio` - response length to compressed response length
* `response.raw` - the underlying `https.IncomingMessage` object
* `response.started` - date when started receiving response body
* `response.finished` - date when finished reading response
* `response.duration` - how long it took to get the response
* `response.error` - the error, if there is one, that occured
* `duration` - how long it took to make the API call
* `error` - the error, if there is one, that occured
* `result` - result of the api call that is given to the callback

Method invocations also have

* `service.name`, `service.url`, `service.prefix`, `service.version`
* `method`
* `params`


### Error handling

Callbacks follow the node.js conventions. If the first argument of the callback is not null, then an error had occured. All errors are instances of `betfairy.Error` and can be thrown and will include a stack trace.

`Error` will always have a `message`. If the error was an API exception, it'll have an `exception` with `errorCode` and `errorDetails`. If the error was a JSON-RPC error, it will have a `code`.

Invocations have an `error` property. There are also `request.error` and `response.error`.

## Fluent API

Betfair API is very ugly. Fluent API tries to solve this problem.

Instead of this

```javascript
session.listEvents(params, function(err, events) {
  if (err) throw err; // error handling
  events.forEach(function(event) {
    console.log(event.event.name + " starts at " + new Date(event.event.openDate)); // event.event.name <- ugly
  });
});
```

you can code like this

```javascript
var fluent = session.fluent();

fluent.events(filter, function(events) { // no err
  events.forEach(function(event) {
    console.log(event.name + " starts at " + event.openDate); // short and sweet
  });
});

fluent.on('error', function(err) {
  throw err; // error handling for all methods
});

fluent.on('invocation', function(inv) { // not implemented
  if (inv.method) {
    console.log(inv.method + ' took ' + inv.duration + ' ms'); // collect statistics for all api calls
  }
});
```

The following methods have been implemented and unit tested:

* `sports` (`listEventTypes`)
* `events` (`listEvents`
* `events.types` (`listEventTypes`)
* `competitions` (`listCompetitions`)
* `countries` (`listCountries`)
* `venues` (`listVenues`)
* `markets.types` (`listMarketTypes`)

## Extensions

## `listMarketCatalogueAll` and `listMarketBookAll`

There are limits on the amount of data requested in one request for `listMarketCatalogue` and `listMarketBook`.
You can read more about it [in the documentation](https://api.developer.betfair.com/services/webapps/docs/display/1smk3cen4v3lu3yomq5qye0ni/Market+Data+Request+Limits)

You can use the non-API method `listMarketCatalogueAll` to load information about many markets and not worry about exceeding limits.

```javascript
var params = {
  filter: {
    eventTypeIds: [ 1 ],
    marketTypeCodes: [ 'MATCH_ODDS' ],
  },
  marketProjection: [ 'COMPETITION', 'EVENT', 'EVENT_TYPE', 'MARKET_START_TIME', 'MARKET_DESCRIPTION', 'RUNNER_DESCRIPTION' ]
};

session.listMarketCatalogueAll(params,
  function done(err, markets) { console.log("Finished: got %d markets in %d requests", markets.length, this.requests); },
  function partial(err, markets) { console.log("Got %d markets", markets.length); });
```

Similarly `listMarketBookAll` will make sure that the limits are not exceeded when fetching prices for many markets.

### MarketMonitor

The idea behind MarketMonitor is that it periodically monitors Betfair for new markets
(e.g. soccer matches that start in the next 24 hours) and when a new market is added,
you can subscribe to it and the prices for these markets will be periodically updated.
If you have subscribed to many similar markets (i.e. all are MATCH_ODDS and updated every 2 seconds),
then MarketMonitor will batch all updates in one API call.

This example is out of date. See `lib/monitor.coffee` for details.

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

## TODO

- bet placement methods
- fluent api for filter
- fluent api for returned results (markets, prices)
- params & filter validation
- throttling, parallel requests, timeouts, retrying, reconnecting
- replay
- simulator
- create login cert
- create api key
