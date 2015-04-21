// Calculates odds based on matched trades by selection and time window.  Odds returned as implied probability
getChances:{[a]
  t:.gw.syncexec[({select time,marketName,selectionId,price,size from trade where sym=x};a`sym);`hdb`rdb];
  q:select `s#time+00:00:01,`g#selectionId,`g#price,previousSize:size from t;
  r:aj[`selectionId`price`time;t;q];
  r:update traded:size-previousSize from r;
  r:select last marketName,odds:traded wavg price by time,selectionId from r;
  r:update odds:(fills;odds) fby selectionId from 0!r;
  :update chance:100*1%odds from r;
 };

// Same as getChances but pivoted
getChancesPivot:{[a]
  r:getChances a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!chance) by date:time from r;            // pivot
  :r; 
 };

// Returns the mid for each selection
getMid:{[a]
  r:.gw.syncexec[({select time,marketName,selectionId,side,price,size from quote where sym=x};a`sym);`hdb`rdb];
  r:select mid:0.5*(max price where side=`back)+(min price where side=`lay) by time,selectionId from r;
  r:update chance:100*1%mid from r;
  :r;
 };

// Same as getMid but pivoted
getMidPivot:{[a]
  r:getMid a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!chance) by date:time from r;            // pivot
  :r; 
 };

// Returns the volume traded by selection and time window
getVolume:{[a]
  r:.gw.syncexec[({select sum size by time,selectionId from trade where sym=x};a`sym);`hdb`rdb];
  :`time`selectionId`totalVol`volPerMin xcol update volpermin:deltas[size]*0D00:01%(deltas time) by selectionId from 0!r;
 };

// Same as getVolume but pivoted
getVolumePivot:{[a]
  r:getVolume a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!volPerMin) by date:time from r;       // pivot
  :r; 
 };

// Returns the spread by selection and time
getSpread:{[a]
  r:.gw.syncexec[({select time,marketName,selectionId,side,?[side=`lay;neg price;price],size from quote where sym=x};a`sym);`hdb`rdb];
  r:select last marketName,abs max price by time,selectionId,side from r;
  r:enlist[`price] _ update mid:avg each price, spread:last each deltas each(0Nf,/:price) from 0!select last marketName, price by time,selectionId from r;
  :r;
  };

// Same as getVolume but pivoted
getSpreadPivot:{[a]
  r:getSpread a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!spread) by date:time from r;       // pivot
  :r; 
 };


getEvents:{[]
  r:.gw.syncexec[({select distinct sym from trade};`);`hdb`rdb];
  :r;
 };
