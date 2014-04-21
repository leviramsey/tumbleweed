var express = require('express');
var http = require('http');
var path = require('path');
// TDR ADDED:
// using connect-flash to provide flash support
// across redirects:
var flash = require('connect-flash');

var app = express();

// all environments
app.set('port', process.env.PORT || 8081);
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.favicon());
app.use(express.logger('dev'));
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
app.get('/challenge', routes.challenge);
app.post('/register', routes.register);
app.post('/login', routes.login);

http.createServer(app).listen(app.get('port'), function(){
  console.log('Express server listening on port ' + app.get('port'));
});