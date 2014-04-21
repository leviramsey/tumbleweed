<<<<<<< HEAD
var express = require('express');
var http = require('http');
var path = require('path');

// TDR ADDED:
// using connect-flash to provide flash support
// across redirects:
var flash = require('connect-flash');
/////

var app = express();

// all environments
app.set('port', process.env.PORT || 8081);
=======
/*                                                              *\
**   _                   _     _                            _   **
**  | |_ _   _ _ __ ___ | |__ | | _____      _____  ___  __| |  **
**  | __| | | | '_ ` _ \| '_ \| |/ _ \ \ /\ / / _ \/ _ \/ _` |  **
**  | |_| |_| | | | | | | |_) | |  __/\ V  V /  __/  __/ (_| |  **
**   \__|\__,_|_| |_| |_|_.__/|_|\___| \_/\_/ \___|\___|\__,_|  **
**                                                              **
**    | @ SERVING CREATIVE CHALLENGES FOR ALL                   **
**    | @ https://github.com/spacenut/tumbleweed                **
**    | @ 2014                                                  **
\*                                                              */


// Required libraries, routes

var express = require('express');
var routes = require('./routes');
var http = require('http');
var path = require('path');

// Flash used for simple error
// messages between redirects

var flash = require('connect-flash');


// Create and initialize the express `app`
// object which wraps the application

var app = express();

// Configure the app:
//	{
//		'port': '8080',
//		'view':
//		{
//			'path': './views',
//			'engine': 'ejs'
//		}
//	}

app.set('port', process.env.PORT || 8080);
>>>>>>> 509bee3f6f22ab43a7a6dd6f8dfe2fd9fa7ff766
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.favicon());
app.use(express.logger('dev'));
<<<<<<< HEAD
// TDR: express.json() and express.urlencoded() are the same
//      as express.bodyParser() in previous versions of the
//      connect middleware library.
app.use(express.json());
app.use(express.urlencoded());
/////
app.use(express.methodOverride());
app.use(express.cookieParser('your secret here'));
app.use(express.session());
// TDR ADDED:
// This is where we add the middleware to the express environment
// for flash support for redirects:
app.use(flash());
/////
app.use(app.router);
app.use(express.static(path.join(__dirname, 'public')));

// Route Definitions:
var routes = require('./routes');
app.get('/', routes.index);
app.get('/feed', routes.feed);
app.get('/logout', routes.logout);
app.post('/register', routes.register);
app.post('/login', routes.login);

http.createServer(app).listen(app.get('port'), function(){
  console.log('Express server listening on port ' + app.get('port'));
=======
app.use(express.json());
app.use(express.urlencoded());
app.use(express.methodOverride());
app.use(express.cookieParser('e6a10aec00a62a97e27874a7b51328b8'));
app.use(express.session());
app.use(flash());
app.use(app.router);
app.use(express.static(path.join(__dirname, 'public')));

// Configure the routes:
//	{
//		'/': 'routes.login',
//		'/authorize': 'routes.authorize',
//		'/register': 'routes.register',
//		'/posts': 'routes.posts',
//		'/logout': 'routes.logout',
//		'/'
//	}

app.get('/', routes.login);
app.post('/authorize', routes.authorize);
app.post('/register', routes.register);
app.get('/posts', routes.posts);
app.post('/post', routes.post);
app.get('/logout', routes.logout);

// Start the tumbleweed server on the appropriate app port
// when the message is displayed to the terminal,
// the application is active

http.createServer(app).listen(app.get('port'), function() {
  console.log('tumbleweed server listening on port ' + app.get('port'));
>>>>>>> 509bee3f6f22ab43a7a6dd6f8dfe2fd9fa7ff766
});
