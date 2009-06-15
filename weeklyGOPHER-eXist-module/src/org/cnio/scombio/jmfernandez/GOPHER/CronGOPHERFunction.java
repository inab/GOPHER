package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.net.URISyntaxException;
import java.net.URL;
import java.util.HashMap;

import org.cnio.scombio.jmfernandez.GOPHER.PDBSeq;
import org.exist.dom.BinaryDocument;
import org.exist.dom.DocumentImpl;
import org.exist.dom.QName;
import org.exist.memtree.MemTreeBuilder;
import org.exist.security.PermissionDeniedException;
import org.exist.storage.lock.Lock;
import org.exist.xmldb.XmldbURI;
import org.exist.xquery.BasicFunction;
import org.exist.xquery.Cardinality;
import org.exist.xquery.FunctionSignature;
import org.exist.xquery.XPathException;
import org.exist.xquery.XQueryContext;
import org.exist.xquery.value.NodeValue;
import org.exist.xquery.value.Sequence;
import org.exist.xquery.value.SequenceType;
import org.exist.xquery.value.Type;
import org.exist.xquery.value.ValueSequence;

public class CronGOPHERFunction
	extends BasicFunction
{
	private final static String XCESC_URI = "http://www.cnio.es/scombio/xcesc/1.0";

	private final static String COMPUTEUNIQUEENTRIES="compute-unique-entries";
	
	private final static String XCESC_PREFIX = "xcesc";
	private final static String XCESC_EXPERIMENT_ROOT="experiment";
	private final static String XCESC_TARGET_ELEMENT="target";
	
	private final static String XCESC_PUBLICID_ATTRIBUTE="publicId";
	private final static String XCESC_DESCRIPTION_ATTRIBUTE="description";
	private final static String XCESC_ORIGIN_ATTRIBUTE="origin";
	
	private final static String XCESC_QUERY_ELEMENT="query";
	private final static String XCESC_ID_ATTRIBUTE="queryId";
	
	public final static FunctionSignature signature[] = {
		new FunctionSignature(
				new QName(COMPUTEUNIQUEENTRIES, GOPHERModule.NAMESPACE_URI, GOPHERModule.PREFIX),
				"It computes the unique PDB and PrePDB entries, compared to latest run",
				new SequenceType[] {
					new SequenceType(Type.STRING, Cardinality.ONE),			// URI of the dynamic core (in a jar) to be called
					new SequenceType(Type.STRING, Cardinality.ONE),			// name of the static method to call in the dynamic core
					new SequenceType(Type.STRING, Cardinality.ONE),			// Original filtered PrePDB in database
					new SequenceType(Type.STRING, Cardinality.ONE),			// Original filtered PDB in database
					new SequenceType(Type.STRING, Cardinality.ONE),			// New unfiltered PrePDB in database
					new SequenceType(Type.STRING, Cardinality.ONE),			// New unfiltered PDB in database
					new SequenceType(Type.STRING, Cardinality.ONE),			// Filesystem Directory Scratch area
				},
				new SequenceType(Type.NODE, Cardinality.ONE)
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
		String gopherPrePDB=args[2].getStringValue();
		String gopherPDB=args[3].getStringValue();
		String PREPDB_PATH=args[4].getStringValue();
		String PDB_PATH=args[5].getStringValue();
		String scratchDirPath=args[6].getStringValue();
		
		File scratchDir=new File(scratchDirPath);
		scratchDir.mkdirs();
		if(scratchDir.isDirectory()) {
			File origPrePDBFile=new File(scratchDir,"prev-pdbpre.fas");
			File origPDBFile=new File(scratchDir,"prev-pdb.fas");
			fetchBinaryResource(gopherPrePDB,origPrePDBFile);
			fetchBinaryResource(gopherPDB,origPDBFile);
			
			File prePDBFile=new File(PREPDB_PATH);
			File PDBFile=new File(PDB_PATH);
			GOPHERClassLoader gcl = null;
			try {
				gcl = new GOPHERClassLoader(new URL(dynCoreJar));
				HashMap<String,PDBSeq> leaders = (HashMap<String,PDBSeq>)gcl.invokeClassMethod(dynCoreMethod, origPrePDBFile, prePDBFile, origPDBFile, PDBFile, scratchDir);
				
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
				throw new XPathException(this,"Invocation error while generating GOPHER query candidates using "+dynCoreMethod+" from "+dynCoreJar,ite);
			} catch(IOException ioe) {
				throw new XPathException(this,"I/O error while generating GOPHER query candidates",ioe);
			} catch (ClassCastException cce) {
				throw new XPathException(this,"ClassCastException while trying to generate GOPHER query candidates",cce);
			} catch (ClassNotFoundException cnfe) {
				throw new XPathException(this,"ClassNotFoundException while trying to generate GOPHER query candidates",cnfe);
			} catch (NoSuchMethodException nsme) {
				throw new XPathException(this,"NoSuchMethodException while trying to generate GOPHER query candidates",nsme);
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
