package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.Map;
import org.exist.scheduler.JobException;
import org.exist.scheduler.UserJavaJob;
import org.exist.storage.BrokerPool;

public class WeeklyGOPHERTask
	extends UserJavaJob
{
	private String jobName = this.getClass().getName();
	
	/**
	 * Function that is executed by the Scheduler
	 *
	 * @param brokerpool    The BrokerPool for the Scheduler of this job
	 * @param params        Any parameters passed to the job or null otherwise
	 *
	 * @throws JobException if there is a problem with the job.
	 * cleanupJob() should then be called, which will adjust the
	 * jobs scheduling appropriately
	 */
	public void execute(BrokerPool brokerpool, Map params)
		throws JobException
	{
	}
	
	public String getName() {
		return jobName;
	}
	
	public void setName(String name) {
		this.jobName = name;
	}
}