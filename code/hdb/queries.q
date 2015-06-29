/ - return metadata for markets captured today
getActiveMarkets:{[d] datesymfilt: ungroup select date, sym: marketids from activeDates where date in d;
			delete time from 0!select by date, sym, selectionId from metadata where ([] date;sym) in datesymfilt}

/ - Calculates odds based on matched trades by selection and time window.  Odds returned as implied probability
getChances:{[mktid;bucket]
	lookup: (select date from activeDates where any each marketids in\: mktid) cross ([] sym:(),mktid);
	chances: 0!select chance: 100*1% size wavg price, size: sum size by sym, selectionId, bucket xbar time from trade where ([] date;sym) in lookup;
	/ join on metadata
	chances lj 2!select sym, selectionId, eventTypeName, competitionName, marketName, eventName, selectionName from select by sym,selectionId from metadata where ([] date;sym) in lookup}

/ - get the mid price for each selection
getMid:{[mktid]
	lookup: (select date from activeDates where any each marketids in\: mktid) cross ([] sym:(),mktid);
	mid: delete back, lay from
		update chance: 100*1% mid,  spread: lay - back from 
		select time, sym, selectionId, back:backs[;0], lay: lays[;0], mid: avg each flip (backs[;0];lays[;0]) from quote where ([] date;sym) in lookup;
	/ join on metadata
	mid lj 2!select sym, selectionId, eventTypeName, competitionName, marketName, eventName, selectionName from select by sym,selectionId from metadata where ([] date;sym) in lookup}