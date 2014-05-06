var config = require("../config/config");
var host = Config.dbhost;
var http = require("http");
var request = require("request");

Query = {};
Query.User = {};
Query.User.create = __user_create;
Query.User.auth = __user_auth;
Query.User.info = __user_info;
Query.Challenge = {};
Query.Challenge.create = __post_challenge;
Query.Challenge.get = __get_challenge;
Query.Challenge.gets = __get_challenges;

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

function __user_info(user, cb, user_is_uid) {
	var query_obj={
		query_type: "user_info",
	};
	if (user_is_uid) {
		query_obj.uid=user;
	} else {
		query_obj.name=user;
	}

	request.post(host,
		{ form: { query: JSON.stringify(query_obj)
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

function __get_challenge(id, cb) {
	request.post(host,
			{ form: { query: JSON.stringify({
				query_type: 'get_challenge',
				id: id
				})}},
			function (error, response, body) {
				if (error) {
					console.log('error __get_challenge: \'' + error + '\'');
					return;
				}
				body=JSON.parse(body);
				cb(response, body);
			});
}

function __get_challenges(n, start, cb) {
	request.post(host,
			{ form: { query: JSON.stringify({
				query_type: 'get_challenge',
				n: n,
				start: start
				})}},
			function (error, response, body) {
				if (error) {
					console.log('error __get_challenges: \'' + error + '\'');
					return;
				}
				body=JSON.parse(body);
				cb(response, body);
			});
}

module.exports = Query;
