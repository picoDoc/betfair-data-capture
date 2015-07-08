// Requestor config
.servers.enabled:1b
.servers.CONNECTIONS:enlist `tickerplant         // Requestor connects to the tickerplant
.servers.HOPENTIMEOUT:30000

// betfair login details (add your own here)
.requestor.username:"";
.requestor.password:"";
.requestor.appKey:"";

// add functions to the usage ignorelist
.usage.ignorelist,:(`.requestor.pollForMarketData;".requestor.pollForMarketData")
