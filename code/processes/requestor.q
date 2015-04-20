// Requestor service to go to betfair and grab data, then send it down to the tickerplant


// init function
.requestor.init:{[]
  .requestor.getSessionToken[];													/ get sessionToken
  .timer.rep[.z.p;0Wp;0D06:00:00;(`.requestor.getSessionToken;`);2h;"refresh the Session Token";1b];				/ refresh it every 6 hrs
  .requestor.metaData:enlist[`]!();												/ initialize some dictionaries
  .requestor.selectionIds:enlist[`]!();
  .requestor.runnerIds:enlist[`]!();
  system"l ",getenv[`KDBHOME],"/tick/betfair.q";										/ grab schema
  .requestor.tp:hopen 5010;													/ connect to the tp
  {.timer.rep[x`start;x`end;x`interval;(`.requestor.callGetMarketData;x`marketId);2h;"get betfair data";0b]}each .requestor.markets;	/ add a jobs for each market in config
 };

// function to get a new session token/id
.requestor.getSessionToken:{[]
  .requestor.sessionToken:@[;`sessionToken].j.k first system" " sv ("bash $KDBBIN/getToken_curl.bash";.requestor.username;.requestor.password);
 };

// function to get market data and send to tp for a given marketid
.requestor.getMarketData:{[id]
  if[not(id)in key .requestor.metaData;.requestor.getMetaData string id];							/ if we don't ahve metadata get it
  r:system" "sv("bash $KDBBIN/marketdata_wget.bash";.requestor.appKey;.requestor.sessionToken;string id);			/ get market data through script
  r:.j.k 1_-1_first r;														/ format json
  / TODO refactor down this code
  trades:raze {if[98h<>type t:x[`ex;`tradedVolume];:()];update selectionId:x`selectionId from x[`ex;`tradedVolume]}each r`runners; / grab trades data (if it's there) 
  trades:update selectionId:.requestor.selectionIds[id]@selectionId from trades;						/ update with meta data
  trades:flip (`$.requestor.metaData[id]),flip trades;
  trades:`sym xcol `name xcols trades; 												/ give it sym cols to keep kdb happy
  trades:cols[trade]#update time:.z.p from trades;									/ add time and reorder from schema
  quotes:raze {if[98h<>type t:x[`ex;`availableToBack];:()];update selectionId:x`selectionId,side:`back from x[`ex;`availableToBack]}each r`runners;
  quotes,:raze {if[98h<>type t:x[`ex;`availableToLay];:()];update selectionId:x`selectionId,side:`lay from x[`ex;`availableToLay]}each r`runners;
  quotes:update selectionId:.requestor.selectionIds[id]@selectionId from quotes;						/ grab quotes data
  quotes:flip (`$.requestor.metaData[id]),flip quotes;										/ and add meta data
  quotes:`sym xcol `name xcols quotes;												/ add sym
  quotes:cols[quote]#update time:.z.p from quotes;									/ and reorder from schema
  {neg[.requestor.tp](`.u.upd;x;value flip y)}'[`trade`quote;(trades;quotes)];							/ push to the tp
 };

// error trapped call to getMarketData
.requestor.callGetMarketData:{[id]
  e:{.lg.e[`APING_CALL_FAILED;"call to betfair failed with error ",x]};
  @[.requestor.getMarketData;id;e];
 };

// function to get meta data about given market id
.requestor.getMetaData:{[id]
  r:system" "sv("bash $KDBBIN/metadata_wget.bash";.requestor.appKey;.requestor.sessionToken;id);
  r:.j.k 1_-1_first r;
  .requestor.selectionIds[`$id]:first each exec `$runnerName by selectionId from r`runners;
  .requestor.runnerIds[`$id]:exec `$runnerName by runnerId from update runnerId:`$value each metadata from r`runners;
  .requestor.metaData[`$id]:r`event;
  .requestor.metaData[`$id],:`marketName`eventType!(r`marketName;r[`eventType;`name]);
 };

// util function for finding market ids
.requestor.listIds:{[]
  /TODO
 };


// run initialization
.requestor.init[]
