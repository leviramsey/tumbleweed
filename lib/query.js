var host = 'http://lrr.cygnetnet.net:3001/query';
var http = require("http");
var request = require("request");

Query = {};
Query.User = {};
Query.User.create = __user_create;
Query.User.auth = __user_auth;
Query.User.info = __user_info;
Query.Challenge = {};
Query.Challenge.create = __post_challenge;

function __user_create(user, email, password, long_name, dob, cb) {
	request.post(host,
		{ form: { query: JSON.stringify({
			query_type: "create_user",
			user: user,
			email: email,
			auth: password,
			long_name: long_name,
			dob: dob
		})
	}},
	function(error, response, body) {
		if(error) {
			console.log('error __user_create: \'' + error + '\'');
			return;
		}
		body = JSON.parse(body);
		cb(response, body.status, user);
	});
}

function __user_auth(user, pass, cb) {
	request.post(host,
		{ form: { query: JSON.stringify({
			query_type: "authentication",
			user: user,
			pass: pass
		})
	}},
	function(error, response, body) {
		if(error) {
			console.log('error __user_info: \'' + error + '\'');
			return;
		}
		body = JSON.parse(body);
		cb(response, body);
	});
}

function __user_info(user, cb) {
	request.post(host,
		{ form: { query: JSON.stringify({
			query_type: "user_info",
			name: user
		})
	}},
	function(error, response, body) {
		if(error) {
			console.log('error __user_info: \'' + error + '\'');
			return;
		}
		body = JSON.parse(body);		
		cb(body.row);
	});
}

function __post_challenge(user, title, visibility, tags, expiration, content, cb) {
	request.post(host,
			{ form: { query: JSON.stringify({
				query_type: "add_content",
				name: user,
				type: "challenge",
				title: title,
				global: (0 == visibility),		// ugly...
				tags: tags,
				expiration: expiration,
				content: content
				})}},
			function (error, response, body) {
				if (error) {
					console.log('error __post_challenge: \'' + error + '\'');
					return;
				}
				body=JSON.parse(body);
				cb(response, body);
			});
}

module.exports = Query;
