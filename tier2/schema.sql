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

-- Not yet implemented in tier2
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
) ENGINE 'InnoDB';

-- Avatars
CREATE TABLE IF NOT EXISTS user_icons (
	uid INT(8) UNSIGNED NOT NULL PRIMARY KEY,
	gravatar BOOLEAN NOT NULL,
	locloc TINYTEXT DEFAULT NULL,
	FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';

-- The master content index
-- Kinds of content
-- 0: challenges
-- 1: responses
-- 2: comments
-- Visibilities: 0 - global, 1 - friends
CREATE TABLE IF NOT EXISTS content (
	id INT(32) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	poster INT(8) UNSIGNED NOT NULL,
	kind INT(1) UNSIGNED NOT NULL,
	posted DATETIME NOT NULL,
	title TINYTEXT NOT NULL,
	FOREIGN KEY (poster) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';

-- Tags
CREATE TABLE IF NOT EXISTS taggings (
	tag VARCHAR(32) NOT NULL,
	target INT(32) UNSIGNED NOT NULL AUTO_INCREMENT,
	PRIMARY KEY (tag,target),
	FOREIGN KEY (target) REFERENCES content(id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';

-- Challenge metadata
CREATE TABLE IF NOT EXISTS challenges (
	id INT(32) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	expiration DATETIME DEFAULT NULL,
	global BOOLEAN NOT NULL,
	FOREIGN KEY (id) REFERENCES content(id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';

-- Response metadata
CREATE TABLE IF NOT EXISTS responses (
	id INT(32) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	response_to INT(32) UNSIGNED NOT NULL,
	verified INT(1) NOT NULL,
	FOREIGN KEY (id) REFERENCES content(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (response_to) REFERENCES challenges(id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE 'InnoDB';
