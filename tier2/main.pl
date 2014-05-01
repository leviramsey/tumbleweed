#!/usr/bin/perl

use Mojolicious::Lite;
use Mojo::JSON qw/decode_json encode_json/;
use Digest;

use lib('lib/');
use experimental 'smartmatch';

use DBIx::Connector;
use DB::Password;
use Math::Random::Secure;

use Mojo::Log;

use MongoDB;

my $connector=DBIx::Connector->new(
	'dbi:mysql:tumbleweed',
	'levi',
	$DB::Password::mine,
);

app->attr(mongo => sub { (my $self) = @_;
		my $client=MongoDB::MongoClient->new();
		my $database=$client->get_database('tumbleweed');
		return { client => $client, database => $database };
	});

app->config(hypnotoad => { listen => [ 'http://*:3001' ] });

{
	my @levels=qw/info/;
	my %logs=map { $_ => Mojo::Log->new(path => "/var/log/mojo/$_.log", level => "$_"); } @levels;

	my %loggers;
	my %foo=%Mojo::Log::;
	for (@levels) {
		$loggers{$_}=$foo{$_};
	}

	sub log_it { my $level=shift @_;
		for (values %logs) {
			if (defined $loggers{$level}) {
				$loggers{$level}->($logs{$level}, @_);
			}
		}
	}
}

sub crypt_password {
	(my $pass, my $cost) = @_;
	$cost //= 10;
	return undef unless ($cost < 32);
	my $crypter=Digest->new('Bcrypt');
	$crypter->cost($cost);
	$crypter->salt('abcdefghijklmnop');
	$crypter->add($pass);
	return ($crypter->bcrypt_b64digest, $cost);
}

{
	my %sql_queries=(
		get_uid_from_name => 'SELECT uid FROM users WHERE name=?',
		get_pwhash => 'SELECT hash,cost FROM user_auths WHERE uid=?',
		create_user => 'INSERT INTO users (name,email,verified,long_name,dob) VALUES (?,?,1,?,?)',
		add_validation => 'INSERT INTO user_verifies (uid,code) VALUES (?,?)',
		get_validation => 'SELECT code FROM user_verifies WHERE uid=?',
		del_validation => 'DELETE FROM user_verifies WHERE uid=?',
		validate_user => 'UPDATE users SET verified=1 WHERE uid=?',
		add_password => 'INSERT INTO user_auths (uid,hash,cost) VALUES (?,?,?)',
		name_email_taken => 'SELECT COUNT(uid) FROM users WHERE name=? OR email=?',
		user_validated => 'SELECT COUNT(uid) FROM users WHERE uid=? AND verified=1',
		get_user_info_from_uid => 'SELECT * FROM users WHERE uid=?',
		get_all_extdata => 'SELECT k,v,priority,display FROM user_extdata WHERE uid=?',
		get_top_disp_extdata => 'SELECT k,v FROM user_extdata WHERE display=1 AND uid=? ORDER BY priority DESC LIMIT ?',
		add_extdata => 'INSERT INTO user_extdata (uid,k,v,priority,display) VALUES (?,?,?,?,?)',
		get_extdata_by_key => 'SELECT * FROM user_extdata WHERE uid=? AND k=?',
		delete_extdata_by_key => 'DELETE FROM user_extdata WHERE uid=? AND k=?',
		add_content => 'INSERT INTO content (poster,kind,posted,title) VALUES (?,?,NOW(),?)',
		get_content_info_by_id => 'SELECT * FROM content WHERE id=?',
		tag_content => 'INSERT INTO taggings (tag, target) VALUES (?,?)',
		get_tags => 'SELECT tag FROM taggings WHERE target=?',
		add_challenge => 'INSERT INTO challenges (id, expiration, global) VALUES (?,?,?)',
		cnt_challenge_expiring => 'SELECT COUNT(*) FROM challenges WHERE id=? AND expiration=? AND global=?',
		cnt_challenge_noexpire => 'SELECT COUNT(*) FROM challenges WHERE id=? AND expiration IS NULL AND global=?',
		get_challenges => 'SELECT content.id AS id,poster,posted,title,expiration,global FROM content LEFT JOIN challenges ON content.id=challenges.id WHERE kind=0 ORDER BY posted DESC LIMIT ?,?',
		get_challenge_by_id => 'SELECT poster,posted,title,expiration,global FROM content LEFT JOIN challenges ON content.id=challenges.id WHERE kind=0 AND content.id=?'
	);

	my %queries;
	my $last_dbh;

	sub query_get { (my $name, my $conn) = @_;
		my $query=$queries{$name};
		unless ((defined $query) && ($query->{Database} == $conn)) {
			$queries{$name}=$query=$conn->prepare($sql_queries{$name});
		}
		return $query;
	}

	sub get_connection {
		return undef;
	}
}
my %res=(
	digitx4 => qr/^\d{4}$/,
	digitx2 => qr/^\d{2}$/,
	digitx1_plus => qr/^\d+$/,
);

sub error_hash { (my $href, my $status, my $desc) = @_;
	return unless ((ref $href) eq 'HASH');

	$href->{status}=$status;
	$href->{error_desc}=$desc;
}

sub die_error_hash {
	error_hash(@_);
	die [ $_[1], $_[0] ];
}

sub fetchrow_array_single { (my $sth) = @_;
	return unless ((ref $sth) eq 'DBI::st');

	my @ret=$sth->fetchrow_array;
	$sth->finish;

	return @ret;
}

sub authentication { (my $obj) = @_;
	my $ret={ response_to => 'authentication' };

	if (defined $obj->{user}) {
		my $user=$obj->{user};
		my $pass=$obj->{pass};

		$ret->{user}=$user;

		$connector->txn(fixup => sub {
				my $dbh=$_;
				my $queries=sub { query_get($_[0], $dbh); };
				$queries->('get_uid_from_name')->execute($user);
				(my $uid)=fetchrow_array_single($queries->('get_uid_from_name'));
				if (defined $uid) {
					$queries->('get_pwhash')->execute($uid);
					(my $hash, my $cost) = fetchrow_array_single($queries->('get_pwhash'));
					if ((defined $hash) && (defined $pass)) {
						(my $pwhash, undef) = crypt_password($pass, $cost);

						if ($pwhash eq $hash) {
							# Authenticated
							$ret->{status}=0;
							$queries->('user_validated')->execute($uid);
							(my $cnt)=fetchrow_array_single($queries->('user_validated'));
							$ret->{validated}=$cnt;
						} else {
							# Password did not match
							error_hash($ret, 1, 'Password did not match');
						}
					} elsif (defined $hash) {
						# Password not specified but needed
						error_hash($ret, 2, 'User must authenticate with password');
					} else {
						# 3rd party authentication, password not needed
						error_hash($ret, 3, '3rd party authentication (not yet implemented)');
					}
				} else {
					error_hash($ret, 4, 'User not found');
				}});
	} else {
		error_hash($ret, 5, 'Username required');
	}

	return encode_json($ret);
}

# must have a pre-set-up hash to return
# reserves error-code 4
sub create_verification_code { (my $ret, my $uid, my $queries) = @_;
	return unless (((ref $ret) eq 'HASH') &&
	               ((ref $queries) eq 'HASH'));
	
	my $code=sprintf("%8x", Math::Random::Secure::irand());
	$queries->{'add_validation'}->execute($uid, $code);
	$queries->{'get_validation'}->execute($uid);
	(my $foo) = fetchrow_array_single($queries->{'get_validation'});

	unless ($foo eq $code) {
		error_hash($ret, 4, 'Could not create validation');
		my $conn=$queries->{'get_validation'}->{Database};
		$conn->rollback;
		$conn->begin_work;
		die;
	}

	$ret->{status}=0;
	$ret->{validation_code}=$code;
}

sub create_user { (my $obj) = @_;
	my $ret={ response_to => 'create_user' };

	my @interested=@{$obj}{qw/user email auth long_name dob/};
	if (scalar(@interested) == scalar grep { (defined $_) && ($_); } @interested) {
		(my $user, my $email, my $auth, my $long_name, my $dob) = @interested;
		
		$ret->{user}=$user;
		# Verify that name and email aren't taken
		$connector->txn(fixup => sub {
				my $dbh=$_;
				my $queries=sub { query_get($_[0], $dbh); };
				$queries->('name_email_taken')->execute($user, $email);
				eval {
					(my $cnt) = fetchrow_array_single($queries->('name_email_taken'));
					if ($cnt) {
						die_error_hash($ret, 1, 'Username or email taken');
					}

					if (ref $auth) {
						# TODO: 3rd party authentication
						die_error_hash($ret, 2, '3rd party authentication not yet implemented');
					}

					my $dobstr;
					say STDERR $dob;
					unless (((ref $dob) eq 'HASH') &&
					        (3 == scalar grep { exists $dob->{$_}; } qw/year month day/)) {
						die_error_hash($ret, 3, 'DOB must be specified as an object with members year, month, day');
					}
					say STDERR $dob->{month};
					$dobstr=sprintf("%04d-%02d-%02d", @{$dob}{qw/year month day/});
					say STDERR $dobstr;
					
					$queries->('create_user')->execute($user, $email, $long_name, $dobstr);
					$queries->('get_uid_from_name')->execute($user);
					(my $uid)=fetchrow_array_single($queries->('get_uid_from_name'));
					unless (defined $uid) {
						die_error_hash($ret, 5, 'Could not create user');
					}

					(my $pwhash, my $pwcost)=crypt_password($auth);
					log_it("info", "$uid $pwhash");
					$queries->('add_password')->execute($uid, $pwhash, $pwcost);
				};
				if ($@) {
					log_it("info", "exception!");
					log_it("info", $@);
				}
			});
	} else {
		error_hash($ret, 6, 'Username, email, long name, date of birth, and authentication information required');
	}

	unless ($ret->{status}) {
		# No error => success!
		$ret->{status}=0;
	}
	return encode_json($ret);
}

# Reserves error codes 1 and 2
sub user_id_or_name { (my $uid, my $name) = @_;
	if (((defined $uid) && $uid) || ((defined $name) && $name)) {
		unless (defined $uid) {
			$connector->txn(fixup => sub {
					my $dbh=$_;
					my $queries=sub { query_get($_[0], $dbh); };
					$queries->('get_uid_from_name')->execute($name);
					($uid) = fetchrow_array_single($queries->('get_uid_from_name'));
				});
		}
		
		if ((defined $uid) && ($uid =~ /$res{digitx1_plus}/)) {
			return ($uid, undef, undef);
		}
		return (undef, 2, 'No user by that name');
	} else {
		return (undef, 1, 'Must provide user ID or name');
	}
}

sub user_info { (my $obj) = @_;
	my $ret={ response_to => 'user_info' };

	(my $uid, my $status, my $error_text) = user_id_or_name($obj->{uid}, $obj->{name});
	unless (defined $uid) {
		error_hash($ret, $status, $error_text);
	} else {
		$connector->txn(fixup => sub {
				my $dbh=$_;
				my $queries=sub { query_get($_[0], $dbh); };
				$queries->('get_user_info_from_uid')->execute($uid);
				$ret->{row}=$queries->('get_user_info_from_uid')->fetchrow_hashref();
			});
	}

	unless ($ret->{status}) {
		# No error => success!
		$ret->{status}=0;
	}

	return encode_json($ret);
}

sub user_extended_data { (my $obj) = @_;
	my $ret={ response_to => 'user_extinfo' };

	(my $uid, my $status, my $error_text) = user_id_or_name($obj->{uid}, $obj->{name});

	unless (defined $uid) {
		error_hash($ret, $status, $error_text);
	} else {
		my @binds=($uid);
		my $query_name='get_all_extdata';
		if ((defined $obj->{n}) && ($obj->{n} =~ /$res{digitx1_plus}/)) {
			push @binds, $obj->{n};
			$query_name='get_top_disp_extdata';
		}
		log_it("info", "$query_name" . join(" ", @binds));

		$connector->txn(fixup => sub {
				my $dbh=$_;
				my $queries=sub { query_get($_[0], $dbh); };
				$queries->($query_name)->execute(@binds);
				$ret->{results}=$queries->($query_name)->fetchall_arrayref;
			});
		if ($@) {
			log_it("info", $@);
		}
	}

	unless ($ret->{status}) {
		$ret->{status}=0;
	}

	return encode_json($ret);
}

sub add_extended_data { (my $obj) = @_;
	my $ret={ response_to => 'add_extended_data' };

	(my $uid, my $status, my $error_text) = user_id_or_name($obj->{uid}, $obj->{name});

	unless (defined $uid) {
		error_hash($ret, $status, $error_text);
	} else {
		unless (4 == scalar grep { $_; } map { defined $obj->{$_}; } qw/key value priority display/) {
			error_hash($ret, 3, "Must specify key, value, priority, display");
		} else {
			eval {
				unless ($obj->{priority} =~ /$res{digitx1_plus}/) {
					die_error_hash($ret, 4, "Priority must be a nonnegative number");
					die;
				}
				my $display=($obj->{display}) ? 1 : 0;
				
				my @binds=($uid, @{$obj}{qw/key value priority/}, $display);
				$binds[1]=lc $binds[1];
				$connector->txn(fixup => sub {
						my $dbh=$_;
						my $queries=sub { query_get($_[0], $dbh); };

						log_it("info", join(" ", @binds[0,1]));
						# Do we already have an entry?
						$queries->('get_extdata_by_key')->execute(@binds[0,1]);
						my @foo=fetchrow_array_single($queries->('get_extdata_by_key'));
						if (scalar @foo) {
							$queries->('delete_extdata_by_key')->execute(@binds[0,1]);
							log_it("info", "deleted extdata key");
						}
						
						$queries->('add_extdata')->execute(@binds);

						$queries->('get_extdata_by_key')->execute(@binds[0,1]);
						@foo=fetchrow_array_single($queries->('get_extdata_by_key'));
						log_it("info", join(" ", @foo));
						unless (scalar @foo) {
							die_error_hash($ret, 5, "Failed to add extended data");
						}
					});
				if ($@) {
					log_it("info", "exception!");
					if ('ARRAY' eq ref $@) {
						# rethrow
						die $@;
					}
					log_it("info", $@);
				}
			}
		}
	}

	unless ($ret->{status}) {
		$ret->{status}=0;
	}

	return encode_json($ret);
}

sub add_content { (my $obj, my $c) = @_;
	my $ret={ response_to => 'add_content' };

	(my $uid, my $status, my $error_text) = user_id_or_name($obj->{uid}, $obj->{name});
	
	unless (defined $uid) {
		error_hash($ret, $status, $error_text);
	} else {
		eval {
			unless ((defined $obj->{type}) &&
			        (defined $obj->{title}) && 
					($obj->{title} !~ /^\s*$/)) {
				die_error_hash($ret, 3, "Must specify a type and title");
			}
			my $type;
			$obj->{type}=lc $obj->{type};
			given ($obj->{type}) {
				when ("challenge") {
					$type=0;
				}
				when ("response") {
					$type=1;
				}
				when ("comment") {
					$type=2;
				}
				default {
					die_error_hash($ret, 4, "Invalid type specified");
				}
			}
			$connector->txn(fixup => sub {
					my $dbh=$_;
					my $queries=sub { query_get($_[0], $dbh); };
					$queries->("add_content")->execute($uid, $type, $obj->{title});
					my $content_id=$dbh->{mysql_insertid};
					unless ((defined $content_id) &&
						(do {
								$queries->('get_content_info_by_id')->execute($content_id);
								my @row=fetchrow_array_single($queries->('get_content_info_by_id'));
								($row[1] == $uid) && ($row[2] == $type) && ($row[4] eq $obj->{title});
						})) {
						die_error_hash($ret, 5, "Failed to save content metadata");
					}

					if ((defined $obj->{tags}) && ('ARRAY' eq ref $obj->{tags})) {
						for (@{$obj->{tags}}) {
							$queries->('tag_content')->execute(lc $_, $content_id);
						}
					}

					if (0 == $type) {
						unless ((defined $obj->{expiration}) &&
						        (('HASH' eq ref $obj->{expiration}) ||
								 ('none' eq lc $obj->{expiration}))) {
							die_error_hash($ret, 6, "Expiration required");
						}
						my $expiration;
						if ('HASH' eq ref $obj->{expiration}) {
							unless (5 == scalar grep { exists $obj->{expiration}->{$_}; } qw/year month day hours minutes/) {
								die_error_hash($ret, 7, "expiration: Invalid date format");
							}
							$expiration=sprintf("%04d-%02d-%02d %02d:%02d:00", @{$obj->{expiration}}{qw/year month day hours minutes/});
							log_it("info", $expiration);
						} else {
							$expiration=undef;
						}

						unless (defined $obj->{global}) {
							die_error_hash($ret, 7, "Challenges must specify global[ity]");
						}
						my $global=($obj->{global}) ? 1 : 0;

						$queries->('add_challenge')->execute($content_id, $expiration, $global);
						my $cnt;
						if (defined $expiration) {
							$queries->('cnt_challenge_expiring')->execute($content_id, $expiration, $global);
							($cnt)=fetchrow_array_single($queries->('cnt_challenge_expiring'));
						} else {
							$queries->('cnt_challenge_noexpire')->execute($content_id, $global);
							($cnt)=fetchrow_array_single($queries->('cnt_challenge_noexpire'));
						}
						unless (1 == $cnt) {
							die_error_hash($ret, 8, "Failed to create challenge");
						}
					}

					if ((defined $obj->{content}) && ('HASH' eq ref $obj->{content})) {
						my $mongo=$c->app->mongo;
						my $mongocoll=$mongo->{database}->get_collection($obj->{type});
						$obj->{content}->{_id}=$content_id;
						$mongocoll->insert($obj->{content});
					} else {
						die_error_hash($ret, 9, "Must specify content as an object");
					}
					$ret->{id}=$content_id;
				});
			if ($@) {
				if ('ARRAY' eq ref $@) {
					die $@;
				}
				log_it("info", "Exception");
				log_it("info", $@);
			}
		};
		if ($@) {
			unless ('ARRAY' eq ref $@) {
				log_it("info", "Exception");
				log_it("info", $@);
			}
		}
	}

	unless ($ret->{status}) {
		$ret->{status}=0;
	}

	return encode_json($ret);
}

sub get_challenge { (my $obj, my $c) = @_;
	my $ret={ response_to => 'get_challenge' };

	if ((defined $obj->{id}) && ($obj->{id} =~ /$res{digitx1_plus}/)) {
		my $id=$obj->{id};
		$connector->txn(fixup => sub {
				my $dbh=$_;
				my $queries=sub { query_get($_[0], $dbh); };
				$queries->("get_challenge_by_id")->execute($id);
				$ret->{meta}=$queries->('get_challenge_by_id')->fetchrow_hashref();
				if (defined $ret->{meta}) {
					$ret->{meta}->{id}=$id;

					$queries->('get_tags')->execute($id);
					my @tags;
					while (defined (my $tag=$queries->('get_tags')->fetchrow_arrayref())) {
						push @tags, $tag->[0];
					}
					if (scalar @tags) {
						$ret->{meta}->{tags}=\@tags;
					}

					my $mongo=$c->app->mongo;
					my $mongocoll=$mongo->{database}->get_collection('challenge');
					my $cursor=$mongocoll->find({ _id => $id });
					($ret->{challenge})=($cursor->all);
				}
			});
	} elsif ((defined $obj->{n}) && ($obj->{n} =~ /$res{digitx1_plus}/)) {
		my $n=$obj->{n};
		my $start=0;
		if ((defined $obj->{start}) && ($obj->{n} =~ /$res{digitx1_plus}/)) {
			$start=$obj->{start};
		}
		$connector->txn(fixup => sub {
				my $dbh=$_;
				my $queries=sub { query_get($_[0], $dbh); };
				$queries->("get_challenges")->execute($start, $n);
				my @challenges;
				while (defined(my $row=$queries->('get_challenges')->fetchrow_hashref())) {
					push @challenges, $row;
				}
				$ret->{challenges}=\@challenges;
			});
	} else {
		log_it("info", "fooey!");
		error_hash($ret, 1, "Must specify either a challenge ID or a number of challenges to retrieve (and optionally a starting position)");
	}

	unless ($ret->{status}) {
		$ret->{status}=0;
	}

	return encode_json($ret);
}

my %query_types = (
	authentication => \&authentication,
	create_user => \&create_user,
	user_info => \&user_info,
	add_extinfo => \&add_extended_data,
	user_extinfo => \&user_extended_data,
	add_content => \&add_content,
	get_challenge => \&get_challenge,
);

post '/query' => sub {
	(my $self) = @_;
	my %params=%{$self->req->params->to_hash};
	say keys %params;
	if (defined $params{query}) {
		my $json=decode_json($params{query});
		my $resp;
		log_it("info", sprintf("%s %s", $self->tx->remote_address, $json->{query_type}));
		if (defined $query_types{$json->{query_type}}) {
			log_it("info", $params{query});
			$resp=$query_types{$json->{query_type}}->($json, $self);
		} else {
			log_it("info", $json->{query_type});
			$resp="";
		}
		return $self->render(data => $resp);
	} elsif (defined $params{debug}) {
		return $self->render(data => encode_json({ tumbleweed => "IS ALIVE!" }) );
	}
	$self->render(text => "");
};

app->start;
