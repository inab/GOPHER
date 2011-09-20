#!/usr/bin/perl -W

# $Id$
# Sample GOPHER evaluator
# This code takes as input the query, and it later sends the results 

use strict;

use CGI;
use LWP::UserAgent;
use POSIX qw(setsid);
use XML::LibXML;
use XML::LibXML::Common;
use POSIX qw(strftime);

$|=1;

my($XCESC_NS)='http://www.cnio.es/scombio/xcesc/1.0';

sub getPrintableDate(;$);
sub launchEvaluationJob($$$);

# this is only a helper function to generate ISO8601 timestamp strings
sub getPrintableDate(;$) {
        my($now)= @_;
        
        $now=time()  unless(defined($now) && $now ne '');
        # We need to munge the timezone indicator to add a colon between the hour and minute part
        my @loc = localtime($now);
        my $tz = strftime("%z", @loc);
        $tz =~ s/(\d{2})(\d{2})/$1:$2/;

        # ISO8601
        return strftime("%Y-%m-%dT%H:%M:%S", @loc) . $tz;
}

# This is the function where you have to put your results evaluation work...
# First parameter is the callback URI where we have to send each one of the results.
# Second parameter is the xcesc:query XML fragment, with all the details needed to start an assessment.
# Third parameter is the xcesc:common XML fragment (if available), with all the shared details needed
# by any value of second parameter.
# As it is an asynchronous work, you should use here your favourite queue system (SGE, NQS, etc...).
# This example only uses fork, which could saturate the server with a DoS attack.
# If the assessment job is accepted, it returns the queryId, otherwise it returns undef.
sub launchEvaluationJob($$$) {
	my($callback,$query,$common)=@_;
	
	# We have to ignore pleas from the children
	$SIG{CHLD}='IGNORE';
	
	# The variable which will contain the return value (the jobId or undef)
	my $retval = undef;
	
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
			
			# Here the query is parsed, and answer is built
			my($answerDoc)=XML::LibXML::Document->new('1.0','UTF-8');
			my($answers)=$answerDoc->createElementNS($XCESC_NS,'answers');
			$answerDoc->setDocumentElement($answers);

			my($answer)=$answerDoc->createElementNS($XCESC_NS,'answer');
			$answer->setAttribute('targetId',$query->getAttribute('queryId'));
			$answers->appendChild($answer);
			
			# And if you want to signal something about this run, set message attribute
			# $answer->setAttribute('message','Something happened');
			
			# Here the evaluation service must do the assessment job, whose results are reflected
			# on 0 or more jobEvaluation elements. As this is a sample service, no match is
			# appended based on input query, because it means 'no result'.
			
			foreach my $predAnswer ($query->childNodes()) {
				next  unless(
					$predAnswer->nodeType() eq ELEMENT_NODE &&
					$predAnswer->localname() eq 'answer' &&
					$predAnswer->namespaceURI() eq $XCESC_NS &&
					$predAnswer->hasAttribute('targetId')
				);

				my $jobEvaluation = $answerDoc->createElementNS($XCESC_NS,'jobEvaluation');
				$answer->appendChild($jobEvaluation);
				$jobEvaluation->setAttribute('timeStamp',getPrintableDate());
				
				# The targetId comes from the prediction's 'answer' targetId
				# and it is the same as the queryId from 'query' inside 'target'
				my $queryId = $predAnswer->getAttribute('targetId');
				$jobEvaluation->setAttribute('targetId',$queryId);
				
				# This variable will contain the 'target' element
				my $target = undef;
				foreach my $match ($predAnswer->childNodes()) {
					if($match->nodeType() eq ELEMENT_NODE && $match->namespaceURI() eq $XCESC_NS) {
						if($match->localname() eq 'target') {
							# This information is needed to evaluate later
							$target = $match;
						} elsif(defined($queryId) && $match->localname() eq 'match') {
							# An evaluation match is as easy as:
							my($evaluation)=$answerDoc->createElementNS($XCESC_NS,'evaluation');
							$jobEvaluation->appendChild($evaluation);
							
							# If you want to include the raw report, do the next
							# my($report)=$answerDoc->createElementNS($XCESC_NS,'report');
							# $evaluation->appendChild($report);
							# $report->appendChild($answerDoc->createCDATASection('This could be, for instance, the raw output of a program'));

							# When you have been able to assess the quality of the place where the prediction/assessment is
							# you use the placeQuality element
							# my($placeQuality)=$answerDoc->createElementNS($XCESC_NS,'placeQuality');
							# $evaluation->appendChild($placeQuality);
							# Precision
							# $placeQuality->setAttribute('precision',0.5);
							# Recall
							# $placeQuality->setAttribute('recall',0.4);
							# And a subjective appreciation: right, partial, under, over, wrong, missing
							# $placeQuality->appendChild($answerDoc->createTextNode('under'));
			
							# When you have been able to assess the quality of the annotation where
							# the prediction/assessment is, you use the annotationQuality element
							# my($annotationQuality)=$answerDoc->createElementNS($XCESC_NS,'annotationQuality');
							# $evaluation->appendChild($annotationQuality);
							# Precision
							# $annotationQuality->setAttribute('precision',1);
							# Recall
							# $annotationQuality->setAttribute('recall',0.1);
							# And the subjective appreciation: right, under, over, wrong, missing
							# $annotationQuality->appendChild($answerDoc->createTextNode('right'));
							
							# And a copy of the match being evaluated
							my($evaluated)=$answerDoc->createElementNS($XCESC_NS,'evaluated');
							$evaluation->appendChild($evaluated);
							$evaluated->appendChild($answerDoc->importNode($match));
						}
					}
				}
			}
			
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
			$retval = $query->getAttribute('queryId');
		}
	}
	# No job, no party ($retval == undef)!
	
	return $retval;
}

my($c)=CGI->new();
my $hasQueryDoc = undef;
my($doc)=undef;
my($errstate)=undef;
my($httpcode)=202;
my @acceptedList=();

# First, let's catch params
foreach my $param ($c->param()) {
	if($param eq 'POSTDATA' || $param eq 'XForms:Model') {
		# Let's parse the incoming XML message, which must
		# follow XCESC schema
		$hasQueryDoc = 1;
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

if(defined($hasQueryDoc)) {
	if(defined($doc)) {
		my($el)=$doc->documentElement();
		if($el->namespaceURI() eq $XCESC_NS && $el->localname() eq 'queries') {
			my($callback)=$el->getAttribute('callback');
			my $common = undef;
			if(defined($callback) && $callback ne '') {
				
				foreach my $query ($el->childNodes()) {
					next  unless(
						$query->nodeType() eq ELEMENT_NODE &&
						$query->namespaceURI() eq $XCESC_NS
					);
					
					if($query->localname() eq 'common') {
						$common = $query;
						next;
					}
					
					next  unless(
						$query->localname() eq 'query' &&
						$query->hasAttribute('queryId')
					);
					
					# This is the function to implement
					my $queryId = launchEvaluationJob($callback,$query,$common);
					
					if(defined($queryId)) {
						$errstate='Accepted';
						push(@acceptedList,$queryId);
					}
				}
			} else {
				$errstate='XML Document does not contain a callback!';
				$httpcode=400;
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

if($httpcode == 202) {
	my($acceptedDoc)=XML::LibXML::Document->new('1.0','UTF-8');
	my($acceptedQueries)=$acceptedDoc->createElementNS($XCESC_NS,'acceptedQueries');
	$acceptedDoc->setDocumentElement($acceptedQueries);
	$acceptedQueries->setAttribute('timeStamp',getPrintableDate());

	foreach my $queryId (@acceptedList) {
		my($accepted)=$acceptedDoc->createElementNS($XCESC_NS,'accepted');
		$accepted->setAttribute('queryId',$queryId);
		$acceptedQueries->appendChild($accepted);
	}
	print $c->header(-status=>"$httpcode $errstate",-type=>'application/xml'),$acceptedDoc->serialize(0);
} else {
	print $c->header(-status=>"$httpcode $errstate"),"<html><head><title>$httpcode $errstate</title></head><body><div align='center'><h1>$httpcode $errstate</h1></div></body></html>";
}
