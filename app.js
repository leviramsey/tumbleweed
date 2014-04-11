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
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.favicon());
app.use(express.logger('dev'));
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
});
