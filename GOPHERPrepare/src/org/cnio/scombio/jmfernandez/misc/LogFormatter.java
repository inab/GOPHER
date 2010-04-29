package org.cnio.scombio.jmfernandez.misc;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.logging.Formatter;
import java.util.logging.LogRecord;

public class LogFormatter
	extends Formatter
{
	protected final static SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ");
	protected Date date = new Date();

	public synchronized String format(LogRecord record) {
		// Minimize memory allocations here, as it is done inside SimpleFormatter
		date.setTime(record.getMillis());
		StringBuilder line=new StringBuilder(sdf.format(date)).append(" [").append(record.getLevel()).append("] ");
		String sourceClassName = record.getSourceClassName();
		int lastDot = sourceClassName.lastIndexOf('.');
		if(lastDot>0) {
			sourceClassName = sourceClassName.substring(lastDot+1);
		}
		line.append(sourceClassName).append('.').append(record.getSourceMethodName()).append(": ").append(record.getMessage());
		
		// Stack trace information
		Throwable t = record.getThrown();
		if(t != null) {
			StringWriter sw = null;
			PrintWriter pw = null;
			try {
				sw = new StringWriter();
				pw = new PrintWriter(sw);
				t.printStackTrace(pw);
				line.append(sw.getBuffer());
			} catch(Throwable t2) {
				// DoNothing(R)
			} finally {
				if(pw!=null)
					pw.close();
				if(sw!=null) {
					line.append("\n--- STACK TRACE BEGIN DUE ").append(t.getMessage()).append(" ---\n");
					line.append(sw.getBuffer());
					line.append("\n--- STACK TRACE END ---\n");
				}
			}
		} else {
			line.append('\n');
		}

		return line.toString();
	}
}
