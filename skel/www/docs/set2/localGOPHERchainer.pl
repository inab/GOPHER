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

# For the temporal files saved by this tester file
umask(2);

my($XCESC_NS)='http://www.cnio.es/scombio/xcesc/1.0';

my($c)=CGI->new();
my $hasQueryDoc = undef;
my($doc)=undef;
my($errstate)=undef;
my($httpcode)=202;

my $serviceParticipant = undef;
my $serviceEvaluator = undef;

# First, let's catch params
foreach my $param ($c->param()) {
	if($param eq 'participantUrl') {
		$serviceParticipant = $c->param($param);
	} elsif($param eq 'evaluatorUrl') {
		$serviceEvaluator = $c->param($param);
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

if(defined($serviceParticipant)) {
	my $fileToSend = $FindBin::Bin .'/'. 'set2-PredInput.xml';
	
	my $uuid = `uuidgen`;
	chomp($uuid);
	my $edoc;
	my $scriptURI = undef;
	
	if(exists($ENV{'SCRIPT_URI'}) && index($ENV{'SCRIPT_URI'},'http')==0) {
		$scriptURI = $ENV{'SCRIPT_URI'};
	} elsif(exists($ENV{'SCRIPT_URL'})) {
		my $proto = undef;
		my $port = $ENV{'SERVER_PORT'};
		if($port eq '443') {
			$proto='https';
			$port='';
		} else {
			$proto='http';
			$port=''  if($port eq '80');
		}
		$port = ':'.$port  unless(length($port)==0);
		$scriptURI = $proto.'://'.$ENV{'SERVER_NAME'}.$port.$ENV{'SCRIPT_URL'};
	}
	eval {
		my($parser)=XML::LibXML->new();
		# Beware encodings here!!!!
		$edoc=$parser->parse_file($fileToSend);
		$edoc->documentElement()->setAttribute('callback',$scriptURI.'/'.$uuid);
		
		my $F;
		$edoc->toFile('/tmp/gopher-'.$uuid.'-init.xml');
		
		# Saving the serviceEvaluator to be chained to
		if(defined($serviceEvaluator)) {
			my $EV;
			if(open($EV,'>','/tmp/gopher-'.$uuid.'-evaluator.url')) {
				print $EV $serviceEvaluator;
				close($EV);
			}
		}
	};
	
	if($@) {
		$errstate='Error while preparing input GOPHER XML message';
		$httpcode=400;
	} else {
		my($ua)=LWP::UserAgent->new();
		my($response)=$ua->post(
			$serviceParticipant,
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
			
			# And now, let's prepare here the document to be sent to the evaluator
			my $EV;
			if(open($EV,'<','/tmp/gopher-'.$hasQueryDoc.'-evaluator.url')) {
				$serviceEvaluator = <$EV>;
				close($EV);
				
				chomp($serviceEvaluator);
				# As we have an URL, let's prepare the dance!
				
				my $templateToFill = $FindBin::Bin .'/'. 'set2-AssessInputTemplate.xml';
				
				my $uuid = `uuidgen`;
				chomp($uuid);
				my $edoc;
				my $scriptURI = undef;
				
				if(exists($ENV{'SCRIPT_URI'}) && index($ENV{'SCRIPT_URI'},'http')==0) {
					$scriptURI = $ENV{'SCRIPT_URI'};
				} elsif(exists($ENV{'SCRIPT_URL'})) {
					my $proto = undef;
					my $port = $ENV{'SERVER_PORT'};
					if($port eq '443') {
						$proto='https';
						$port='';
					} else {
						$proto='http';
						$port=''  if($port eq '80');
					}
					$port = ':'.$port  unless(length($port)==0);
					$scriptURI = $proto.'://'.$ENV{'SERVER_NAME'}.$port.$ENV{'SCRIPT_URL'};
				}
				
				my $added = 0;
				eval {
					my($parser)=XML::LibXML->new();
					# Beware encodings here!!!!
					$edoc=$parser->parse_file($templateToFill);
					$edoc->documentElement()->setAttribute('callback',$scriptURI.'/'.$uuid);
					
					my $xpc = XML::LibXML::XPathContext->new();
					$xpc->registerNs('x',$XCESC_NS);
					
					# From the answers given by the predictor, to the evaluator
					my @answers = $xpc->findnodes('/x:answers/x:answer',$doc);
					
					foreach my $answer (@answers) {
						next  unless($answer->hasAttribute('targetId'));
						
						my $targetId = $answer->getAttribute('targetId');
						my @nEvals = $xpc->findnodes('/x:queries/x:query/x:answer[@targetId = '."'$targetId'".']',$edoc);
						
						if(scalar(@nEvals)>0) {
							my $nEval = $nEvals[0];
							# Appending the answers
							foreach my $child ($answer->childNodes()) {
								$nEval->appendChild($edoc->importNode($child));
							}
							$added++;
						}
					}
					
					if($added > 0) {
						my $F;
						$edoc->toFile('/tmp/gopher-'.$uuid.'-init.xml');
					}					
				};
				
				if($@) {
					$errstate='Error while preparing input GOPHER XML message';
					$httpcode=400;
				} elsif($added > 0) {
					my($ua)=LWP::UserAgent->new();
					my($response)=$ua->post(
						$serviceEvaluator,
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
			}
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
