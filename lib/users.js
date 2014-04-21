require("query.js");

function User() {
	this.uid;
	this.name;
	this.email;
	this.long_name;
	this.dob;
}

function createFrom(o) {
	if(o.status != 0) {
		return undefined;
	}
	
	Query.User.info(o.user, function(response) {
	});
	
	var user = User();
	user.name = o.user;
	user.email = o.email;
}