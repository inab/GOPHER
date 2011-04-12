/**
 * 
 */
package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.Map;
import java.util.List;

import org.exist.xquery.AbstractInternalModule;
import org.exist.xquery.FunctionDef;

/**
 * @author jmfernandez
 *
 */
public class GOPHERModule
	extends AbstractInternalModule
{
	public final static String NAMESPACE_URI = "http://www.cnio.es/scombio/gopher/1.0/xquery/javaModule";
	
	public final static String PREFIX = "gmod";
	
	private static FunctionDef[] functions;
	
	static {
		functions=new FunctionDef[CronGOPHERFunction.signature.length];
		for(int i=0;i<CronGOPHERFunction.signature.length;i++) {
			functions[i]=new FunctionDef(CronGOPHERFunction.signature[i], CronGOPHERFunction.class);
		}
	};
	
	
	public GOPHERModule(Map<String, List<? extends Object>> parameters) {
		super(functions,parameters,true);
	}
	
	/* (non-Javadoc)
	 * @see org.exist.xquery.AbstractInternalModule#getDefaultPrefix()
	 */
	public String getDefaultPrefix() {
		return PREFIX;
	}

	/* (non-Javadoc)
	 * @see org.exist.xquery.AbstractInternalModule#getNamespaceURI()
	 */
	public String getNamespaceURI() {
		return NAMESPACE_URI;
	}

	/* (non-Javadoc)
	 * @see org.exist.xquery.Module#getDescription()
	 */
	public String getDescription() {
		return "GOPHER module which allows selecting unique PDB and PrePDB sequences for evaluation";
	}

	public String getReleaseVersion() {
		return "&ge; eXist-1.5";
	}

}
