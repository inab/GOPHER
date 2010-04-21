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
	
	public final String id;
	public final String iddesc;
	public final CharSequence sequence;
	public final HashMap<String,Object> features;
	
	public PDBSeq(final String id,final String iddesc,final CharSequence sequence) {
		this.id=id;
		this.iddesc=iddesc;
		this.sequence=sequence;
		this.features=new HashMap<String,Object>();
	}
}
