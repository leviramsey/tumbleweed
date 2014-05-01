var query = require('../lib/query');

exports.index = function(req, res) {

	if(req.session.user) {
		res.redirect('/feed');
	}
	else {
		res.render('index', {
			title: 'Tumbleweed',
			registererr: req.flash('register'),
			loginerr: req.flash('login')
		});
	}
}

exports.settings = function(req, res) {

	if(req.session.user) {
		res.render('settings', {
			title: 'Settings'
		});
	}
	else {
		res.redirect('/');
	}
}

exports.feed = function(req, res) {

	if(req.session.user) {
		res.render('feed', {
			title: req.session.user.name + '\'s Tumblefeed Page',
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
		var content={ description: body.description };
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
	if (!(req.body.id)) {
		res.redirect('/feed');
	}

	var id=req.query.id;
	Query.Challenge.get(
			id,
			function (response, body) {
				if (body) {
					if (0 == body.status) {
						var poster=body.meta.poster;
						var name="";
						Query.User.info(poster,
							function (row) {	name=row.name;	}, true);

						res.render('challenge', {
							// TODO
						});
					}
				} else {
					res.redirect('/');
				}
			});
}
