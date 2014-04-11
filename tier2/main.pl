#!/usr/bin/perl

use Mojolicious::Lite;
use Mojo::JSON qw/decode_json encode_json/;
use Digest;

use lib('lib/');

use DB::SQLConnections;
use Math::Random::Secure;

my $verification_enabled=0;

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
		create_user => 'INSERT INTO users (name,email,verified) VALUES (?,?,?)',
		add_validation => 'INSERT INTO user_verifies (uid,code) VALUES (?,?)',
		get_validation => 'SELECT code FROM user_verifies WHERE uid=?',
		del_validation => 'DELETE FROM user_verifies WHERE uid=?',
		validate_user => 'UPDATE users SET verified=1 WHERE uid=?',
		add_password => 'INSERT INTO user_auths (uid,hash,cost) VALUES (?,?,?)',
		name_email_taken => 'SELECT COUNT(uid) FROM users WHERE name=? OR email=?',
		user_validated => 'SELECT COUNT(uid) FROM users WHERE uid=? AND verified=1',
		get_user_info_from_uid => 'SELECT * FROM users WHERE uid=?',
	);

	sub get_connection {
		my @ret=DB::SQLConnections::get_connection(\%sql_queries);
		if (defined $ret[0]) {
			$ret[0]->begin_work;
		}
		return @ret;
	}
}

sub error_hash { (my $href, my $status, my $desc) = @_;
	return unless ((ref $href) eq 'HASH');

	$href->{status}=$status;
	$href->{error_desc}=$desc;
}

sub fetchrow_array_single { (my $sth) = @_;
	return unless ((ref $sth) eq 'DBI::st');

	my @ret=$sth->fetchrow_array;
	$sth->finish;

	return @ret;
}

sub authentication {
	(my $obj) = @_;

	my $ret={ response_to => 'authentication' };

	if (defined $obj->{user}) {
		my $user=$obj->{user};
		my $pass=$obj->{password};	# possibly undef!

		$ret->{user}=$user;

		# verify password in DB...
		(my $conn, my $queries) = get_connection();
		$queries->{'get_uid_from_name'}->execute($user);
		(my $uid) = fetchrow_array_single($queries->{'get_uid_from_name'});
		if (defined $uid) {
			$queries->{'get_pwhash'}->execute($uid);
			(my $hash, my $cost) = fetchrow_array_single($queries->{'get_pwhash'});
			if (defined $hash && defined $pass) {
				(my $pwhash, undef)=crypt_password($pass, $cost);

				if ($pwhash eq $hash) {
					# Authenticated
					$ret->{status}=0;
					$queries->{'user_validated'}->execute($uid);
					(my $cnt) = fetchrow_array_single($queries->{'user_validated'});
					$ret->{validated}=$cnt;
				} else {
					# Password did not match
					error_hash($ret, 1, 'Password did not match');
				}
			} else {
				error_hash($ret, 2, 'User does not have password.  3rd party authentication');
			}
		} else {
			error_hash($ret, 3, 'User not found');
		}
		DB::SQLConnections::done_with_conn($conn, 'commit');
	} else {
		error_hash($ret, 4, 'Username required');
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

sub create_user {
	(my $obj) = @_;

	my $ret={ response_to => 'create_user' };

	if ((defined $obj->{user}) &&
		(defined $obj->{email}) &&
		(defined $obj->{auth})) {
		my $user=$obj->{user};
		my $email=$obj->{email};
		my $auth=$obj->{auth};

		$ret->{user}=$user;
		# Verify that name and email aren't taken
		(my $conn, my $queries) = get_connection();
		$queries->{'name_email_taken'}->execute($user, $email);
		eval {
			(my $cnt)=fetchrow_array_single($queries->{'name_email_taken'});
			if ($cnt) {
				error_hash($ret, 1, 'Username or email taken');
				die;
			}
			if (ref $auth) {
				# TODO: 3rd party authentication
				error_hash($ret, 2, '3rd party authentication not yet implemented');
				die;
			}

			for ($queries->{'create_user'}) {
				$_->execute($user, $email, 1-$verification_enabled);
				$_->finish;
			}
			$queries->{'get_uid_from_name'}->execute($user);
			(my $uid)=fetchrow_array_single($queries->{'get_uid_from_name'});
			unless (defined $uid) {
				error_hash($ret, 3, 'Could not create user');
				die;
			}

			(my $pwhash, my $pwcost)=crypt_password($auth);
			$queries->{'add_password'}->execute($uid, $pwhash, $pwcost);
			$queries->{'add_password'}->finish();
			say STDERR "password created";
			if ($verification_enabled) {
				create_verification_code($ret, $uid, $queries);
			}
		};
		DB::SQLConnections::done_with_conn($conn, 'commit');
	} else {
		error_hash($ret, 5, 'Username, email, and authentication information required');
	}

	unless ($ret->{status}) {
		# No error => success!
		$ret->{status}=0;
	}
	return encode_json($ret);
}

sub validate_user { (my $obj) = @_;
	my $ret={ response_to => 'validate_user', };

	if ((defined $obj->{user}) &&
		(defined $obj->{code})) {
		my $user=$obj->{user};
		my $code=lc $obj->{code};

		# Get UID
		(my $conn, my $queries) = get_connection();
		$queries->{'get_uid_from_name'}->execute($user);
		eval {
			(my $uid) = fetchrow_array_single($queries->{'get_uid_from_name'});
			unless (defined $uid) {
				error_hash($ret, 1, 'User not found');
				die;
			}

			$queries->{'get_validation'}->execute($uid);
			(my $dbc) = fetchrow_array_single($queries->{'get_validation'});
			unless (defined $dbc) {
				$queries->{'user_validated'}->execute($uid);
				(my $cnt) = fetchrow_array_single($queries->{'user_validated'});
				if ($cnt) {
					error_hash($ret, 2, 'User already validated');
				} else {
					# Somehow we lost the validation
					$ret->{new_validation}={ };
					create_verification_code($ret->{new_validation}, $uid, $queries);
					error_hash($ret, 3, 'New validation created');
				}
				die;
			}

			unless ($dbc eq $code) {
				error_hash($ret, 4, 'Incorrect code');
				die;
			}

			$queries->{'del_validation'}->execute($uid);
			$queries->{'validate_user'}->execute($uid);

			$ret->{status}=0;
		};
		DB::SQLConnections::done_with_conn($conn, 'commit');
	} else {
		error_hash($ret, undef, 'User and code required');
		$ret->{status}=undef;
		$ret->{error_desc}='User and code required';
	}
	return encode_json($ret);
}

my %query_types = (
	authentication => \&authentication,
	create_user => \&create_user,
	validate_user => \&validate_user,
);

post '/query' => sub {
	(my $self) = @_;
	my %params=%{$self->req->params->to_hash};
	if (defined $params{query}) {
		my $json=decode_json($params{query});
		my $resp;
		if (defined $query_types{$json->{query_type}}) {
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
