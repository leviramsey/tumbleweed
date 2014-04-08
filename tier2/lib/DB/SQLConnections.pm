#!/usr/bin/perl
#
# Lightweight connection pool

package DB::SQLConnections;

use DBI;
use feature ':5.12';

# A list of [ $DBI_connection_handle, $working, %queries ]s
my @connpool;

my $make_connection=sub {
	(my $querystrings) = @_;
	my $conn=DBI->connect(
		'dbi:mysql:tumbleweed',
		'levi',
		'ph1l1ke',
		{ AutoCommit => 1, }
	);

	die unless $conn;

	my $queries={};
	if ((defined $querystrings) && (ref $querystrings eq 'HASH')) {
		while ((my $key, my $val) = each %{$querystrings}) {
			my $query=$conn->prepare($val);
			if ($query) {
				$queries->{$key}=$query;
			}
		}
	}
	push @connpool, [ $conn, 1, $queries ];
	say STDERR 'Making new connection';
	return ($conn, $queries);
};

sub get_connection {
	(my $queries) = @_;
	say STDERR scalar @connpool;
	while ((my $index, my $lst) = each @connpool) {
		unless ($lst->[1]) {
			$lst->[1]=1;
			if ($lst->[0]->ping()) {
				say STDERR 'Using pre-existing connection';
				return ($lst->[0], $lst->[2]);
			} else {
				say STDERR 'Connection died';
				$lst->[0]->disconnect();
				splice(@connpool, $index, 1);
				next;
			}
		}
	}
	# None available...
	return $make_connection->($queries);
}

sub done_with_conn {
	(my $conn, my $action) = @_;
	$action //= "commit";
	$action=lc $action;

	if (defined $conn) {
		my %actions=(
			commit => sub { return $_[0]->commit; },
			rollback => sub { return $_[0]->rollback; }
		);

		$actions{$action}->($conn);

		for (grep { $_->[0] == $conn } @connpool) {
			$_->[1]=0;
		}
	}
}

1;
