#!/usr/bin/perl

use Mojolicious::Lite;
use Mojo::JSON qw/decode_json encode_json/;
use Digest;

use lib('lib/');

use DBIx::Connector;
use DB::Password;
use Math::Random::Secure;

use Mojo::Log;

my $connector=DBIx::Connector->new(
	'dbi:mysql:tumbleweed',
	'levi',
	$DB::Password::mine,
);

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
	if (scalar(@interested) == scalar grep { defined $_ } @interested) {
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
					log_it("info", "fooey");

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
	if ((defined $uid) || (defined $name)) {
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
						unless (scalar @foo) {
							die_error_hash($ret, 5, "Failed to add extended data");
						}
					});
				if ($@) {
					if ('ARRAY' eq ref $@) {
						# rethrow
						die $@;
					}
					say STDERR $@;
				}
			}
		}
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
);

post '/query' => sub {
	(my $self) = @_;
	my %params=%{$self->req->params->to_hash};
	if (defined $params{query}) {
		my $json=decode_json($params{query});
		my $resp;
		if (defined $query_types{$json->{query_type}}) {
			log_it("info", sprintf("%s %s", $self->tx->remote_address, $json->{query_type}));
			log_it("info", $params{query});
			$resp=$query_types{$json->{query_type}}->($json);
		} else {
			$resp="";
		}
		return $self->render(data => $resp);
	} elsif (defined $params{debug}) {
		return $self->render(data => encode_json({ tumbleweed => "IS ALIVE!" }) );
	}
	$self->render(text => "");
};

app->start;
