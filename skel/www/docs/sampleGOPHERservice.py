#!/usr/bin/env python
# -*- coding: utf-8 -*-

import cgi
import cgitb
cgitb.enable()
from time import gmtime, strftime
import quopri

import os
import sys
import signal
import urllib2
import xml.dom.minidom
from xml.dom.minidom import Node
import time

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
	#	modHeaders["Date"] = strftime("%a, %d %b %Y %H:%M:%S +0000", gmtime())
	if status is None:
		status="200 OK"
	print >> output, "Status: "+quopri.encodestring(status)
	print >> output, "Content-Type: "+contentType
	for k,v in modHeaders.items():
		print >> output , quopri.encodestring(k+": "+v)
	print >> output

def launchJob(callback, query):
	"""
		This is the function where you have to put your service work...
		First parameter is the callback URI where we have to send each one of the results.
		Second parameter is the xcesc:query XML fragment, with all the details of the job.
		As it is an asynchronous work, you should use here your favourite queue system (SGE, NQS, etc...).
		This example only uses fork, which could saturate the server with a DoS attack.
		If the job is accepted, it returns 1, otherwise it returns None.
	"""
	
	# We have to ignore pleas from the children
	signal.signal(signal.SIGCHLD,signal.SIG_IGN)
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
			
			answer = answerDoc.createElementNS(XSCESC_NS,'answer')
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
			match.setAttribute('domain','ab-initio')
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
			# An example of annotation/assessment with term elements would be
			term = answerDoc.createElementNS(XCESC_NS,'term')
			match.appendChild(term)
			term.setAttribute('namespace','GO')
			term.setAttribute('publicId','GO:0004174')
			term.setAttribute('score',100)
			term.setAttribute('p-value',0.5)
			"""
			
			"""
			#
			# An example of annotation/assessment with result elements would be
			result = answerDoc.createElementNS(XCESC_NS,'result')
			match.appendChild(result)
			result.setAttribute('score',50)
			result.setAttribute('p-value',0.1)
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
					data = u.read()
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
			return True
	except:
		# No job, no party!
		return None
	
	return True


form = cgi.FieldStorage(headers={"content-type": ""})

errstate = None
httpcode = 202
if form.file is None:
	errstate = "Empty Query Message"
	httpcode = 400
else:
	print_http_headers(headers={"Content-Type": "application/xml"})
	try:
		doc = xml.dom.minidom.parse(form.file)
		el = doc.documentElement
		if el.namespaceURI == XCESC_NS and el.localName == 'queries':
			if el.hasAttribute('callback'):
				callback = el.getAttribute('callback')
				
				for query in el.childNodes():
					if query.nodeType == Node.ELEMENT_NODE and query.localName == 'query' and query.namespaceURI == XCESC_NS and query.hasAttribute('queryId'):
						if launchJob(callback,query):
							errstate = 'Accepted'
					
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

print_http_headers(status = "%s %s" % (httpcode,errstate))
print "<html><head><title>%s %s</title></head><body><div align='center'><h1>%s %s</h1></div></body></html>" % (httpcode, errstate, httpcode, errstate)

