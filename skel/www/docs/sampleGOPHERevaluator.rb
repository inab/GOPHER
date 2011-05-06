#!/usr/bin/ruby

# $Id: sampleGOPHERevaluator.rb 1821 2011-03-22 14:41:57Z jmfernandez $
# Sample GOPHER service
# This code takes as input the query, and it later sends the results 

require 'cgi'
require 'net/http'
require 'time'
require 'uri'
require 'rexml/document'
include REXML

STDOUT.sync = true

XCESC_NS = 'http://www.cnio.es/scombio/xcesc/1.0'

# Trying to override a method from a module inside CGI
# so it is able to give us the untouched POST message
class CGI
	module QueryExtension
		def initialize_query()
			if ("POST" == env_table['REQUEST_METHOD']) and env_table['CONTENT_TYPE'] =~ /(application|text)\/xml/
			  	# start
				stdinput.binmode if defined? stdinput.binmode
				
				content_length = Integer(env_table['CONTENT_LENGTH'])  if(env_table.has_key?('CONTENT_LENGTH'))
				if defined?(content_length) && 10240 < content_length
					require "tempfile"
					body = Tempfile.new('CGI')
				else
					begin
						require "stringio"
						body = StringIO.new
					rescue LoadError
						require "tempfile"
						body = Tempfile.new('CGI')
					end
				end
				if defined? body.binmode
					body.binmode
				end
				
				bufsize = 64 * 1024
				buf = ''
				while true
					buf = stdinput.read(bufsize)
					if buf.nil? || buf.empty?
						break
					end
					body.print buf
				end
				body.rewind

				@params = { 'POSTDATA' => body }
			elsif ("POST" == env_table['REQUEST_METHOD']) and %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n.match(env_table['CONTENT_TYPE'])
			        boundary = $1.dup
			        @multipart = true
			        @params = read_multipart(boundary, Integer(env_table['CONTENT_LENGTH']))
			else
				@multipart = false
				@params = CGI::parse(
					case env_table['REQUEST_METHOD']
					when "GET", "HEAD"
						if defined?(MOD_RUBY)
							Apache::request.args or ""
						else
							env_table['QUERY_STRING'] or ""
						end
					when "POST"
						stdinput.binmode if defined? stdinput.binmode
						stdinput.read(Integer(env_table['CONTENT_LENGTH'])) or ''
					else
						read_from_cmdline
					end
				)
			end

			@cookies = CGI::Cookie::parse((env_table['HTTP_COOKIE'] or env_table['COOKIE']))
		end
	end
end

# This is the function where you have to put your results evaluation work...
# First parameter is the callback URI where we have to send each one of the results.
# Second parameter is the xcesc:query XML fragment, with all the details needed to start an assessment.
# As it is an asynchronous work, you should use here your favourite queue system (SGE, NQS, etc...).
# This example only uses fork, which could saturate the server with a DoS attack.
# If the assessment job is accepted, it returns 1, otherwise it returns nil.
def launchEvaluationJob(callback,query)
	# We have to ignore pleas from the children
	trap('CLD','IGNORE')
	
	# The variable which will contain the return value (the jobId or undef)
	retval = nil
	
	pid = fork
	
	if pid
		# This is the child
		if pid == 0
			# As we are using dumb forks, we must close connections to the parent process
			$stdin.close
			$stdin = File.new('/dev/null', 'r')
			$stdout.close
			$stdout = File.new('/dev/null', 'w')
			$stderr.close
			$stderr = File.new('/dev/null', 'w')
			Process.setsid
			
			# Here the query is parsed, and answer is built
			answerDoc = Document.new()
			# XML declaration with UTF-8 encoding
			answerDoc << XMLDecl.new('1.0','UTF-8')
			answers = Element.new('answers')
			answers.add_namespace(XCESC_NS)
			answerDoc << answers
			
			answer = Element.new('answer',answers)
			answer.attributes['targetId'] = query.attributes['queryId']
			
			# And if you want to signal something about this run, set message attribute
			# answer.attributes['message'] = 'Something happened'
			
			# Here the evaluation service must do the assessment job, whose results are reflected
			# on 0 or more jobEvaluation elements. As this is a sample service, no match is
			# appended based on input query, because it means 'no result'.
			
			query.elements.each { |target|
				if target.name == 'target' and target.namespace == XCESC_NS
					jobEvaluation = Element.new('jobEvaluation',answer)
					jobEvaluation.attributes['timeStamp'] = Time.now.iso8601
					queryId = nil
					
					target.elements.each { |match|
						if match.namespace == XCESC_NS
							if match.name == 'query' and match.attributes.get_attribute('queryId') != nil
								queryId = match.attributes['queryId']
								jobEvaluation.attributes['targetId'] = queryId
							elsif queryId != nil and match.name == 'match'
								# An evaluation match is as easy as:
								evaluation = Element.new('evaluation',jobEvaluation)
								
								# If you want to include the raw report, do the next
								# report = Element.new('report',evaluation)
								# report << CData.new('This could be, for instance, the raw output of a program')
								
								# When you have been able to assess the quality of the place where the prediction/assessment is
								# you use the placeQuality element
								# placeQuality = Element.new('placeQuality',evaluation)
								# Raw score (it could be an e-value, for instance)
								# placeQuality.attributes['score'] = 1
								# Normalized p-value
								# placeQuality.attributes['p-value'] = 0.4
								# And the subjective appreciation: right, partial, under, over, wrong, missing
								# placeQuality << Text.new('under')
								
								# When you have been able to assess the quality of the annotation where
								# the prediction/assessment is, you use the annotationQuality element
								# annotationQuality = Element.new('annotationQuality',evaluation)
								# Raw score (it could be an e-value or other kind of native score, for instance)
								# annotationQuality.attributes['score'] = 2
								# Normalized p-value
								# annotationQuality.attributes['p-value'] = 0.1
								# And the subjective appreciation: right, under, over, wrong, missing
								# annotationQuality << Text.new('right')
								
								# Optional custom appreciations from any namespace (zero or more)
								# term = Element.new('term',evaluation)
								# term.attributes['namespace'] = 'GO'
								# term.attributes['id'] = 'GO:12345'
								# Raw score (it could be an e-value or other kind of native score, for instance)
								# term.attributes['score'] = 2
								# Normalized p-value
								# term.attributes['p-value'] = 0.1
								
								# And a copy of the match being evaluated
								imported = match.deep_clone
								imported.parent = evaluation
							end
						end
					}
				end
			}
			
			# Once the work has finished, results are sent to the GOPHER server.
			# The user agent is completely optional!!!!
			callback_uri = URI.parse(callback)
			req = Net::HTTP.new(callback_uri.host,callback_uri.port)
			
			while true
				response = req.request_post(callback_uri.path,answerDoc.to_s,{'User-Agent' => ' GOPHER Answer 0.1','Content-Type' => 'application/xml'})
				
				# Success or ill formed request
				# If it is the second, you should write to
				# gopher_support@cnio.es
				if response.code == '200' or response.code == '202' or response.code == '400'
					break
				else
					# Let's wait a minute, and try again, because there could be some transient error...
					sleep(60)
				end
			end
			
			# Cleanups (if needed)
			# And then finish!
			exit 0
		else
			# This is the parent, which has to do nothing...
			retval = query.attributes['queryId']
		end
	end
	# No job, no party (retval == nil)!
	
	return retval
end

c = CGI.new
doc = nil
errstate = nil
httpcode = 202
acceptedList = []

# First, let's catch params
if c.params.has_key?('POSTDATA')
	begin
		doc = Document.new(c.params['POSTDATA'])
		el = doc.root
		if el.namespace == XCESC_NS and el.name == 'queries'
			if el.attributes.get_attribute('callback') == nil
				errstate = 'XML Document does not contain a callback!'
				httpcode = 400
			else
				callback = el.attributes['callback']
				
				el.elements.each { |query|
					if query.name == 'query' and query.namespace == XCESC_NS and query.attributes.get_attribute('queryId') != nil
						queryId = launchEvaluationJob(callback,query)
						if queryId != nil
							errstate = 'Accepted'
							acceptedList << queryId
						end
					end
				}
#				doc.writexml(writer=sys.stdout)
			end
		else
			errstate = 'XML Document is not a GOPHER queries one!'
			httpcode = 400
		end
	rescue
		errstate = 'Error while parsing the input GOPHER XML message'
		httpcode = 400
	end
else
	errstate = 'Empty Query Message'
	httpcode = 400
end


if errstate == nil
	errstate = 'No query has been accepted'
	httpcode = 400
end

if httpcode == 202
	acceptedDoc = Document.new()
	acceptedDoc << XMLDecl.new('1.0','UTF-8')
	acceptedQueries = Element.new('acceptedQueries')
	acceptedQueries.add_namespace(XCESC_NS)
	acceptedQueries.attributes['timeStamp'] = Time.now.iso8601
	acceptedDoc << acceptedQueries
	
	for queryId in acceptedList
		accepted = Element.new('accepted',acceptedQueries)
		accepted.attributes['queryId'] = queryId
	end
	
	puts c.header({
		'status' => "#{httpcode} #{errstate}",
		'type' => 'application/xml',
		'charset' => 'UTF-8'
	})
	acceptedDoc.write($stdout,0)
else
	puts c.header({
		'status' => "#{httpcode} #{errstate}"
	})
	puts "<html><head><title>#{httpcode} #{errstate}</title></head><body><div align='center'><h1>#{httpcode} #{errstate}</h1></div></body></html>"
end