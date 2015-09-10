/ - return metadata for markets captured today
getActiveMarkets:{[d] `date xcols update date: d from delete time from 0!select by sym, selectionId from metadata}

/ - Calculates odds based on matched trades by selection and time window.  Odds returned as implied probability
getOdds:{[mktid;bucket]
	chances: 0!select chance: 100*1% size wavg price, size: sum size by sym, selectionId, bucket xbar time from trade where sym = mktid;
	/ join on metadata
	joinOnMetaData[chances;mktid]};
	
/ - get the mid price for each selection
getMid:{[mktid]
	mid: delete back, lay from
		update chance: 100*1% mid, spread: lay - back from 
			select time, sym, selectionId, back:backs[;0], lay: lays[;0], mid: avg each flip (backs[;0];lays[;0]) from quote where sym in mktid;
	/ join on metadata
	joinOnMetaData[mid;mktid]}
	
/ - join on meta data
joinOnMetaData:{[data;mktid]
	data lj 2!select sym, selectionId, eventTypeName, competitionName, marketName, eventName, selectionName 
			from select by sym,selectionId from metadata where sym in mktid}

/ - calculate vwap buckets
/ - v is vwap buckets i.e. 100 200 500
/ - q is list of qty/size (in price order)
/ - p is a list of prices (may be asc or desc depending on whether it is back or lays)
vwap:{[v;q;p] (deltas each (v,()) &\: sums q) wavg\: p}
getVwap:{[mktid;pbkt]
	data: ungroup select sym, selectionId, time, size:count[i]#enlist pbkt, back:vwap[pbkt;;]'[bsizes;backs], lay:vwap[pbkt;;]'[lsizes;lays] 
		from quote where sym in mktid;
	/ - join on metadata
	joinOnMetaData[data;mktid]}
