#!/usr/bin/perl

use Mojolicious::Lite;
use Mojo::JSON qw/encode_json/;
use Digest::MD5 qw/md5 md5_hex/;
use MIME::Base64;
use URL::Encode qw/url_encode/;

app->config(hypnotoad => { listen => ['http://*:3000'] });

my $directory="public/uploads";

unless (-e $directory) {
	mkdir($directory, 0744);
}

get '/' => 'form';

post '/upload' => sub { (my $self) = shift;
	return $self->render(data => encode_json({ status => 1, error => 'File too large'})) if $self->req->is_limit_exceeded;

	my $upload=$self->param('upload');
	return $self->redirect_to('form') unless $upload;
	my $size=$upload->size;
	my $name=$upload->filename;

	my $extension="";
	if ($name =~ m%\.[^./]{1,7}$%) {
		($extension) = ($name =~ m%\.([^./]{1,7})$%);
	}

	my $md5;
	if (ref($upload->asset) eq 'Mojo::Asset::File') {
		my $tract=Digest::MD5->new;
		$tract->addfile($upload->asset->handle);
		$md5=$tract->digest;
	} elsif (ref($upload->asset) eq 'Mojo::Asset::Memory') {
		$md5=md5($upload->asset->slurp);
	}
	my $filename;
	while (1) {
		my $b64=encode_base64($md5);
		chomp $b64;
		$b64 =~ s/=*$//;
		my $subdirectory=substr($b64, 0, 8);
		chomp $subdirectory;
		my $rest=substr($b64, 8);
		$rest=($extension) ? "$rest.$extension" : $rest;
		unless (-e "$directory/$subdirectory") {
			mkdir("$directory/$subdirectory", 0744);
		}

		if (-e "$directory/$subdirectory/$rest") {
			$md5++;
			next;
		}
		$upload->move_to("$directory/$subdirectory/$rest");
		$filename=url_encode("$subdirectory/$rest");
		last;
	}

	$self->render(data => encode_json({ status => 0, name=> $name, size=>$size, filename => $filename }));
};

app->start;
