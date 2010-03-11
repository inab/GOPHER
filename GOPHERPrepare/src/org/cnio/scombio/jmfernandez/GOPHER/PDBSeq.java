/**
 * 
 */
package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.HashMap;

/**
 * 
 * @author jmfernandez
 *
 */
public class PDBSeq {
	public final static String ORIGIN_KEY="origin";
	public final static String PATH_KEY="path";
	public final static String PREPROCESS_KEY="preprocess";
	
	public String id;
	public String iddesc;
	public StringBuilder sequence;
	public HashMap<String,Object> features;
	
	public PDBSeq(String id,String iddesc,StringBuilder sequence) {
		this.id=id;
		this.iddesc=iddesc;
		this.sequence=sequence;
		this.features=new HashMap<String,Object>();
	}
}
