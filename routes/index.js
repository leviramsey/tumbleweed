var query = require('../lib/query');
var util=require('../lib/util');

exports.index = function(req, res) {

	if(req.session.user) {
		res.redirect('/feed');
	}
	else {
		res.render('index', {
			registererr: req.flash('register'),
			loginerr: req.flash('login')
		});
	}
}

exports.settings = function(req, res) {
	if(req.session.user) {
		res.render('settings', {
			title: 'Settings',
			user: req.session.user
		});
	} else {
		res.redirect('/');
	}
}

exports.feed = function(req, res) {

	var n = 5;
	var start = 0;
	if(req.query.n)	n = req.query.n;
	if(req.query.start)	start = req.query.start;
		
	Query.Challenge.gets(n,start, function(response, body) {
		if(req.session.user) {
			res.render('feed', {
				title: req.session.user.name + '\'s Tumblefeed',
				user: req.session.user,
				challenges: body.challenges
			});
		}
		else {
			res.redirect('/');
		}
	});
}


exports.profile = function(req, res) {

	if(req.session.user) {
		res.render('profile', {
			title: req.session.user.name + '| Tumbleweed',
			user: req.session.user
		});
	}
	else {
		res.redirect('/');
	}
}


exports.challenge = function(req, res) {

	if(req.session.user) {
		res.render('create', {
			title: 'Create a challenge'
		});
	}
	else {
		res.redirect('/');
	}
}

exports.register = function(req, res) {

	if (!req.body.user || !req.body.pass || !req.body.email || !req.body.long_name || !req.body.day || !req.body.month || !req.body.year) {
    req.flash('register', 'Must fill in all fields');
    res.redirect('/');
    return;
  }

	Query.User.create(req.body.user, req.body.email, req.body.pass, req.body.long_name,
		{ day: req.body.day, month: req.body.month, year: req.body.year },
		function(status, user) {
		
			if(parseInt(status) > 0) {
				req.flash('register', 'Username already exists');
				res.redirect('/');
			}
			else {
				Query.User.info(req.body.user, function(body) {
					req.session.user = body;
					res.redirect('/feed');
				});
			}
		});
};

exports.login = function(req, res) {

	if(!req.body.user || !req.body.pass) {
		req.flash('login', 'Must give username and password');
    res.redirect('/');
    return;
	}

	Query.User.auth(req.body.user, req.body.pass,
		function(response, body) {
		
			if(parseInt(body.status) > 0) {
				req.flash('login', 'Username or password invalid');
				res.redirect('/');
			}
			else {
				Query.User.info(req.body.user, function(body) {
					req.session.user = body;
					res.redirect('/feed');
				});
			}
		});
};

exports.logout = function(req, res) {
	if(!req.session.user) {
		res.redirect('/');
	}
	else {
		req.session.destroy(function() {
			res.redirect('/');
		});
	}
}

exports.create = function(req, res) {
	if(!req.session.user) {
		res.redirect('/');
	}
	else {
		var body=req.body;
		var content={ description: body.description, example: body.upload };
		console.log(body.upload);
		var tags=body.tags.split(/\s+/);
		Query.Challenge.create(req.session.user.name,
				               body.title,
							   body.locale,
							   tags,
							   JSON.parse(body.duration),
							   content,
			function(response, body) {
				if (body) {
					var id=body.id;
					res.redirect('/challenge?id='+id);
				} else {
					// Something fscked up...
					res.redirect('/');
				}
			});
	}
}

exports.view_challenge = function(req, res) {
	if (!(req.query.id)) {
		res.redirect('/feed');
	}

	var id=req.query.id;
	Query.Challenge.get(
			id,
			function (response, body) {
				if (body && body.meta && (0 == body.status)) {
					var poster=body.meta.poster;
					Query.User.info(poster,
						function (row) {
							name=row.name;

							if (typeof body.meta.tags !== 'undefined') {
								body.meta.tags=body.meta.tags.map(function (x) { return [ x, encodeURIComponent(x) ]; });
							}

							res.render('challenge', {
								title: body.meta.title,
								name: name,
								visibility: (body.meta.global ? "Everyone" : "Friends only"),
								description: body.challenge.description,
								post_time: Util.json_date_stringify(body.meta.posted),
								expiration: Util.json_date_stringify(body.meta.expiration),
								tags: body.meta.tags,
								example: '/uploads/' + body.challenge.example
							});}, true);
				} else {
					console.log(body);
					res.redirect('/');
				}
			});
}
