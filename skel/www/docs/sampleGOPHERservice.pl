#!/usr/bin/perl -W

# Sample GOPHER service
# This code takes as input the query, and it later sends the results 

use strict;

use CGI;
use LWP::UserAgent;
use POSIX qw(setsid);
use XML::LibXML;
use XML::LibXML::XPathContext;

$|=1;

my($XCESC_NS)='http://www.cnio.es/scombio/xcesc/1.0';

sub launchJob($$);

# This is the function where you have to put your service work...
# First parameter is the callback URI where we have to send each one of the results.
# Second parameter is the xcesc:query XML fragment, with all the details of the job.
# As it is an asynchronous work, you should use here your favourite queue system (SGE, NQS, etc...).
# This example only uses fork, which could saturate the server with a DoS attack.
# If the job is accepted, it returns 1, otherwise it returns undef.
sub launchJob($$) {
	my($callback,$query)=@_;
	
	# We have to ignore pleas from the children
	$SIG{CHLD}='IGNORE';
	
	my($pid)=fork();
	
	if(defined($pid)) {
		# This is the child
		if($pid==0) {
			# As we are using dumb forks, we must close connections to the parent process
			close(STDIN);
			open(STDIN,'<','/dev/null');
			close(STDOUT);
			open(STDOUT,'>','/dev/null');
			close(STDERR);
			open(STDERR,'>','/dev/null');
			setsid();
			
			# Here the query is parsed
			my($answerDoc)=XML::LibXML::Document->new('1.0','UTF-8');
			my($answers)=$answerDoc->createElementNS($XCESC_NS,'answers');
			$answerDoc->setDocumentElement($answers);

			my($answer)=$answerDoc->createElementNS($XCESC_NS,'answer');
			$answer->setAttribute('targetId',$query->getAttribute('queryId'));
			$answers->appendChild($answer);
			
			# And if you want to signal something about this run, set message attribute
			# $answer->setAttribute('message','Something happened');
			
			# Here the service must do the job, whose results are reflected on 0 or more
			# match elements. As this is a sample service, no match is appended based on
			# input query, because it means 'no result'.
			
			# A match is as easy as:
			# my($match)=$answerDoc->createElementNS($XCESC_NS,'match');
			# $answer->appendChild($match);
			# $match->setAttribute('domain','ab-initio');
			
			# When you want to narrow the scope of the prediction/assessment you have to use
			# one or more scope elements. For instance:
			# my($scope)=$answerDoc->createElementNS($XCESC_NS,'scope');
			# $match->appendChild($scope);
			# $scope->setAttribute('from',1);
			# $scope->setAttribute('to',20);
			
			# And the results, which depending on the kind of prediction or assessment
			# will be one or more term elements, or one or more result elements
			#
			# An example of annotation/assessment with term elements would be
			# my($term)=$answerDoc->createElementNS($XCESC_NS,'term');
			# $match->appendChild($term);
			# $term->setAttribute('namespace','GO');
			# $term->setAttribute('publicId','GO:0004174');
			# $term->setAttribute('score',100);
			# $term->setAttribute('p-value',0.5);
			#
			# An example of annotation/assessment with result elements would be
			# my($result)=$answerDoc->createElementNS($XCESC_NS,'result');
			# $match->appendChild($result);
			# $result->setAttribute('score',50);
			# $result->setAttribute('p-value',0.1);
			# $result->appendChild($answerDoc->createCDATASection('This could be, for instance, a PDB'));
			
			# Once the work has finished, results are sent to the GOPHER server.
			# The user agent is completely optional!!!!
			my($ua)=LWP::UserAgent->new(" GOPHER Answer 0.1");
			
			# Again, beware encodings!!!!!!!
			for(;;) {
				my($response)=$ua->post(
					$callback,
					Content_Type=>'application/xml',
					Content=>$answerDoc->serialize(0)
				);
				
				# Success or ill formed request
				# If it is the second, you should write to
				# gopher_support@cnio.es
				if($response->is_success() || $response->code() eq '400') {
					last;
				} else {
					# Let's wait a minute, and try again, because there could be some transient error...
					sleep(60);
				}
			}
			
			# Cleanups (if needed)
			# And then finish!
			exit(0);
		} else {
			# This is the parent, which has to do nothing...
			return 1;
		}
	} else {
		# No job, no party!
		return undef;
	}
}

my($c)=CGI->new();
my($doc)=undef;
my($errstate)=undef;
my($httpcode)=202;

# First, let's catch params
foreach my $param ($c->param()) {
	if($param eq 'POSTDATA' || $param eq 'XForms:Model') {
		# Let's parse the incoming XML message, which must
		# follow XCESC schema
		eval {
			my($parser)=XML::LibXML->new();
			# Beware encodings here!!!!
			$doc=$parser->parse_string($c->param($param));
		};
		if($@) {
			$errstate='Error while parsing the input GOPHER XML message';
			$httpcode=400;
		}
		last;
	}
}

if(defined($doc)) {
	my($context)=XML::LibXML::XPathContext->new();
	my($el)=$doc->documentElement();
	if($el->namespaceURI() eq $XCESC_NS && $el->localname() eq 'queries') {
		my($callback)=$el->getAttribute('callback');
		if(defined($callback) && $callback ne '') {
			$context->registerNs('xcesc',$XCESC_NS);
			
			foreach my $query ($context->findnodes('//xcesc:query',$doc)) {
				# This is the function to implement
				$errstate='Accepted'  if(launchJob($query,$callback));
			}
		}
	} else {
		$errstate='XML Document is not a GOPHER queries one!';
		$httpcode=400;
	}
}

if(!defined($errstate)) {
	# Setting a default error state
	$errstate='Empty query';
	$httpcode=400;
}

print $c->header(-status=>"$httpcode $errstate"),"<html><head><title>$httpcode $errstate</title></head><body><div align='center'><h1>$httpcode $errstate</h1></div></body></html>";
