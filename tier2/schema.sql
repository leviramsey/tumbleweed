-- SQL DB schema for Tumbleweed

CREATE DATABASE IF NOT EXISTS tumbleweed;

USE tumbleweed;

CREATE TABLE IF NOT EXISTS users (
	uid INT(8) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(16) NOT NULL,
	email VARCHAR(32) NOT NULL,
	verified BOOLEAN NOT NULL,
	long_name VARCHAR(40) NOT NULL,
	dob DATE NOT NULL
) ENGINE 'InnoDB';

--- Not yet implemented in tier2
CREATE TABLE IF NOT EXISTS user_verifies (
	uid INT(8) UNSIGNED PRIMARY KEY,
	code VARCHAR(8) NOT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';

-- Not all users will log in via local passwords (e.g. facebook, google, etc. logins)
CREATE TABLE IF NOT EXISTS user_auths (
	uid INT(8) UNSIGNED PRIMARY KEY,
	hash VARCHAR(31) NOT NULL,
	cost INT(2) UNSIGNED NOT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';

-- The extra attributes for user profile pages
CREATE TABLE IF NOT EXISTS user_extdata (
	uid INT(8) UNSIGNED NOT NULL,
	k VARCHAR(16) NOT NULL,
	v TINYTEXT NOT NULL,
	priority INT(2) UNSIGNED NOT NULL DEFAULT 0,
	display BOOLEAN NOT NULL DEFAULT 0,
	PRIMARY KEY (uid,k),
	FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB'
