#!/usr/bin/env python
# -*- coding: utf-8 -*-

# $Id$
# Sample GOPHER evaluator
# This code takes as input the query, and it later sends the results 

import sys
import os

# Unbuffered behavior for stdout and stderr!
if __name__ == "__main__":
	unbuffered = os.fdopen(sys.stdout.fileno(),'w',0)
	sys.stdout = unbuffered
	
	unbuffered = os.fdopen(sys.stderr.fileno(),'w',0)
	sys.stderr = unbuffered

import cgi
import cgitb
cgitb.enable()
import quopri
import time

import signal
import urllib2
import xml.dom.minidom
from xml.dom.minidom import Node
from datetime import datetime

XCESC_NS = 'http://www.cnio.es/scombio/xcesc/1.0'

def print_http_headers(status=None,headers={},output=None):
	modHeaders = headers
	contentType = "text/html"
	charset = "utf-8"
	if "Content-Type" in headers:
		contentType = modHeaders["Content-Type"]
		del modHeaders["Content-Type"]
	contentType=quopri.encodestring(contentType)
	if "charset" in headers:
		charset = modHeaders["charset"]
		del modHeaders["charset"]
	if charset is not None:
		contentType += "; charset="+quopri.encodestring(charset)
	#if "Date" not in headers:
	#	modHeaders["Date"] = time.strftime("%a, %d %b %Y %H:%M:%S +0000", time.gmtime())
	if status is None:
		status="200 OK"
	print >> output, "Status: "+quopri.encodestring(status)
	print >> output, "Content-Type: "+contentType
	for k,v in modHeaders.items():
		print >> output , quopri.encodestring(k+": "+v)
	print >> output

def launchEvaluationJob(callback, query, common):
	"""
		This is the function where you have to put your results evaluation work...
		First parameter is the callback URI where we have to send each one of the results.
		Second parameter is the xcesc:query XML fragment, with all the details needed to start an assessment.
		Third parameter is the xcesc:common XML fragment (if available), with all the shared details needed
		by any value of second parameter.
		As it is an asynchronous work, you should use here your favourite queue system (SGE, NQS, etc...).
		This example only uses fork, which could saturate the server with a DoS attack.
		If the assessment job is accepted, it returns the queryId, otherwise it returns None.
	"""
	
	# We have to ignore pleas from the children
	signal.signal(signal.SIGCHLD,signal.SIG_IGN)
	
	# The variable which will contain the return value (the jobId or None)
	retval = None
	
	try:
		pid = os.fork()
		
		# This is the child
		if pid==0:
			# As we are using dumb forks, we must close connections to the parent process
			sys.stdin.close()
			# This is needed because Python does not close underlying C streams
			# See http://effbot.org/pyfaq/why-doesn-t-closing-sys-stdout-stdin-stderr-really-close-it.htm
			os.close(0)
			sys.stdin.open('/dev/null')
			
			sys.stdout.close()
			os.close(1)
			sys.stdout.open('/dev/null',"w")
			
			sys.stderr.close()
			os.close(2)
			sys.stderr.open('/dev/null',"w")
			
			os.setsid()
			
			# Here the query is parsed, and answer is built
			domImplementation = xml.dom.minidom.getDOMImplementation()
			
			answerDoc = domImplementation.createDocument(XCESC_NS, 'answers', None)
			answers = answerDoc.documentElement
			answers.setAttribute('xmlns',XCESC_NS)
			
			answer = answerDoc.createElementNS(XCESC_NS,'answer')
			answer.setAttribute('targetId',query.getAttribute('queryId'))
			answers.appendChild(answer)
			
			"""
			# And if you want to signal something about this run, set message attribute
			answer.setAttribute('message','Something happened')
			"""
			
			# Here the evaluation service must do the assessment job, whose results are reflected
			# on 0 or more jobEvaluation elements. As this is a sample service, no match is
			# appended based on input query, because it means 'no result'.
			
			for predAnswer in query.childNodes():
				if predAnswer.nodeType == Node.ELEMENT_NODE and predAnswer.localName == 'answer' and predAnswer.namespaceURI == XCESC_NS and predAnswer.hasAttribute('targetId'):
					jobEvaluation = answerDoc.createElementNS(XCESC_NS,'jobEvaluation')
					answer.appendChild(jobEvaluation)
					jobEvaluation.setAttribute('timeStamp',datetime.utcnow().isoformat()+'Z')

					# The targetId comes from the prediction's 'answer' targetId
					# and it is the same as the queryId from 'query' inside 'target'
					queryId = predAnswer.getAttribute('targetId')
					jobEvaluation.setAttribute('targetId',queryId)
					
					# This variable will containt the 'target' element
					target = None
					for match in predAnswer.childNodes():
						if match.nodeType == Node.ELEMENT_NODE and match.namespaceURI == XCESC_NS:
							if match.localName == 'target':
								# This information is needed to evaluate later
								target = match
							elif queryId is not None and match.localName == 'match':
								# An evaluation match is as easy as:
								evaluation = answerDoc.createElementNS(XCESC_NS,'evaluation')
								jobEvaluation.appendChild(evaluation)
								
								"""
								# If you want to include the raw report, do the next
								report = answerDoc.createElementNS(XCESC_NS,'report')
								evaluation.appendChild(report)
								report.appendChild(answerDoc.createCDATASection('This could be, for instance, the raw output of a program'))
								"""
								
								"""
								# When you have been able to assess the quality of the place where the prediction/assessment is
								# you use the placeQuality element
								placeQuality = answerDoc.createElementNS(XCESC_NS,'placeQuality')
								evaluation.appendChild(placeQuality)
								# Precision
								placeQuality.setAttribute('precision',0.5)
								# Recall
								placeQuality.setAttribute('recall',0.4)
								# And the subjective appreciation: right, partial, under, over, wrong, missing
								placeQuality.appendChild(answerDoc.createTextNode('under'))
								"""
								
								"""
								# When you have been able to assess the quality of the annotation where
								# the prediction/assessment is, you use the annotationQuality element
								annotationQuality = answerDoc.createElementNS(XCESC_NS,'annotationQuality')
								evaluation.appendChild(annotationQuality)
								# Precision
								annotationQuality.setAttribute('precision',1)
								# Recall
								annotationQuality.setAttribute('recall',0.1)
								# And the subjective appreciation: right, under, over, wrong, missing
								annotationQuality.appendChild(answerDoc.createTextNode('right'))
								"""
								
								# And a copy of the match being evaluated
								evaluated = answerDoc.createElementNS(XCESC_NS,'evaluated')
								evaluation.appendChild(evaluated)
								evaluated.appendChild(answerDoc.importNode(match), True)
			
			# Once the work has finished, results are sent to the GOPHER server.
			# The user agent is completely optional!!!!
			req = urllib2.Request(url=callback,data=answerDoc.toprettyxml(encoding="UTF-8"),headers={'User-Agent': " GOPHER Answer 0.1",'Content-Type': 'application/xml'})
			
			# Again, beware encodings!!!!!!!
			while True:
				netErrFlag = None
				# Success or ill formed request
				try:
					f = urllib2.urlopen(req)
					data = f.read()
					break
				except urllib2.HTTPError, e:
					# If it is the second, you should write to
					# gopher_support@cnio.es
					if e.code == 400:
						break
				except:
					# Transient network error
					netErrFlag = True
				
				# Let's wait a minute, and try again, because there could be some transient error...
				time.sleep(60)
			
			# Cleanups (if needed)
			# And then finish!
			sys.exit(0)
		else:
			# This is the parent, which has to do nothing...
			retval = query.getAttribute('queryId')
	except:
		# No job, no party (retval == None)!
		retval = None
	
	return retval


form = cgi.FieldStorage(headers={"content-type": ""})

errstate = None
httpcode = 202
acceptedList = []
if form.file is None:
	errstate = "Empty Query Message"
	httpcode = 400
else:
	try:
		doc = xml.dom.minidom.parse(form.file)
		el = doc.documentElement
		if el.namespaceURI == XCESC_NS and el.localName == 'queries':
			if el.hasAttribute('callback'):
				callback = el.getAttribute('callback')
				common = None
				
				for query in el.childNodes():
					if query.nodeType == Node.ELEMENT_NODE and query.namespaceURI == XCESC_NS:
						if query.localName == 'common':
							common = query
						elif query.localName == 'query' and query.hasAttribute('queryId'):
							queryId = launchEvaluationJob(callback,query,common)
							if queryId is not None:
								errstate = 'Accepted'
								acceptedList.append(queryId)
				
#				doc.writexml(writer=sys.stdout)
			else:
				errstate = 'XML Document does not contain a callback!'
				httpcode = 400
		else:
			errstate = 'XML Document is not a GOPHER queries one!'
			httpcode = 400
	except:
		errstate = 'Error while parsing the input GOPHER XML message'
		httpcode = 400

if errstate is None:
	errstate = 'No query has been accepted'
	httpcode = 400

if httpcode == 202:
	domImplementation = xml.dom.minidom.getDOMImplementation()
	
	acceptedDoc = domImplementation.createDocument(XCESC_NS, 'acceptedQueries', None)
	acceptedQueries = acceptedDoc.documentElement
	acceptedQueries.setAttribute('timeStamp',datetime.utcnow().isoformat()+'Z')
	
	for queryId in acceptedList:
		accepted = acceptedDoc.createElementNS(XCESC_NS,'accepted')
		accepted.setAttribute('queryId',queryId)
		acceptedQueries.appendChild(accepted)
	
	print_http_headers(status = "%s %s" % (httpcode,errstate),headers = {'Content-Type': 'application/xml'})
	acceptedDoc.writexml(writer=sys.stdout,encoding="UTF-8")
else:
	print_http_headers(status = "%s %s" % (httpcode,errstate))
	print "<html><head><title>%s %s</title></head><body><div align='center'><h1>%s %s</h1></div></body></html>" % (httpcode, errstate, httpcode, errstate)
