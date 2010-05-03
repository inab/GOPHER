package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.InputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.net.URL;
import java.nio.channels.FileChannel;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.logging.Logger;
import java.util.logging.StreamHandler;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.cnio.scombio.jmfernandez.GOPHER.PDBSeq;
import org.cnio.scombio.jmfernandez.misc.LogFormatter;

public class GOPHERPrepare {
	protected final static Logger LOG = Logger.getLogger(GOPHERPrepare.class.getName());
	static {
		LOG.setUseParentHandlers(false);
	};

	protected final static double CDHIT_IDENTITY=0.97;
	protected final static int CDHIT_WORD_SIZE=5;
	protected final static String BLAST_PATH="dc_blastall";
	protected final static String BLAST_ALGO="tera-blastp";
	protected final static String KNOWNSEQS_DB="fusionated";
	protected final static double BLAST_EVALUE=1e-5;
	protected final static int BLAST_HITS=500;
	
	protected final static String PDBPREFILE=PDBParser.PDBPRE_LABEL+".fas";
	protected final static String PDBFILE=PDBParser.PDB_LABEL+".fas";
	protected final static String ORIGPRE="prev-";
	protected final static String FILTPRE="filtered-";
	protected final static String SURVPRE="survivors-";
	protected final static String LEADERSPRE="leaders-";
	protected final static String ORIGDB="original.fas";
	protected final static String SURVDB="survivors.fas";
	protected final static String LEADERSDB="leaders.fas";
	protected final static String BLASTPOST=".blast";
	
	protected final static String ORIG_PDBPREFILE=ORIGPRE+PDBPREFILE;
	protected final static String ORIG_PDBFILE=ORIGPRE+PDBFILE;
		
	protected final static String queryParticle="Query=";
	
	protected final static String CIFDICT_LABEL="cifdict";
	
	public class StreamRedirector
		extends Thread
	{
		InputStream is;
		OutputStream os;
		PrintStream err;
		
		StreamRedirector(InputStream is, OutputStream os) {
			this(is,os,System.err);
		}
		
		StreamRedirector(InputStream is, OutputStream os, PrintStream err) {
			this.is = is;
			this.os = os;
			this.err=err;
		}

		public void run() {
			try {
				byte[] buffer=new byte[65536];
				int readed;
				
				while((readed=is.read(buffer,0,buffer.length))!=-1) {
					if(os!=null)
						os.write(buffer,0,readed);
				}
			} catch (IOException ioe) {
				if(err!=null)
					ioe.printStackTrace(err);
			}
		}
	}
	
	protected static Pattern PDBHEADERPAT=Pattern.compile("PDB:([^ :]+)[ :]");
	protected static Pattern blhitspat=Pattern.compile("\\([0-9]+ letters?\\)");
	
	File leadersdb;
	File leadersReport;
	Map<String,String> envp;
	Map<String,String> conf;
	CIFDict cifdict;
	PrintStream logStream;
	
	public GOPHERPrepare(Map<String,String> envp)
	{
		this(null,envp);
	}
	
	public GOPHERPrepare(PrintStream logStream, Map<String,String> envp)
	{
		this(logStream,envp,null);
	}
	
	public GOPHERPrepare(PrintStream logStream, Map<String,String> envp,Map<String,String> conf)
	{
		this.envp=envp;
		this.conf=conf;
		cifdict=null;
		leadersdb=null;
		leadersReport=null;
		
		// Set logging info just when needed
		this.logStream = logStream;
		if(logStream!=null)
			LOG.addHandler(new StreamHandler(logStream, new LogFormatter()));
	}
	
	public GOPHERPrepare()
	{
		this(null);
	}
	
	protected boolean filterUsingFASTAFile(File origFile,File newFile,File filtFile,File analFile)
		throws FileNotFoundException, IOException
	{
		boolean succeed=true;
		BufferedReader ORIG=new BufferedReader(new FileReader(origFile));
		List<String> origHeaders=null;
		try {
			origHeaders=PDBParser.ReadFASTAHeaders(ORIG);
			String[] orArr = origHeaders.toArray(new String[] {});
			Arrays.sort(orArr);
			origHeaders=Arrays.asList(orArr);
			// We don't need it any more
		} finally {
			ORIG.close();
		}
		
		if(newFile.isDirectory()) {
			PDBParser pdbParser = new PDBParser(cifdict,null);
			pdbParser.parsePDBs(newFile, origHeaders,null,filtFile,analFile,false);
		} else {
			List<String> newheaders=null;
			BufferedReader NEW = new BufferedReader(new FileReader(newFile));
			try {
				newheaders=PDBParser.ReadFASTAHeaders(NEW);
				// We don't need it any more
			} finally {
				NEW.close();
			}
			
			String[] newArr = newheaders.toArray(new String[] {});
			Arrays.sort(newArr);
			newheaders=Arrays.asList(newArr);
			
			// Now, let's find only new entries
			int maxorigpos=origHeaders.size();
			int maxnewpos=newheaders.size();
			int origpos=0;
			int newpos=0;
			HashMap<String,Object> candidate=new HashMap<String,Object>();
			while(origpos<maxorigpos && newpos<maxnewpos) {
				if(origHeaders.get(origpos).equals(newheaders.get(newpos))) {
					// Equal, next step!
					origpos++;
					newpos++;
				} else if(origHeaders.get(origpos).compareTo(newheaders.get(newpos))<0) {
					// Not skipped yet, next step on original!
					origpos++;
				} else {
					// Skipped, save and next step on new!
					candidate.put(newheaders.get(newpos),null);
					newpos++;
				}
			}
			
			// Now we know the candidate, let's save them
			PrintWriter FILT = new PrintWriter(filtFile);
			try {
				PrintWriter ANAL = new PrintWriter(analFile);
				try {
					// Let's analyze the sequences, getting the headers
					String line=null;
					String description=null;
					StringBuilder sequence=null;
					boolean survivor=false;
	
					// Reset file pointer for further usage
					boolean doLast=true;
					NEW = new BufferedReader(new FileReader(newFile));
					while((line=NEW.readLine())!=null || doLast) {
						if(line==null || (line.length()>0 && line.charAt(0)==PDBParser.FASTA_HEADER_PREFIX)) {
							// We have a candidate sequence!
							if(description!=null) {
								CharSequence cutseq=PDBChain.PruneSequence(cifdict.purifySequence(sequence.toString().toUpperCase(Locale.ROOT)));
	
								// Has passed the filters?
								if(cutseq!=null) {
									// Let's save it!
									FILT.println(description);
									FILT.println(cutseq);
									if(survivor) {
										ANAL.println(description);
										ANAL.println(cutseq);
									}
								}
							}
							
							if(line!=null) {
								// New header is it in the "chosen one" list?
								description=line;
								sequence=new StringBuilder();
								survivor=candidate.containsKey(line.substring(1));
							} else {
								doLast=false;
							}
						} else if(sequence!=null) {
							sequence.append(line.replace("\t",""));
						}
					}
				} finally {
					ANAL.close();
				}
			} finally {
				FILT.close();
			}
		}
		
		return succeed;
	}
	
	protected static String processFASTAPDBDesc(String desc) {
		// Now, store
		String id;
		Matcher m=PDBHEADERPAT.matcher(desc);
		if(m.find()) {
			id=m.group(1);
		} else {
			desc = desc.trim();
			String[] res = desc.split("[ \t]+",2);
			id=(res.length>0)?res[0]:desc;
		}

		return id;
	}
	
	protected static HashMap<String,PDBSeq> copyWithPrefix(File fastaFile,String prefix,PrintWriter FH)
		throws FileNotFoundException, IOException
	{
		HashMap<String,PDBSeq> seqs=new HashMap<String,PDBSeq>();
		BufferedReader FASTA = null;
		try {
			FASTA = new BufferedReader(new FileReader(fastaFile));
		} catch(IOException ioe) {
			throw new IOException("ERROR: Unable to open "+fastaFile.getAbsolutePath()+" to prefix it with "+prefix+"! Reason: "+ioe.getMessage());
		}
		String id=null;
		String iddesc=null;
		StringBuilder sequence=null;
		try {
			String line;
			while((line=FASTA.readLine())!=null) {
				if(line.charAt(0)==PDBParser.FASTA_HEADER_PREFIX) {
					if(id!=null)
						seqs.put(id,new PDBSeq(id,iddesc,sequence));
					String desc=line.substring(1);
					FH.println(PDBParser.FASTA_HEADER_PREFIX+prefix+PDBParser.PREF_SEP+desc);

					// Now, store
					id=processFASTAPDBDesc(desc);
					iddesc=desc;
					sequence=new StringBuilder();
				} else {
					FH.println(line);
					sequence.append(line);
				}
			}
		} finally {
			if(id!=null)
				seqs.put(id,new PDBSeq(id,iddesc,sequence));
			FASTA.close();
		}
		
		return seqs;
	}
	
	protected HashMap<String,PDBSeq> parseLeaders(HashMap<String,HashMap<String,PDBSeq>> survivors)
		throws FileNotFoundException, IOException
	{
		HashMap<String,PDBSeq> leaders=new HashMap<String,PDBSeq>();
		BufferedReader FH=new BufferedReader(new FileReader(leadersdb));
		try {
			String line;
			while((line=FH.readLine())!=null) {
				if(line.length() > 0 && line.charAt(0)==PDBParser.FASTA_HEADER_PREFIX) {
					String[] procHeader = line.split(PDBParser.PREF_SEP_STRING, 2);
					if(procHeader.length<2 || !survivors.containsKey(procHeader[0])) {
						throw new IOException("Garbled FASTA header at "+leadersdb.getAbsolutePath());
					}
					HashMap<String,PDBSeq> paq = survivors.get(procHeader[0]);
					String pdbCode=processFASTAPDBDesc(procHeader[1]);
					if(pdbCode==null || !paq.containsKey(pdbCode)) {
						throw new IOException("PDB Id "+pdbCode+" was not found! Perhaps the FASTA header was garbled");
					}
					PDBSeq leaderSeq=paq.get(pdbCode);
					leaderSeq.features.put(PDBSeq.ORIGIN_KEY, PDBParser.PDBPREFIX.equals(procHeader[0])?PDBParser.PDB_LABEL:PDBParser.PDBPRE_LABEL);
					leaders.put(leaderSeq.id,leaderSeq);
				}
			}
		} finally {
			FH.close();
		}
		
		return leaders;
	}
	
	protected HashMap<String,PDBSeq> chooseLeaders(File workdir, File origprepdb, File origpdb, File analprepdb, File analpdb)
		throws FileNotFoundException, IOException
	{
		// First, let's generate common original database
		File origdb=new File(workdir,ORIGDB);
		File survdb=new File(workdir,SURVDB);
		File leaderscanddb=new File(leadersdb.getAbsolutePath()+".candidate");

		// Second, let's concatenate all of them
		try {
			copyFile(origpdb,origdb);
		} catch(IOException ioe) {
			throw new IOException("ERROR: Unable to create file "+origdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
		}
		try {
			appendFile(origprepdb,origdb);
		} catch(IOException ioe) {
			throw new IOException("ERROR: Unable to concatenate to file "+origdb.getAbsolutePath()+" due "+ioe.getMessage());
		}

		PrintWriter SURVFH=null;
		
		try {
			SURVFH=new PrintWriter(survdb);
		} catch(IOException ioe) {
			throw new IOException("ERROR: Unable to create survivors database "+survdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
		}
		HashMap<String,PDBSeq> pdbArray=null;
		HashMap<String,PDBSeq> pdbPreArray=null;
		try {
			try {
				pdbArray=copyWithPrefix(analpdb,PDBParser.PDBPREFIX,SURVFH);
			} catch(IOException ioe) {
				throw new IOException("ERROR: Unable to concatenate "+analpdb.getAbsolutePath()+" to "+survdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			try {
				pdbPreArray=copyWithPrefix(analprepdb,PDBParser.PDBPREPREFIX,SURVFH);
			} catch(IOException ioe) {
				throw new IOException("ERROR: Unable to concatenate "+analprepdb.getAbsolutePath()+" to "+survdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
		} finally {
			SURVFH.close();
		}

		HashMap<String,HashMap<String,PDBSeq>> survivors=new HashMap<String,HashMap<String,PDBSeq>>();
		survivors.put(PDBParser.PDBPREFIX,pdbArray);
		survivors.put(PDBParser.PDBPREPREFIX,pdbPreArray);

		// Now, let's calculate needed memory for clustering
		int cdmem=(int)Math.round(((double)(origdb.length()+survdb.length()))/(1024L*1024L)*20+0.5);

		// And let's launch cd-hit-2d
		String[] CDHIT2Dparams={
			"cd-hit-2d",
			"-i",origdb.getAbsolutePath(),
			"-i2",survdb.getAbsolutePath(),
			"-o",leaderscanddb.getAbsolutePath(),
			"-c",Double.toString(CDHIT_IDENTITY),
			"-n",Integer.toString(CDHIT_WORD_SIZE),
			"-M",Integer.toString(cdmem)
		};
		
		LOG.info("NOTICE: Launching @CDHIT2Dparams");
		Process p = launchProgram(CDHIT2Dparams,envp,workdir,true);
		// No need to redirect error, because it is already redirected!
		StreamRedirector sro=new StreamRedirector(p.getInputStream(),logStream,logStream);
		sro.start();
		
		try {
			int retval = p.waitFor();
			// LOG.notice("RETVALS "+retval+" vs "+p.exitValue());
			if(retval!=0)
				throw new IOException("ERROR: system @CDHIT2Dparams failed: "+retval);
		} catch(InterruptedException ie) {
			throw new IOException("ERROR: system @CDHIT2Dparams failed due "+ie.getMessage());
		}
		
		String[] CDHITparams={
			"cd-hit",
			"-i",leaderscanddb.getAbsolutePath(),
			"-o",leadersdb.getAbsolutePath(),
			"-c",Double.toString(CDHIT_IDENTITY),
			"-n",Integer.toString(CDHIT_WORD_SIZE),
			"-M",Integer.toString(cdmem)
		};
		
		LOG.info("NOTICE: Launching @CDHITparams");
		p = launchProgram(CDHITparams,envp,workdir,true);
		sro=new StreamRedirector(p.getInputStream(),logStream,logStream);
		sro.start();
		try {
			int retval = p.waitFor();
			// LOG.notice("RETVALS "+retval+" vs "+p.exitValue());
			if(retval!=0)
				throw new IOException("ERROR: system @CDHITparams failed: "+retval);
		} catch(InterruptedException ie) {
			throw new IOException("ERROR: system @CDHITparams failed due "+ie.getMessage());
		}
		
		// Let's catch the leaders!
		HashMap<String,PDBSeq> leaders=parseLeaders(survivors);
		
		// And now, information about the leaders!
		String[] BLASTparams={
			BLAST_PATH,
			"-p",BLAST_ALGO,
			"-i",leadersdb.getAbsolutePath(),
			"-d",KNOWNSEQS_DB,
			"-e",Double.toString(BLAST_EVALUE),
			"-v",Integer.toString(BLAST_HITS),
			"-b",Integer.toString(BLAST_HITS)
		};

		LOG.info("NOTICE: Launching @BLASTparams");
		BufferedOutputStream lrs=null;
		try {
			lrs=new BufferedOutputStream(new FileOutputStream(leadersReport));
		} catch(IOException ioe) {
			throw new IOException("ERROR: unable to create BLAST report "+leadersReport.getAbsolutePath()+". Reason: "+ioe.getMessage());
		}
		p = launchProgram(BLASTparams,envp,workdir,false);
		try {
			sro=new StreamRedirector(p.getInputStream(),lrs,logStream);
			StreamRedirector sre=new StreamRedirector(p.getErrorStream(),logStream,logStream);
			sro.start();
			sre.start();
			try {
				int retval = p.waitFor();
				// LOG.notice("RETVALS "+retval+" vs "+p.exitValue());
				if(retval!=0)
					throw new IOException("ERROR: system @BLASTparams failed: "+retval);
			} catch(InterruptedException ie) {
				throw new IOException("ERROR: system @BLASTparams failed due "+ie.getMessage());
			}
		} finally {
			lrs.close();
		}
		
		// Let's parse!
		BufferedReader BLFH=null;
		try {
			BLFH=new BufferedReader(new FileReader(leadersReport));
		} catch(IOException ioe) {
			throw new IOException("ERROR: unable to parse BLAST report "+leadersReport.getAbsolutePath()+". Reason: "+ioe.getMessage());
		}
		
		try {
			String query=null;
			String line;
			boolean gettingQuery=false;
			while((line=BLFH.readLine())!=null) {
				if(line.indexOf(queryParticle)==0) {
					// First, let's save the obtained results

					// Second, new information

					query=line.substring(queryParticle.length());
					gettingQuery=true;
				} else if(gettingQuery) {
					if(blhitspat.matcher(line).find()) {
						gettingQuery=false;
					} else {
						query+=" "+line.substring(queryParticle.length());
					}
				} else if(line.indexOf("***** No hits found ******")!=-1) {
					LOG.fine("This one is really difficult! "+query);
					// We need to save here the information to generate the XML report
					query=null;
				} else if(line.indexOf("Sequences producing significant")==0) {
					LOG.fine("An easy one: "+query);
					// We need to save here the information to generate the XML report
					query=null;
				}
			}
		} finally {
			BLFH.close();
		}
		
		return leaders;
	}
	
	protected static void copyFile(File origFile,File newFile,boolean append)
		throws FileNotFoundException, IOException
	{
		FileChannel inChannel = null;
		FileChannel outChannel = null;
		
		try {
			inChannel = new FileInputStream(origFile).getChannel();
			outChannel = new FileOutputStream(newFile,append).getChannel();
			inChannel.transferTo(0, inChannel.size(),outChannel);
		} finally {
			if(inChannel != null)
				inChannel.close();
			if(outChannel != null)
				outChannel.close();
		}
	}
	
	protected static void fetchURL(URL origURL,File newFile,boolean append)
		throws FileNotFoundException, IOException
	{
		InputStream is = origURL.openStream();
		try {
			BufferedInputStream bis = new BufferedInputStream(is);
			byte[] buffer=new byte[65536];
			
			FileOutputStream fos = null;
			
			try {
				fos = new FileOutputStream(newFile,append);
				
				int readLength = -1;
				while((readLength=bis.read(buffer)) != -1) {
					fos.write(buffer,0,readLength);
				}
			} finally {
				try {
					fos.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
		} finally {
			try {
				is.close();
			} catch(IOException ioe) {
				// IgnoreIT(R)
			}
		}
	}

	protected Process launchProgram(String[] args,Map<String,String> addedEnv,File workdir,boolean redirectError)
		throws IOException
	{
		String[] pbargs=null;
		
		// Do we have to patch the arguments? What a shame!
		// And all this work because a chicken and egg problem!!
		if(addedEnv!=null && addedEnv.containsKey("PATH")) {
			pbargs=new String[] {"sh","-c",null};
			StringBuilder sb=new StringBuilder();
			
			boolean spaceSep=false;
			Pattern p = Pattern.compile("(?s)['\"$&><;{}()\\[\\]\t\n ]");
			for(String param:args) {
				if(spaceSep)
					sb.append(' ');
				else
					spaceSep=true;
				
				// Patch on these cases
				// NB: matches behaves like using ^ $
				if(p.matcher(param).find()) {
					// Surround the parameter with quotes
					sb.append("'").append(param.replaceAll("('+)", "'\"$1\"'")).append("'");
				} else {
					sb.append(param);
				}
			}
			
			// sb.append(" ; exit $?");
			
			pbargs[2]=sb.toString();
		} else {
			// Easy case :-)
			pbargs=args;
		}
		
		ProcessBuilder pb=new ProcessBuilder(pbargs);
		
		// Now, the environment variables
		String pathSep=System.getProperty("path.separator", ":");
		if(addedEnv!=null) {
			Map<String,String> ENV = pb.environment();
			for(Map.Entry<String, String> entry:addedEnv.entrySet()) {
				String key=entry.getKey();
				ENV.put(key, entry.getValue()+(ENV.containsKey(key)?(pathSep+ENV.get(key)):""));
			}
		}
		
		// The working directory
		if(workdir!=null)
			pb.directory(workdir);
		
		// And the redirection
		if(redirectError)
			pb.redirectErrorStream(true);
		
		return pb.start();
	}
	
	protected static void copyFile(File origFile,File newFile)
		throws FileNotFoundException, IOException
	{
		copyFile(origFile,newFile,false);
	}
	
	protected static void appendFile(File origFile,File newFile)
		throws FileNotFoundException, IOException
	{
		copyFile(origFile,newFile,true);
	}
	
	public HashMap<String,PDBSeq> doGOPHERPrepare(File origprepdb,File newprepdb,File origpdb,File newpdb,File workdir)
		throws IOException
	{
		return doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,false);
	}
	
	public HashMap<String,PDBSeq> doGOPHERPrepare(String origprepdb,String newprepdb,String origpdb,String newpdb,File workdir)
		throws IOException
	{
		return doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,false);
	}

	public HashMap<String,PDBSeq> doGOPHERPrepare(String origprepdb,String newprepdb,String origpdb,String newpdb,File workdir,boolean first)
		throws IOException
	{
		return doGOPHERPrepare(new File(workdir,origprepdb),new File(workdir,newprepdb),new File(workdir,origpdb),new File(workdir,newpdb),workdir,first);
	}
	
	public HashMap<String,PDBSeq> doGOPHERPrepare(File origprepdb,File newprepdb,File origpdb,File newpdb,File workdir,boolean first)
		throws IOException
	{
		// First, time to create working directory
		workdir.mkdirs();
		if(!workdir.isDirectory()) {
			throw new IOException("FATAL ERROR: Unable to create directory "+workdir.getAbsolutePath()+"!!!");
		}

		// Now, the CIFDict object
		if(conf!=null && conf.containsKey(CIFDICT_LABEL))
			cifdict = new CIFDict(new File(conf.get(CIFDICT_LABEL)));
		else
			throw new FileNotFoundException("Unable to find/parse CIFDict file, needed to parse inputs for the analysis");
		
		// Second, let's copy the original and new files there
		File Worigprepdb=new File(workdir,ORIG_PDBPREFILE);
		try {
			if(!Worigprepdb.equals(origprepdb))
				copyFile(origprepdb,Worigprepdb);
		} catch(IOException ioe) {
			throw new IOException("FATAL ERROR: Unable to copy "+origprepdb.getAbsolutePath()+" to "+Worigprepdb.getAbsolutePath()+" due "+ioe.getMessage()+". Reason:"+ioe.getMessage());
		}
		
		File Worigpdb=new File(workdir,ORIG_PDBFILE);
		try {
			// Special case
			if(first && origpdb.isDirectory()) {
				Worigpdb=origpdb;
			} else if(!Worigpdb.equals(origpdb)) {
				copyFile(origpdb,Worigpdb);
			}
		} catch(IOException ioe) {
			throw new IOException("FATAL ERROR: Unable to copy "+origpdb.getAbsolutePath()+" to "+Worigpdb.getAbsolutePath()+" due "+ioe.getMessage()+". Reason:"+ioe.getMessage());
		}

		File Wnewprepdb=new File(workdir,PDBPREFILE);
		try {
			if(!first && !Wnewprepdb.equals(newprepdb))
				copyFile(newprepdb,Wnewprepdb);
		} catch(IOException ioe) {
			throw new IOException("FATAL ERROR: Unable to copy "+newprepdb.getAbsolutePath()+" to "+Wnewprepdb.getAbsolutePath()+" due "+ioe.getMessage()+". Reason:"+ioe.getMessage());
		}
		
		File Wnewpdb=new File(workdir,PDBFILE);
		try {
			if(!first) {
				// Special case
				if(newpdb.isDirectory()) {
					Wnewpdb=newpdb;
				} else if(!Wnewpdb.equals(newpdb)) {
					copyFile(newpdb,Wnewpdb);
				}
			}
		} catch(IOException ioe) {
			throw new IOException("FATAL ERROR: Unable to copy "+newpdb.getAbsolutePath()+" to "+Wnewpdb.getAbsolutePath()+" due "+ioe.getMessage()+". Reason:"+ioe.getMessage());
		}

		// These ones are for the next week iteration
		File Wnewfiltprepdb=new File(workdir,FILTPRE+PDBPREFILE);
		File Wnewfiltpdb=new File(workdir,FILTPRE+PDBFILE);

		// And these ones are for now!
		File analprepdb=new File(workdir,SURVPRE+PDBPREFILE);
		File analpdb=new File(workdir,SURVPRE+PDBFILE);

		if(first) {
			// To run only the first time
			// Like 'touch' command
			Wnewfiltprepdb.createNewFile();
			Wnewfiltpdb.createNewFile();

			try {
				filterUsingFASTAFile(Wnewfiltprepdb,Worigprepdb,newprepdb,analprepdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analprepdb.getAbsolutePath()+" from "+Worigprepdb.getAbsolutePath()+" and "+Wnewprepdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			try {
				filterUsingFASTAFile(Wnewfiltpdb,Worigpdb,newpdb,analpdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analpdb.getAbsolutePath()+" from "+Worigpdb.getAbsolutePath()+" and "+Wnewpdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			
			return null;
		} else {
			// Third, easy filtering phase (new only, 30 residues or more after
			// prunning histidines heads and tails)
			try {
				filterUsingFASTAFile(Worigprepdb,Wnewprepdb,Wnewfiltprepdb,analprepdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analprepdb.getAbsolutePath()+" from "+Worigprepdb.getAbsolutePath()+" and "+Wnewprepdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			try {
				filterUsingFASTAFile(Worigpdb,Wnewpdb,Wnewfiltpdb,analpdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analpdb.getAbsolutePath()+" from "+Worigpdb.getAbsolutePath()+" and "+Wnewpdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}

			// Fourth, heuristics and difficult filtering phase
			leadersdb=new File(workdir,LEADERSDB);
			leadersReport=new File(workdir,LEADERSDB+BLASTPOST);
			return chooseLeaders(workdir,origprepdb,origpdb,analprepdb,analpdb);

			// File leadersprepdb=new File(workdir,LEADERSPRE+PDBPREFILE);
			// File leaderspdb=new File(workdir,LEADERSPRE+PDBFILE);

			// Fifth, other tools?????
		}
	}
	
	public static HashMap<String,PDBSeq> StaticDoGOPHERPrepare(File origprepdb,File newprepdb,File origpdb,File newpdb,File workdir,boolean first,File logfile,Map<String,String> envp,Map<String,String> config)
		throws IOException
	{
		PrintStream lps = (logfile!=null)?new PrintStream(logfile):System.err;
		try {
			GOPHERPrepare gp=new GOPHERPrepare(lps,envp,config);
			return gp.doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,first);
		} finally {
			if(logfile!=null)
				lps.close();
		}
	}
	
	/**
	 * No seed
	 * @param origprepdb
	 * @param newprepdb
	 * @param origpdb
	 * @param newpdb
	 * @param workdir
	 * @param logfile
	 * @param envp
	 * @return
	 * @throws IOException
	 */
	public static HashMap<String,PDBSeq> StaticDoGOPHERPrepare(File origprepdb,URL newprepdbURL,File origpdb,File newpdb,File workdir,File logfile,Map<String,String> envp,Map<String,String> config)
		throws IOException
	{
		PrintStream lps = (logfile!=null)?new PrintStream(logfile):System.err;
		File newprepdb = null;
		try {
			newprepdb = File.createTempFile("prepdb", ".fas");
			fetchURL(newprepdbURL, newprepdb, false);
			GOPHERPrepare gp=new GOPHERPrepare(lps,envp,config);
			return gp.doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,false);
		} finally {
			if(logfile!=null)
				lps.close();
			if(newprepdb!=null)
				newprepdb.delete();
		}
	}
	
	/**
	 * Seed generation
	 * @param origprepdbURL
	 * @param newprepdb
	 * @param origpdb
	 * @param newpdb
	 * @param workdir
	 * @param logfile
	 * @param envp
	 * @return
	 * @throws IOException
	 */
	public static HashMap<String,PDBSeq> StaticDoGOPHERPrepareSeed(URL origprepdbURL,File newprepdb,File origpdb,File newpdb,File workdir,File logfile,Map<String,String> envp,Map<String,String> config)
		throws IOException
	{
		PrintStream lps = (logfile!=null)?new PrintStream(logfile):System.err;
		File origprepdb = null;
		try {
			origprepdb = File.createTempFile("prepdb", ".fas");
			origprepdb.deleteOnExit();
			fetchURL(origprepdbURL, origprepdb, false);
			GOPHERPrepare gp=new GOPHERPrepare(lps,envp,config);
			return gp.doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,true);
		} finally {
			if(logfile!=null)
				lps.close();
			if(origprepdb!=null)
				origprepdb.delete();
		}
	}

	public final static void main(String[] args) {
		if(args.length==6 || (args.length>=7 && "-s".equals(args[0]))) {
			boolean first=args.length>6;
			// Shifting the array, so '-s' flag is not taken into account
			if(first) {
				System.arraycopy(args, 1, args, 0, args.length-1);
			}
			
			File origpdb=new File(args[2]);
			File newpdb=new File(args[3]);

			File workdir=new File(args[5]);
			
			try {
				Map<String,String> config=new HashMap<String,String>();
				config.put(CIFDICT_LABEL, args[4]);
				GOPHERPrepare gp=new GOPHERPrepare(null,null,config);
				
				String prepath=args[first?0:1];
				File tempfile=null;
				if(prepath.startsWith("http://") || prepath.startsWith("ftp://")) {
					tempfile = File.createTempFile("prepdb", ".fas");
					tempfile.deleteOnExit();
					fetchURL(new URL(prepath), tempfile, false);
				} else {
					tempfile=new File(prepath);
				}
				
				File origprepdb=first?tempfile:new File(args[0]);
				File newprepdb=first?new File(args[1]):tempfile;
				
				gp.doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,first);
				DoExit(0);
			} catch(IOException ioe) {
				System.err.println(ioe.getMessage());
				DoExit(1);
			}
		} else {
			System.err.println("FATAL ERROR: This program needs at least 6 params, in order:\n"
+"*	The filtered, previous week, PDBPre database file in FASTA format.\n"
+"*	The unfiltered, current week, PDBPre database file or URL in FASTA format.\n"
+"*	The filtered, previous week, PDB database file in FASTA format.\n"
+"*	The unfiltered, current week, wwPDB directory filled with (compressed) PDB files.\n"
+"*	The path to the CIF dictionary.\n"
+"*	The working directory where to store all the results and intermediate files.\n"
+"\n"
+"	When the '-s' flag is used as first param, the meaning of the following ones change:\n"
+"\n"
+"*	The unfiltered, current week, PDBPre database file or URL in FASTA format.\n"
+"*	The filtered, current week, PDBPre database file in FASTA format (to be generated).\n"
+"*	The unfiltered, current week, wwPDB directory filled with (compressed) PDB files.\n"
+"*	The filtered, current week, PDB database file in FASTA format (to be generated).\n"
+"*	The path to the CIF dictionary.\n"
+"*	The working directory where to store all the intermediate files.");
			DoExit(1);
		}
	}
	
	protected final static void DoExit(int status) {
		System.exit(status);
	}
}
