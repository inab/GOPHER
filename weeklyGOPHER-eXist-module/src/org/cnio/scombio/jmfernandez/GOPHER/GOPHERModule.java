/**
 * 
 */
package org.cnio.scombio.jmfernandez.GOPHER;

import org.exist.xquery.AbstractInternalModule;
import org.exist.xquery.FunctionDef;

/**
 * @author jmfernandez
 *
 */
public class GOPHERModule
	extends AbstractInternalModule
{
	public final static String GOPHER_URI = "http://www.cnio.es/scombio/gopher/1.0";
	public final static String NAMESPACE_URI = GOPHER_URI+"/xquery/javaModule";
	
	public final static String PREFIX = "gmod";
	
	private static FunctionDef[] functions;
	
	static {
		functions=new FunctionDef[CronGOPHERFunction.signature.length];
		for(int i=0;i<CronGOPHERFunction.signature.length;i++) {
			functions[i]=new FunctionDef(CronGOPHERFunction.signature[i], CronGOPHERFunction.class);
		}
	};
	
	
	public GOPHERModule() {
		super(functions);
	}
	
	/* (non-Javadoc)
	 * @see org.exist.xquery.AbstractInternalModule#getDefaultPrefix()
	 */
	@Override
	public String getDefaultPrefix() {
		return PREFIX;
	}

	/* (non-Javadoc)
	 * @see org.exist.xquery.AbstractInternalModule#getNamespaceURI()
	 */
	@Override
	public String getNamespaceURI() {
		return NAMESPACE_URI;
	}

	/* (non-Javadoc)
	 * @see org.exist.xquery.Module#getDescription()
	 */
	public String getDescription() {
		return "GOPHER module which allows selecting unique PDB and PrePDB sequences for evaluation";
	}

}
