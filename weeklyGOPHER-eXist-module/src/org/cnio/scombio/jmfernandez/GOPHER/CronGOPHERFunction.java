package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.InvocationTargetException;
import java.net.MalformedURLException;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

import org.cnio.scombio.jmfernandez.GOPHER.PDBSeq;
import org.exist.dom.persistent.BinaryDocument;
import org.exist.dom.persistent.DocumentImpl;
import org.exist.dom.QName;
import org.exist.dom.memtree.MemTreeBuilder;
import org.exist.security.PermissionDeniedException;
import org.exist.storage.lock.Lock;
import org.exist.xmldb.XmldbURI;
import org.exist.xquery.BasicFunction;
import org.exist.xquery.Cardinality;
import org.exist.xquery.FunctionSignature;
import org.exist.xquery.XPathException;
import org.exist.xquery.XQueryContext;
import org.exist.xquery.value.FunctionParameterSequenceType;
import org.exist.xquery.value.FunctionReturnSequenceType;
import org.exist.xquery.value.NodeValue;
import org.exist.xquery.value.Sequence;
import org.exist.xquery.value.SequenceType;
import org.exist.xquery.value.Type;
import org.exist.xquery.value.ValueSequence;
import org.w3c.dom.Element;
import org.w3c.dom.Node;

public class CronGOPHERFunction
	extends BasicFunction
{
	private final static String XCESC_URI = "http://www.cnio.es/scombio/xcesc/1.0";

	private final static String COMPUTEUNIQUEENTRIES="compute-unique-entries";
	private final static String GENERATESEED="generate-seed";
	
	private final static String XCESC_PREFIX = "xcesc";
	private final static String XCESC_EXPERIMENT_ROOT="experiment";
	private final static String XCESC_TARGET_ELEMENT="target";
	
	private final static String XCESC_PUBLICID_ATTRIBUTE="id";
	private final static String XCESC_DESCRIPTION_ATTRIBUTE="description";
	private final static String XCESC_ORIGIN_ATTRIBUTE="kind";
	
	private final static String XCESC_QUERY_ELEMENT="query";
	private final static String XCESC_ID_ATTRIBUTE="queryId";
	
	private final static SequenceType[] FUNC_SIGNATURE=new SequenceType[] {
		new FunctionParameterSequenceType("dynCoreJar",Type.STRING, Cardinality.ONE,"URI of the dynamic core (in a jar) to be called"),			// URI of the dynamic core (in a jar) to be called
		new FunctionParameterSequenceType("dynCoreMethod",Type.STRING, Cardinality.ONE,"Name of the static method to call in the dynamic core"),			// name of the static method to call in the dynamic core
		new FunctionParameterSequenceType("prevFilteredPrePDB",Type.STRING, Cardinality.ONE,"Original filtered FASTA PrePDB in database"),			// Original filtered PrePDB in database
		new FunctionParameterSequenceType("prevFilteredwwPDB",Type.STRING, Cardinality.ONE,"Original filtered FASTA wwPDB in database"),			// Original filtered PDB in database
		new FunctionParameterSequenceType("prepdbURI",Type.ANY_URI, Cardinality.ONE,"New unfiltered PrePDB URI"),			// New unfiltered PrePDB in database
		new FunctionParameterSequenceType("pdbPath", Type.STRING, Cardinality.ONE,"New unfiltered wwPDB directory in filesystem"),			// New unfiltered PDB in database
		new FunctionParameterSequenceType("scratchDir",Type.STRING, Cardinality.ZERO_OR_ONE,"Filesystem Directory Scratch area (i.e. TEMP)"),			// Filesystem Directory Scratch area
		new FunctionParameterSequenceType("env",Type.ELEMENT, Cardinality.ZERO_OR_MORE,"Environment variables to use, in the form <env key='' value=''/>"),		// Environment variables to use
		new FunctionParameterSequenceType("config",Type.ELEMENT, Cardinality.ZERO_OR_MORE,"Configuration parameters to pass to the core, in the form <conf key='' value=''/>"),		// Environment variables to use
	};
	
	private final static SequenceType[] FUNC_SIGNATURE_SEED=new SequenceType[] {
		new FunctionParameterSequenceType("dynCoreJar",Type.STRING, Cardinality.ONE,"URI of the dynamic core (in a jar) to be called"),			// URI of the dynamic core (in a jar) to be called
		new FunctionParameterSequenceType("dynCoreMethod",Type.STRING, Cardinality.ONE,"Name of the static method to call in the dynamic core"),			// name of the static method to call in the dynamic core
		new FunctionParameterSequenceType("prepdbURI",Type.ANY_URI, Cardinality.ONE,"New unfiltered PrePDB URI"),			// Original unfiltered PrePDB in database
		new FunctionParameterSequenceType("pdbPath",Type.STRING, Cardinality.ONE,"New unfiltered wwPDB directory in filesystem"),			// Original unfiltered PDB in database
		new FunctionParameterSequenceType("newFilteredPrePDBFile",Type.STRING, Cardinality.ONE,"New filtered FASTA PrePDB in filesystem"),			// New filtered PrePDB in database
		new FunctionParameterSequenceType("newFilteredwwPDBFile",Type.STRING, Cardinality.ONE,"New filtered FASTA wwPDB in filesystem"),			// New filtered PDB in database
		new FunctionParameterSequenceType("scratchDir",Type.STRING, Cardinality.ZERO_OR_ONE,"Filesystem Directory Scratch area (i.e. TEMP)"),			// Filesystem Directory Scratch area
		new FunctionParameterSequenceType("env",Type.ELEMENT, Cardinality.ZERO_OR_MORE,"Environment variables to use, in the form <env key='' value=''/>"),		// Environment variables to use
		new FunctionParameterSequenceType("config",Type.ELEMENT, Cardinality.ZERO_OR_MORE,"Configuration parameters to pass to the core, in the form <conf key='' value=''/>"),		// Environment variables to use
	};
	
	public final static FunctionSignature signature[] = {
		new FunctionSignature(
			new QName(COMPUTEUNIQUEENTRIES, GOPHERModule.NAMESPACE_URI, GOPHERModule.PREFIX),
			"It computes the unique PDB and PrePDB entries, compared to latest run. Parameters are:\n" +
			"* URI of the dynamic core (in a jar) to be called\n" +
			"* name of the static method to call in the dynamic core\n" +
			"* Original filtered PrePDB in database\n" +
			"* Original filtered PDB in database\n" +
			"* New unfiltered PrePDB in database\n" +
			"* New unfiltered PDB in database\n" +
			"* Filesystem Directory Scratch area\n" +
			"* Environment variables to use, as a set of elements like <env key='PATH' value='/usr/bin' />\n" +
			"\n" +
			"It returns xcesc:experiment elements (see xcesc.xsd for further details and descriptions).",
			FUNC_SIGNATURE,
			new FunctionReturnSequenceType(Type.ELEMENT, Cardinality.ONE,"xcesc:experiment element (see xcesc.xsd for further details and descriptions)")
		),
		new FunctionSignature(
			new QName(GENERATESEED, GOPHERModule.NAMESPACE_URI, GOPHERModule.PREFIX),
			"It computes the unique PDB and PrePDB entries seed. Parameters are:\n" +
			"* URI of the dynamic core (in a jar) to be called\n" +
			"* name of the static method to call in the dynamic core\n" +
			"* Original unfiltered PrePDB in filesystem\n" +
			"* Original unfiltered PDB in filesystem\n" +
			"* New filtered PrePDB in filesystem\n" +
			"* New filtered PDB in filesystem\n" +
			"* Filesystem Directory Scratch area\n" +
			"* Environment variables to use, as a set of elements like <env key='PATH' value='/usr/bin' />\n" +
			"\n" +
			"It returns xcesc:experiment elements (see xcesc.xsd for further details and descriptions).",
			FUNC_SIGNATURE_SEED,
			new FunctionReturnSequenceType(Type.ELEMENT, Cardinality.ONE,"xcesc:experiment element (see xcesc.xsd for further details and descriptions).")
		),
	};
	
	protected final static QName QNAME_TARGET;
	protected final static QName QNAME_PUBLICID;
	protected final static QName QNAME_DESCRIPTION;
	protected final static QName QNAME_ORIGIN;
	protected final static QName QNAME_QUERY;
	protected final static QName QNAME_ID;
	
	static {
		// As these are mostly constants
		QNAME_TARGET = new QName(XCESC_TARGET_ELEMENT,XCESC_URI,XCESC_PREFIX);
		QNAME_PUBLICID = new QName(XCESC_PUBLICID_ATTRIBUTE);
		QNAME_DESCRIPTION = new QName(XCESC_DESCRIPTION_ATTRIBUTE);
		QNAME_ORIGIN = new QName(XCESC_ORIGIN_ATTRIBUTE);
		QNAME_QUERY = new QName(XCESC_QUERY_ELEMENT,XCESC_URI,XCESC_PREFIX);
		QNAME_ID = new QName(XCESC_ID_ATTRIBUTE);
	};
	
	public CronGOPHERFunction(XQueryContext context, FunctionSignature signature) {
		super(context, signature);
	}

	@Override
	public Sequence eval(Sequence[] args, Sequence contextSequence)
		throws XPathException
	{	
		// Let's calculate everything!
		String dynCoreJar=args[0].getStringValue();
		String dynCoreMethod=args[1].getStringValue();
		
		String gopherPrePDB=null;
		String gopherPDB=null;
		URL PREPDB_URI=null;
		String PDB_PATH=null;
		boolean genSeed=isCalledAs(GENERATESEED);
		if(genSeed) {
			try {
				PREPDB_URI=new URL(args[2].getStringValue());
			} catch(MalformedURLException mue) {
				throw new XPathException(this,"Malformed URL while generating GOPHER query candidates",mue);
			}
			PDB_PATH=args[3].getStringValue();
			gopherPrePDB=args[4].getStringValue();
			gopherPDB=args[5].getStringValue();
		} else {
			gopherPrePDB=args[2].getStringValue();
			gopherPDB=args[3].getStringValue();
			try {
				PREPDB_URI=new URL(args[4].getStringValue());
			} catch(MalformedURLException mue) {
				throw new XPathException(this,"Malformed URL while generating GOPHER query candidates",mue);
			}
			PDB_PATH=args[5].getStringValue();
		}
		
		// The scratch area always must exist!!!! 
		String scratchDirPath=args[6].getItemCount()>0?args[6].getStringValue():System.getProperty("java.io.tmpdir", "/tmp");
		
		File scratchDir=new File(scratchDirPath);
		scratchDir.mkdirs();
		if(scratchDir.isDirectory()) {
			File origPrePDBFile=null;
			File origPDBFile=null;
			File prePDBFile=null;
			File PDBFile=null;
			
			if(genSeed) {
				// origPrePDBFile=new File(PREPDB_PATH);
				origPDBFile=new File(PDB_PATH);
				
				prePDBFile=new File(scratchDir,gopherPrePDB);
				PDBFile=new File(scratchDir,gopherPDB);
			} else {
				origPrePDBFile=new File(scratchDir,"prev-pdbpre.fas");
				origPDBFile=new File(scratchDir,"prev-pdb.fas");
				fetchBinaryResource(gopherPrePDB,origPrePDBFile);
				fetchBinaryResource(gopherPDB,origPDBFile);
				
				// prePDBFile=new File(PREPDB_PATH);
				PDBFile=new File(PDB_PATH);
			}
			
			GOPHERClassLoader gcl = null;
			try {
				Map<String,String> envl=genEnvP(args[7]);
				Map<String,String> config=genConfigP(args[8]);
				
				gcl = new GOPHERClassLoader(new URL[] {new URL(dynCoreJar)},PDBSeq.class.getClassLoader());
				
				HashMap<String,PDBSeq> leaders = new HashMap<String,PDBSeq>();
				leaders = gcl.invokeClassMethod(
						dynCoreMethod,
						leaders.getClass(),
						new Class<?>[] {
							genSeed?URL.class:File.class,
							genSeed?File.class:URL.class,
							File.class,
							File.class,
							File.class,
							boolean.class,
							File.class,
							envl.getClass(),
							config.getClass()
						},
						genSeed?PREPDB_URI:origPrePDBFile,
						genSeed?prePDBFile:PREPDB_URI,
						origPDBFile,
						PDBFile,
						scratchDir,
						genSeed,
						(File)null,
						envl,
						config
					);
				
				//And now, let's create the in memory document!!!
				context.pushDocumentContext();
				try {
					MemTreeBuilder mtb=context.getDocumentBuilder();
					// Let's start building the document
					mtb.startDocument();
					QName QNAME_ROOT=new QName(XCESC_EXPERIMENT_ROOT,XCESC_URI,XCESC_PREFIX);
					// Root element
					mtb.startElement(QNAME_ROOT,null);

					int leadPos=0;
					for(PDBSeq pdb: leaders.values()) {
						// Start target element
						mtb.startElement(QNAME_TARGET,null);

						// The publicId
						mtb.addAttribute(QNAME_PUBLICID, pdb.id);
						// The FASTA Headers
						mtb.addAttribute(QNAME_DESCRIPTION, pdb.iddesc);
						// The FASTA origin
						mtb.addAttribute(QNAME_ORIGIN, pdb.features.containsKey(PDBSeq.ORIGIN_KEY)?(String)pdb.features.get(PDBSeq.ORIGIN_KEY):"");

						mtb.startElement(QNAME_QUERY,null);
						leadPos++;
						mtb.addAttribute(QNAME_ID, Integer.toString(leadPos));
						mtb.cdataSection(pdb.sequence);
						mtb.endElement();

						// End target element
						mtb.endElement();
					}

					// End root element
					mtb.endElement();
					// The end
					mtb.endDocument();
					ValueSequence seq=new ValueSequence();
					seq.add((NodeValue)mtb.getDocument().getFirstChild());
					return seq;
				} finally {
					context.popDocumentContext();
				}
			} catch(InvocationTargetException ite) {
				Throwable t=ite.getCause();
				if(t==null)
					t=ite;
				// For error (to be commented)
				t.printStackTrace();
				// For the message (so it is no hidden)
				StringWriter sw = new StringWriter();
				PrintWriter pw=new PrintWriter(sw);
				t.printStackTrace(pw);
				throw new XPathException(this,"Invocation error while generating GOPHER query candidates using "+dynCoreMethod+" from "+dynCoreJar+"\nDetails:\n"+sw.getBuffer(),t);
			} catch(IOException ioe) {
				throw new XPathException(this,"I/O error while generating GOPHER query candidates",ioe);
			} catch (ClassCastException cce) {
				throw new XPathException(this,"ClassCastException while trying to generate GOPHER query candidates",cce);
			} catch (ClassNotFoundException cnfe) {
				throw new XPathException(this,"ClassNotFoundException while trying to generate GOPHER query candidates",cnfe);
			} catch (NoSuchMethodException nsme) {
				throw new XPathException(this,"NoSuchMethodException while trying to generate GOPHER query candidates using "+dynCoreMethod,nsme);
			} finally {
				gcl = null;
				System.runFinalization();
				System.gc();
			}
		} else {
			throw new XPathException(this,"Unable to use filesystem scratch area!!!");
		}
		
		// And now, we should return!
		// return Sequence.EMPTY_SEQUENCE;
	}
	
	protected Map<String,String> genEnvP(Sequence addedEnv) {
		// First, let's gather the variables, classifying them
		// onto new or already
		
		return genKeyVal("env",addedEnv);
	}
	
	protected Map<String,String> genConfigP(Sequence addedEnv) {
		// First, let's gather the variables, classifying them
		// onto new or already
		
		return genKeyVal("config",addedEnv);
	}
	
	/**
	 * Key/value parser
	 * @param parent The name of the parent element which contains the key/value pairs
	 * @param added The parent element to validate and then process
	 * @return
	 */
	protected Map<String,String> genKeyVal(final String parent,Sequence added) {
		// First, let's gather the variables, classifying them
		// onto new or already
		HashMap<String,String> newVars=new HashMap<String,String>();
		
		for(int envi=0;envi<added.getItemCount();envi++) {
			Node node = ((NodeValue)added.itemAt(envi)).getNode();
			if(node.getNodeType()==Node.ELEMENT_NODE && parent.equals(node.getLocalName())) {
				Element elem=(Element)node;
				String key=elem.getAttribute("key");
				String value=elem.getAttribute("value");
				if(key!=null && value!=null && !"".equals(key)) {
					newVars.put(key, value);
				}
			}
		}
		
		return newVars;
	}
	
	protected void fetchBinaryResource(String thedocpath,File localFile)
		throws XPathException
	{
		DocumentImpl prePDBdoc=null;
		FileOutputStream fos = null;
		BufferedOutputStream bos = null;
		InputStream is = null;
		try {
			prePDBdoc = context.getBroker().getXMLResource(XmldbURI.xmldbUriFor(thedocpath), Lock.READ_LOCK);
			if(prePDBdoc==null) {
				throw new XPathException(this, thedocpath + ": unable to find resource");
			} else if(prePDBdoc.getResourceType()!=DocumentImpl.BINARY_FILE) {
				throw new XPathException(this, thedocpath + ": is not a binary resource");
			}
			BinaryDocument bin = (BinaryDocument) prePDBdoc;
			is = context.getBroker().getBinaryResource(bin);
			fos = new FileOutputStream(localFile);
			bos = new BufferedOutputStream(fos);
			byte[] buffer=new byte[655360];
			int readed;
			while((readed=is.read(buffer))!=-1) {
				bos.write(buffer, 0, readed);
			}
		} catch(URISyntaxException usy) {
			throw new XPathException(this, "Invalid resource uri",usy);
		} catch(PermissionDeniedException pde) {
			throw new XPathException(this, thedocpath + ": permission denied to read resource");
		} catch(IOException ioe) {
			throw new XPathException(this, thedocpath + ": I/O error while reading resource",ioe);
		} finally {
			if(prePDBdoc!=null) {
				prePDBdoc.getUpdateLock().release(Lock.READ_LOCK);
				prePDBdoc=null;
			}
			if(bos!=null) {
				try {
					bos.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
				bos=null;
			}
			if(fos!=null) {
				try {
					fos.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
				fos=null;
			}
			if(is!=null) {
				try {
					is.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
				is=null;
			}
		}
	}
}
