getChances:{[a]
  t:.gw.syncexec[({select time,marketName,selectionId,price,size from trade where sym=x};a`sym);`hdb`rdb];
  q:select `s#time+00:00:01,`g#selectionId,`g#price,previousSize:size from t;
  r:aj[`selectionId`price`time;t;q];
  r:update traded:size-previousSize from r;
  r:select last marketName,odds:traded wavg price by time,selectionId from r;
  r:update odds:(fills;odds) fby selectionId from 0!r;
  :update chance:100*1%odds from r;
 };

getChancesD3:{[a]
  r:getChances a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!chance) by date:time from r;            // pivot
  :update -6_/:@[;4 7 10;:;"-- "]each string date from r;            // do some date formatting
 };

saveChancesD3:{[a]
  r:getChancesD3 a;
  f:`$":",getenv[`KDBHOME],"/data/",string[a`sym],"/chances.csv";
  f 0: "," 0: r;
 };

getMid:{[a]
  r:.gw.syncexec[({select time,marketName,selectionId,side,price,size from quote where sym=x};a`sym);`hdb`rdb];
  r:select mid:0.5*(max price where side=`back)+(min price where side=`lay) by time,selectionId from r;
  r:update chance:100*1%mid from r;
  :r;
 };

getMidD3:{[a]
  r:getMid a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!chance) by date:time from r;            // pivot
  :update -6_/:@[;4 7 10;:;"-- "]each string date from r;            // do some date formatting
 };

saveMidD3:{[a]
  r:getMidD3 a;
  f:`$":",getenv[`KDBHOME],"/data/",string[a`sym],"/mid.csv";
  f 0: "," 0: r;
 };

getVolume:{[a]
  r:.gw.syncexec[({select sum size by time,selectionId from trade where sym=x};a`sym);`hdb`rdb];
  :`time`selectionId`totalVol`volPerMin xcol update volpermin:deltas[size]*0D00:01%(deltas time) by selectionId from 0!r;
 };

getVolumeD3:{[a]
  r:getVolume a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!volPerMin) by date:time from r;       // pivot
  :update -6_/:@[;4 7 10;:;"-- "]each string date from r;            // do some date formatting
 };

saveVolumeD3:{[a]
  r:getVolumeD3 a;
  f:`$":",getenv[`KDBHOME],"/data/",string[a`sym],"/volume.csv";
  f 0: "," 0: r;
 };

getSpread:{[a]
  r:.gw.syncexec[({select time,marketName,selectionId,side,?[side=`lay;neg price;price],size from quote where sym=x};a`sym);`hdb`rdb];
  r:select last marketName,abs max price by time,selectionId,side from r;
  r:enlist[`price] _ update mid:avg each price, spread:last each deltas each(0Nf,/:price) from 0!select last marketName, price by time,selectionId from r;
  :update spread:100*spread%mid from r;
 };

// this will only work properly in two outcome events (basketball, american football etc.)
getBestOdds:{[a]
  r:.gw.syncexec[({select time,marketName,selectionId,side,price,size from quote where sym=x};a`sym);`hdb`rdb];
  s:exec distinct selectionId from r;
  r:update odds:100*1%price from r;
  r:update selectionId:{x y=x 0}[s] selectionId,odds:100-odds from r where side=`lay;
  r:select min odds by time,selectionId from r;
  :r;
 };

getBestOddsD3:{[a]
  r:getBestOdds a;
  P:asc exec distinct selectionId from r;                       // get distinct pivot values
  r:0!exec P#(selectionId!odds) by date:time from r;            // pivot
  r:select date,bottom,spread:(top+bottom)-100 from `date`bottom`top xcol r;
  :update -6_/:@[;4 7 10;:;"-- "]each string date from r;       // do some date formatting
 };

saveBestOddsD3:{[a]
  r:getBestOddsD3 a;
  f:`$":",getenv[`KDBHOME],"/data/",string[a`sym],"/bestodds.csv";
  f 0: "," 0: r;
 };

getLevel2:{[a]
  r:.gw.syncexec[({select time,marketName,selectionId,price,size,side from quote where sym=x};a`sym);`hdb`rdb];
  r:update odds:100*1%price from r;
  :r;
 };

getEvents:{[]
  r:.gw.syncexec[({select distinct sym from trade};`);`hdb`rdb];
  :r;
 };
