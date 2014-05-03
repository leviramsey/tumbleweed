var months= [ 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November' ];

Util = {};
Util.json_date_stringify = __json_date_stringify;

function __json_date_stringify(json) {
	// No sprintf?  WTF?
	if ((typeof json === undefined) ||
		(typeof json.month === undefined) ||
		(json.month < 1) ||
		(json.month > 12)) {
		return "";
	}

	var ret=months[json.month-1] + " ";
	ret=ret + json.day + ", " + json.year + " ";
	ret=ret + json.hours + ":" + json.minutes;

	return ret;
}

module.exports=Util;
