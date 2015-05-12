// Requestor service to go to betfair and grab data, then send it down to the tickerplant
\d .requestor

// init function
init:{[]
  .lg.o[`init;"Running initialization function"];
  getSessionToken[];						/ get sessionToken
  .lg.o[`init;"Setting up timer to refresh session"];
  .timer.rep[.z.p;0Wp;0D06:00:00;(`.requestor.getSessionToken;`);2h;"refresh the Session Token";1b]; / refresh it every 6 hrs
  runnerIds:: selectionIds:: metaData::enlist[`]!();		/ initialize some dictionaries
  .lg.o[`init;"Making connection the tickerplant"];
  .servers.startup[];						/ connect to the discovery and tp processes
  tp::.servers.gethandlebytype[`tickerplant;`any];
  .lg.o[`init;"Setting timer to poll betfair api for data"];  
  {.timer.rep[x`start;x`end;x`interval;(`.requestor.callGetMarketData;x`marketId);2h;"get betfair data";0b]}each markets; / add a job for each market in config
 };

// function to convert kdb dictionary into a string which can be passed as a command line parameter
jsonStringParam:{[d]
	/ - convert the dictionary into a json string
	jsonstr: .j.j[d];
	/ - do some platform specific formatting of the string so that it can be 
	/ - passed as a command line parameter on both DOS ans Unix-like systems
	$[.os.NT;ssr[jsonstr;"\"";"\\\""];"'",jsonstr,"'"]}
 
// function to get a new session token/id
getSessionToken:{[]
  / - validate username, password and appKey (cannot be empty)
  $[not count username;.lg.e[`getSessionToken;"Username cannot be empty. Please check code/settings/requestor.q"];
	not count password;.lg.e[`getSessionToken;"Password cannot be empty. Please check code/settings/requestor.q"];
	not count appKey;.lg.e[`getSessionToken;"AppKey cannot be empty. Please check code/settings/requestor.q"];()];
  .lg.o[`getSessionToken;"Attempting to login to betfair api"];
  loginResp: callApi[("login";appKey;jsonStringParam `username`password!(username;password))];
  $["SUCCESS" ~ respstr:loginResp`loginStatus;
	[.lg.o[`getSessionToken;"Login successful: ",st:loginResp`sessionToken];sessionToken:: st];
	.lg.e[`getSessionToken;"Login failed. Response was: ",respstr]]};

// function to get market data and send to tp for a given marketid
getMarketData:{[id]
  if[not(id)in key metaData;getMetaData id];	/ if we don't have metadata for this market go get it
  / - build json request dictionary
  reqd: buildMarketDataReq[id];
  / - call the api to get the data
  r: first callApi[("data";appKey;sessionToken;reqd)][`result][`runners];
  
  trades:raze {if[98h<>type t:x[`ex;`tradedVolume];:()];update selectionId:x`selectionId from t}each r; / grab trades data (if it's there)
  trades:formatMarketData[id;`trade;trades];
  
  quotes:raze {if[98h<>type t:x[`ex;`availableToBack];:()];update selectionId:x`selectionId,side:`back from t}each r; / grab quotes data (backers)
  quotes,:raze {if[98h<>type t:x[`ex;`availableToLay];:()];update selectionId:x`selectionId,side:`lay from t}each r; / grab quotes data (layers)
  quotes:formatMarketData[id;`quote;quotes];
  
  {neg[tp](`.u.upd;x;value flip y)}'[`trade`quote;(trades;quotes)];	/ push to the tp
 };

// function to replace selectionId with names, add in meta data, reorder cols
formatMarketData:{[id;tabname;data]
	if[() ~ data;:()]; 						/ if data is empty, then escape
   	data: update .requestor.selectionIds[id;selectionId] from data;	/ replace selectionId with selection names
 	data: flip[count[data] #/: `$ metaData[id]] ,' data;		/ add in meta data
	data:`sym xcol `name xcols data;				/ give it a sym cols to keep kdb happy
	cols[`. tabname] # update time:.z.p from data}			/ add time and reorder to match schema

// error trapped call to getMarketData
callGetMarketData:{[id]
  e:{.lg.e[`APING_CALL_FAILED;"call to betfair failed with error ",x]};
  @[getMarketData;id;e]};

// function to get meta data about given market id
getMetaData:{[id]
  / - build the json request dictionary
  reqd: buildMetaDataReq[id];
  / - calling the api 
  r: first callApi[("data";appKey;sessionToken;reqd)][`result];
  / - if no data returned, then escape
  if[ () ~ r;:()];
  selectionIds[id]:first each exec `$runnerName by selectionId from r`runners; / populate selectionIds,
  runnerIds[id]:exec `$runnerName by runnerId from update runnerId:metadata @' `runnerId from  r[`runners]; / runnerIds
  metaData[id]:r`event;						/ and some other stuff...
  metaData[id],:`marketName`eventType!(r`marketName;r[`eventType;`name])};

// function to build api request dictionary for metadata
buildMetaDataReq:{[id]
 / - filter dictionary
 filterd: enlist[`marketIds]! enlist string (),id;
 / - parameter dictionary (includes filterd dictionary)
 paramd: `filter`sort`maxResults`marketProjection!(filterd;"FIRST_TO_START";"1";("COMPETITION";"EVENT";"EVENT_TYPE";"RUNNER_DESCRIPTION";"RUNNER_METADATA"));
 / - main dictionary (includes paramd dictionary)
 buildJsonRpcDict["listMarketCatalogue";paramd]}

// function to build api request dictionary for market data
buildMarketDataReq:{[id]
 / - price projection dictionary
 priceP:`priceData`virtualise`rolloverStakes!(("EX_TRADED";"EX_ALL_OFFERS");0b;0b);
 / - parameter dictionary (includes priceP dictionary)
 paramd:`marketIds`priceProjection`orderProjection`matchProjection!(string (),id;priceP;"ALL";"ROLLED_UP_BY_PRICE");
 / - main dictionary (includes paramd dictionary)
 buildJsonRpcDict["listMarketBook";paramd]}

buildJsonRpcDict:{[api;paramd]
 jsonStringParam `jsonrpc`method`params`id!("2.0";"SportsAPING/v1.0/",api;paramd;1)}

// function to return a table of markets for a particular sports id
getMarketInfo:{[sportids;text]
 / - filter dictionary
 filter: enlist[`eventTypeIds]! enlist string (),sportids;
 if[count[text] and not "*" ~ first text; filter[`textQuery]:text];
 / - paramd dictionary
 paramd:`filter`maxResults`marketProjection!(filter;1000;("COMPETITION";"EVENT";"EVENT_TYPE";"RUNNER_DESCRIPTION";"RUNNER_METADATA"));
 / - build the json req dictionary
 req: buildJsonRpcDict["listMarketCatalogue";paramd];
 / - call the api
 data: callApi[("data";appKey;sessionToken;req)][`result];
 / - return a table with info for the markets
 select marketId, marketName, totalMatched, eventType:eventType @' `name, competition: competition @' `name, event: event @' `name  from data}

// function to call the betfair api for data requests
callApi:{[x]
 / - submit the request via the python handler
 data: first system " " sv enlist["python",$[.os.NT;"w";()]; .os.pth getenv[`KDBBIN],"/getData.py"] , (),x;
 / - check for errors returned by python handler
 if["ERROR:" ~ 6#data;.lg.e[`callApi;data]];
 / - convert the json string into a q dictionary
 data:.j.k data;
 / - check if the response has returned a result (otherwise it will have returned an error)
 $[`error in key data;
	/ - pull the error code and log the error in the process log
	.lg.e[`callApi;"ERROR response received from Betfair: ",data[`error;`data;`APINGException;`errorCode]];
	:data]}

// run initialization
\d .
.lg.o[`init;"Loading schema file"];
system .os.pth "l ",getenv[`KDBHOME],"/tick/database.q"; / grab schema
.requestor.init[]
