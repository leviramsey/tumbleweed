-- SQL DB schema for Tumbleweed

USE tumbleweed;

CREATE TABLE users (
	uid INT(8) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(16) NOT NULL,
	email VARCHAR(32) NOT NULL,
	verified BOOLEAN NOT NULL
) ENGINE 'InnoDB';

--- Not yet implemented in tier2
CREATE TABLE user_verifies (
	uid INT(8) UNSIGNED PRIMARY KEY,
	code VARCHAR(8) NOT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';

-- Not all users will log in via local passwords (e.g. facebook, google, etc. logins)
CREATE TABLE user_auths (
	uid INT(8) UNSIGNED PRIMARY KEY,
	hash VARCHAR(31) NOT NULL,
	cost INT(2) UNSIGNED NOT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';
