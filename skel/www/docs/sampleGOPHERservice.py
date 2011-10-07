#!/usr/bin/env python
# -*- coding: utf-8 -*-

# $Id$
# Sample GOPHER service
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

def launchJob(callback, query, common):
	"""
		This is the function where you have to put your service work...
		First parameter is the callback URI where we have to send each one of the results.
		Second parameter is the xcesc:query XML fragment, with all the details of the job.
		Third parameter is the xcesc:common XML fragment (if available), with all the shared details needed
		by any value of second parameter.
		As it is an asynchronous work, you should use here your favourite queue system (SGE, NQS, etc...).
		This example only uses fork, which could saturate the server with a DoS attack.
		If the job is accepted, it returns the queryId, otherwise it returns None.
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
			
			# Here the service must do the job, whose results are reflected on 0 or more
			# match elements. As this is a sample service, no match is appended based on
			# input query, because it means 'no result'.
			
			"""
			# A match is as easy as:
			match = answerDoc.createElementNS(XCESC_NS,'match')
			answer.appendChild(match)
			match.setAttribute('source','ab-initio')
			# It is much easier to generate an UTC timestamp in Python than a localized one
			match.setAttribute('timeStamp',datetime.utcnow().isoformat()+'Z')
			"""
			
			"""
			# When you want to narrow the scope of the prediction/assessment you have to use
			# one or more scope elements. For instance:
			scope = answerDoc.createElementNS(XCESC_NS,'scope')
			match.appendChild(scope)
			scope.setAttribute('from',1)
			scope.setAttribute('to',20)
			"""
			
			# And the results, which depending on the kind of prediction or assessment
			# will be one or more term elements, or one or more result elements
			
			"""
			# An example of annotation/assessment with term elements would be:
			term = answerDoc.createElementNS(XCESC_NS,'term')
			match.appendChild(term)
			term.setAttribute('namespace','GO')
			term.setAttribute('id','GO:0004174')
			
			# If the annotation/assessment 'id' belongs to a subset which should be
			# declared in order to ease the identifier recognition, use 'kind'
			# In this example, using the nomenclature from GOA and UniProt, this
			# GO term is from Molecular Function ontology, which abbreviated form
			# is 'F'
			term.setAttribute('kind','F')
			
			metric = answerDoc.createElementNS(XCESC_NS,'metric')
			term.appendChild(metric)
			metric.setAttribute('type','score')
			metric.appendChild(answerDoc.createTextNode(100))
			
			metric = answerDoc.createElementNS(XCESC_NS,'metric')
			term.appendChild(metric)
			metric.setAttribute('type','p-value')
			metric.appendChild(answerDoc.createTextNode(0.5))
			"""
			
			"""
			# An example of annotation/assessment with result elements would be:
			result = answerDoc.createElementNS(XCESC_NS,'result')
			match.appendChild(result)
			metrics = answerDoc.createElementNS(XCESC_NS,'metrics')
			result.appendChild(metrics)
			
			otherMetric = answerDoc.createElementNS(XCESC_NS,'metric')
			metrics.appendChild(otherMetric)
			otherMetric.setAttribute('type','score')
			otherMetric.appendChild(answerDoc.createTextNode(50))
			
			otherMetric = answerDoc.createElementNS(XCESC_NS,'metric')
			metrics.appendChild(otherMetric)
			otherMetric.setAttribute('type','p-value')
			otherMetric.appendChild(answerDoc.createTextNode(0.1))
			
			result.appendChild(answerDoc.createCDATASection('This could be, for instance, a PDB'))
			"""
			
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
							queryId = launchJob(callback,query,common)
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
