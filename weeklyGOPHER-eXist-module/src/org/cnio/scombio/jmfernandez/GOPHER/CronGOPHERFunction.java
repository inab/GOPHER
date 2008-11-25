package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.util.HashMap;

import org.cnio.scombio.jmfernandez.GOPHER.GOPHERPrepare.PDBSeq;
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
import org.exist.xquery.value.Sequence;
import org.exist.xquery.value.SequenceType;
import org.exist.xquery.value.Type;

public class CronGOPHERFunction
	extends BasicFunction
{
	private final static String COMPUTEUNIQUEENTRIES="compute-unique-entries";
	
	private final static String GOPHER_PREFIX = "gopher";
	private final static String GOPHER_EXPERIMENT_ROOT="experiment";
	private final static String GOPHER_TARGET_ELEMENT="target";
	
	private final static String GOPHER_PUBLICID_ATTRIBUTE="publicId";
	private final static String GOPHER_DESCRIPTION_ATTRIBUTE="description";
	private final static String GOPHER_ORIGIN_ATTRIBUTE="origin";
	
	private final static String GOPHER_QUERY_ELEMENT="query";
	private final static String GOPHER_ID_ATTRIBUTE="id";
	
	private final static String PREPDB_PATH="/drives/databases/FastaDB/pdbpre";
	private final static String PDB_PATH="/drives/databases/FastaDB/pdb";
	
	public final static FunctionSignature signature[] = {
		new FunctionSignature(
				new QName(COMPUTEUNIQUEENTRIES, GOPHERModule.NAMESPACE_URI, GOPHERModule.PREFIX),
				"It computes the unique PDB and PrePDB entries, compared to latest run",
				new SequenceType[] {
					new SequenceType(Type.STRING, Cardinality.ONE),			// Original filtered PrePDB in database
					new SequenceType(Type.STRING, Cardinality.ONE),			// Original filtered PDB in database
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
		QNAME_TARGET = new QName(GOPHER_TARGET_ELEMENT,GOPHERModule.GOPHER_URI,GOPHER_PREFIX);
		QNAME_PUBLICID = new QName(GOPHER_PUBLICID_ATTRIBUTE);
		QNAME_DESCRIPTION = new QName(GOPHER_DESCRIPTION_ATTRIBUTE);
		QNAME_ORIGIN = new QName(GOPHER_ORIGIN_ATTRIBUTE);
		QNAME_QUERY = new QName(GOPHER_QUERY_ELEMENT,GOPHERModule.GOPHER_URI,GOPHER_PREFIX);
		QNAME_ID = new QName(GOPHER_ID_ATTRIBUTE);
	};
	
	public CronGOPHERFunction(XQueryContext context, FunctionSignature signature) {
		super(context, signature);
	}

	@Override
	public Sequence eval(Sequence[] args, Sequence contextSequence)
		throws XPathException
	{
		MemTreeBuilder mtb=new MemTreeBuilder(context);
		// Let's start building the document
		mtb.startDocument();
		QName QNAME_ROOT=new QName(GOPHER_EXPERIMENT_ROOT,GOPHERModule.GOPHER_URI,GOPHER_PREFIX);
		// Root element
		mtb.startElement(QNAME_ROOT,null);
		
		// Let's calculate everything!
		String gopherPrePDB=args[0].getStringValue();
		String gopherPDB=args[1].getStringValue();
		String scratchDirPath=args[2].getStringValue();
		File scratchDir=new File(scratchDirPath);
		scratchDir.mkdirs();
		if(scratchDir.isDirectory()) {
			File origPrePDBFile=new File(scratchDir,GOPHERPrepare.ORIG_PDBPREFILE);
			File origPDBFile=new File(scratchDir,GOPHERPrepare.ORIG_PDBFILE);
			fetchBinaryResource(gopherPrePDB,origPrePDBFile);
			fetchBinaryResource(gopherPDB,origPDBFile);
			
			File prePDBFile=new File(PREPDB_PATH);
			File PDBFile=new File(PDB_PATH);
			GOPHERPrepare gp=new GOPHERPrepare();
			try {
				HashMap<String,PDBSeq> leaders = gp.doGOPHERPrepare(origPrePDBFile, prePDBFile, origPDBFile, PDBFile, scratchDir);
				
				//And now, let's create the in memory document!!!
				int leadPos=0;
				for(PDBSeq pdb: leaders.values()) {
					// Start target element
					mtb.startElement(QNAME_TARGET,null);
					
					// The publicId
					mtb.addAttribute(QNAME_PUBLICID, pdb.id);
					// The FASTA Headers
					mtb.addAttribute(QNAME_DESCRIPTION, pdb.iddesc);
					// The FASTA origin
					mtb.addAttribute(QNAME_ORIGIN, pdb.features.containsKey(GOPHERPrepare.ORIGIN_KEY)?(String)pdb.features.get(GOPHERPrepare.ORIGIN_KEY):"");
					
					mtb.startElement(QNAME_QUERY,null);
					leadPos++;
					mtb.addAttribute(QNAME_ID, Integer.toString(leadPos));
					mtb.cdataSection(pdb.sequence);
					mtb.endElement();
					
					// End target element
					mtb.endElement();
				}
			} catch(IOException ioe) {
				throw new XPathException(getASTNode(),"I/O error while generating GOPHER query candidates",ioe);
			}
		} else {
			throw new XPathException(getASTNode(),"Unable to use filesystem scratch area!!!");
		}
		
		// End root element
		mtb.endElement();
		// The end
		mtb.endDocument();
		
		// And now, let's return!
		return mtb.getDocument();
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
				throw new XPathException(getASTNode(), thedocpath + ": unable to find resource");
			} else if(prePDBdoc.getResourceType()!=DocumentImpl.BINARY_FILE) {
				throw new XPathException(getASTNode(), thedocpath + ": is not a binary resource");
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
			throw new XPathException(getASTNode(), "Invalid resource uri",usy);
		} catch(PermissionDeniedException pde) {
			throw new XPathException(getASTNode(), thedocpath + ": permission denied to read resource");
		} catch(IOException ioe) {
			throw new XPathException(getASTNode(),thedocpath + ": I/O error while reading resource",ioe);
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
