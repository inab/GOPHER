#!/usr/bin/perl -W

# $Id$
# GOPHER tester service
# This code takes as URL input the url of the service to test, and its role

use strict;

use CGI;
use LWP::UserAgent;
use POSIX qw(setsid);
use XML::LibXML;
use XML::LibXML::Common;
use POSIX qw(strftime);
use FindBin;

$|=1;

my($XCESC_NS)='http://www.cnio.es/scombio/xcesc/1.0';

my($c)=CGI->new();
my $hasQueryDoc = undef;
my($doc)=undef;
my($errstate)=undef;
my($httpcode)=202;

my $serviceToTest = undef;
my $serviceKind = 'participant';

# First, let's catch params
foreach my $param ($c->param()) {
	if($param eq 'url') {
		$serviceToTest = $c->param($param);
	} elsif($param eq 'kind') {
		$serviceKind = ($c->param($param) eq 'evaluator')?'evaluator':'participant';
	} elsif($param eq 'POSTDATA' || $param eq 'XForms:Model') {
		# Let's parse the incoming XML message, which must
		# follow XCESC schema
		$hasQueryDoc = substr($c->path_info(),1);
		eval {
			my($parser)=XML::LibXML->new();
			# Beware encodings here!!!!
			$doc=$parser->parse_string($c->param($param));
		};
		if($@) {
			$errstate='Error while parsing the input GOPHER XML message';
			$httpcode=400;
			my $uuid = `uuidgen`;
			chomp($uuid);

			my $F;
			if(open($F,'>','/tmp/gopher-'.$hasQueryDoc.'-failedResponse-'.$uuid.'.txt')) {
				print $F $c->param($param);
				close($F);
			}
		}
		last;
	}
}

if(defined($serviceToTest)) {
	my $fileToSend = $FindBin::Bin .'/'. (($serviceKind eq 'evaluator')?'sampleAssessInput.xml':'samplePredInput.xml');
	
	my $uuid = `uuidgen`;
	chomp($uuid);
	my $edoc;
	eval {
		my($parser)=XML::LibXML->new();
		# Beware encodings here!!!!
		$edoc=$parser->parse_file($fileToSend);
		$edoc->documentElement()->setAttribute('callback',$ENV{'SCRIPT_URI'}.'/'.$uuid);
		
		my $F;
		$edoc->toFile('/tmp/gopher-'.$uuid.'-init.xml');
	};
	
	if($@) {
		$errstate='Error while preparing input GOPHER XML message';
		$httpcode=400;
	} else {
		my($ua)=LWP::UserAgent->new();
		my($response)=$ua->post(
			$serviceToTest,
			Content_Type=>'application/xml',
			Content=>$edoc->serialize(0)
		);
		
		my $F;
		my $filename = '/tmp/gopher-'.$uuid.'-initResponse.txt';
		if(open($F,'>',$filename)) {
			print $F $response->content();
			close($F);
		}
		
		unless($response->is_success()) {
			$errstate='Error on initial answer from GOPHER service: '.$response->code();
			$httpcode=400;
		} else {
			$errstate = $filename;
		}
	}
} elsif(defined($hasQueryDoc)) {
	if(defined($doc)) {
		my($el)=$doc->documentElement();
		if($el->namespaceURI() eq $XCESC_NS && $el->localname() eq 'answers') {
			my $uuid = `uuidgen`;
			chomp($uuid);
			my $filename = '/tmp/gopher-'.$hasQueryDoc.'-answer-'.$uuid.'.xml';
			$doc->toFile($filename);
			$errstate = $filename;
		} else {
			$errstate='XML Document is not a GOPHER queries one!';
			$httpcode=400;
		}
	}
} else {
	$errstate = "Empty Query Message";
	$httpcode = 400;
}

if(!defined($errstate)) {
	# Setting a default error state
	$errstate='No query has been accepted';
	$httpcode=400;
}

print $c->header(-status=>"$httpcode $errstate"),"<html><head><title>$httpcode $errstate</title></head><body><div align='center'><h1>$httpcode $errstate</h1></div></body></html>";
