package org.cnio.scombio.jmfernandez.GOPHER;

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
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.cnio.scombio.jmfernandez.GOPHER.PDBSeq;

public class GOPHERPrepare {
	protected final static int MINSEQLENGTH=30;
	protected final static int HAREA=20;
	protected final static int HMIN=3;
	protected final static double CDHIT_IDENTITY=0.97;
	protected final static int CDHIT_WORD_SIZE=5;
	protected final static String BLAST_PATH="dc_blastall";
	protected final static String BLAST_ALGO="tera-blastp";
	protected final static String KNOWNSEQS_DB="fusionated";
	protected final static double BLAST_EVALUE=1e-5;
	protected final static int BLAST_HITS=500;
	
	protected final static String PDBPRE_LABEL="pdbpre";
	protected final static String PDBPREFILE=PDBPRE_LABEL+".fas";
	protected final static String PDB_LABEL="pdb";
	protected final static String PDBFILE=PDB_LABEL+".fas";
	protected final static String ORIGPRE="prev-";
	protected final static String FILTPRE="filtered-";
	protected final static String SURVPRE="survivors-";
	protected final static String LEADERSPRE="leaders-";
	protected final static String ORIGDB="original.fas";
	protected final static String SURVDB="survivors.fas";
	protected final static String LEADERSDB="leaders.fas";
	protected final static String PDBPREPREFIX="N";
	protected final static String PDBPREFIX="P";
	protected final static String PREF_SEP=":";
	protected final static String BLASTPOST=".blast";
	
	protected final static String ORIG_PDBPREFILE=ORIGPRE+PDBPREFILE;
	protected final static String ORIG_PDBFILE=ORIGPRE+PDBFILE;
	
	protected static String queryParticle="Query=";
	
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
					os.write(buffer,0,readed);
				}
			} catch (IOException ioe) {
				if(err!=null)
					ioe.printStackTrace(err);
			}
		}
	}
	
	protected Pattern hdpattern;
	protected Pattern hxpattern;
	protected Pattern PDBHEADERPAT;
	protected Pattern blhitspat;
	protected PrintStream logStream;
	
	File leadersdb;
	File leadersReport;
	
	public GOPHERPrepare(PrintStream logStream)
	{
		hdpattern=Pattern.compile("[HX]{"+HMIN+",}");
		hxpattern=Pattern.compile("^[HX]+");
		PDBHEADERPAT=Pattern.compile("PDB:([^ :]+)[ :]");
		blhitspat=Pattern.compile("\\([0-9]+ letters?\\)");
		this.logStream=logStream;
		leadersdb=null;
		leadersReport=null;
	}
	
	public GOPHERPrepare()
	{
		this(System.err);
	}
	
	protected ArrayList<String> readFASTAHeaders(BufferedReader FH)
		throws IOException
	{
		ArrayList<String> headers=new ArrayList<String>();
		
		String line;
		while((line=FH.readLine())!=null) {
			if(line.length() > 0 && line.charAt(0)=='>') {
				headers.add(line.substring(1));
			}
		}
		
		return headers;
	}
	
	/**
		This method takes a one-line sequence, and it removes
		histidine heads and/or tails. Optional second parameter
		drives the behavior (0 or negative is head, 1 is tail, 2 is both).
	*/
	protected String pruneSequence(String cutseq) {
		return pruneSequence(cutseq,0);
	}
	
	/**
		This method takes a one-line sequence, and it removes
		histidine heads and/or tails. Optional second parameter
		drives the behavior (0 or negative is head, 1 is tail, 2 is both).
	*/
	protected String pruneSequence(String cutseq,int mode) {
		if(mode>0) {
			if(mode >= 2) {
				return pruneSequence(pruneSequence(cutseq),1);
			}

			cutseq=new StringBuilder(cutseq).reverse().toString();
		}
		
		Matcher m;
		if(cutseq.length()>=MINSEQLENGTH && (m=hdpattern.matcher(cutseq.substring(0,HAREA))).find()) {
			// Let's get last match
			int lastpos;
			do {
				lastpos=m.start();
			} while(m.find());
			
			// And now the length
			Matcher lastmatcher = hxpattern.matcher(cutseq.substring(lastpos));
			lastmatcher.find();
			int headpos=lastpos+lastmatcher.end();
			
			// So the pos is...
			cutseq=cutseq.substring(headpos);
		}

		return (mode>0)?(new StringBuilder(cutseq).reverse().toString()):cutseq;
	}
	
	protected boolean filterFASTAFile(File origFile,File newFile,File filtFile,File analFile)
		throws FileNotFoundException, IOException
	{
		boolean succeed=true;
		BufferedReader ORIG=new BufferedReader(new FileReader(origFile));
		ArrayList<String> origheaders=null;
		try {
			origheaders=readFASTAHeaders(ORIG);
			// We don't need it any more
		} finally {
			ORIG.close();
		}
		
		BufferedReader NEW = new BufferedReader(new FileReader(newFile));
		ArrayList<String> newheaders=null;
		try {
			newheaders=readFASTAHeaders(NEW);
			// We don't need it any more
		} finally {
			NEW.close();
		}
		
		// Now, let's find only new entries
		int maxorigpos=origheaders.size();
		int maxnewpos=newheaders.size();
		int origpos=0;
		int newpos=0;
		HashMap<String,Object> candidate=new HashMap<String,Object>();
		while(origpos<maxorigpos && newpos<maxnewpos) {
			if(origheaders.get(origpos).equals(newheaders.get(newpos))) {
				// Equal, next step!
				origpos++;
				newpos++;
			} else if(origheaders.get(origpos).compareTo(newheaders.get(newpos))<0) {
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
				NEW = new BufferedReader(new FileReader(newFile));
				while((line=NEW.readLine())!=null) {
					if(line.charAt(0)=='>') {
						// We have a candidate sequence!
						if(description!=null && sequence.length()>=MINSEQLENGTH) {
							String cutseq=pruneSequence(sequence.toString().toUpperCase(),2);

							// Has passed the filter?
							if(cutseq.length()>=MINSEQLENGTH) {
								// Let's save it!
								FILT.println(description);
								FILT.println(cutseq);
								if(survivor) {
									ANAL.println(description);
									ANAL.println(cutseq);
								}
							}
						}

						// New header is it in the "chosen one" list?
						description=line;
						sequence=new StringBuilder();
						survivor=candidate.containsKey(line.substring(1));
					} else if(sequence!=null) {
						sequence.append(line.replace("\t",""));
					}
				}

				if(description!=null && sequence.length()>=MINSEQLENGTH) {
					String cutseq=pruneSequence(sequence.toString().toUpperCase(),2);

					// Has passed the filter?
					if(cutseq.length()>=MINSEQLENGTH) {
						// Let's save it!
						FILT.println(description);
						FILT.println(cutseq);
						if(survivor) {
							ANAL.println(description);
							ANAL.println(cutseq);
						}
					}
				}
			} finally {
				ANAL.close();
			}
		} finally {
			FILT.close();
		}
		
		return succeed;
	}
	
	protected String processFASTAPDBDesc(String desc) {
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
	
	protected HashMap<String,PDBSeq> copyWithPrefix(File fastaFile,String prefix,PrintWriter FH)
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
				if(line.charAt(0)=='>') {
					if(id!=null)
						seqs.put(id,new PDBSeq(id,iddesc,sequence));
					String desc=line.substring(1);
					FH.println(">"+prefix+PREF_SEP+desc);

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
	
	protected HashMap<String,PDBSeq> parseLeaders(HashMap<String,HashMap<String,PDBSeq>> survivors,File leadersFile)
		throws FileNotFoundException, IOException
	{
		HashMap<String,PDBSeq> leaders=new HashMap<String,PDBSeq>();
		BufferedReader FH=new BufferedReader(new FileReader(leadersFile));
		String line;
		while((line=FH.readLine())!=null) {
			if(line.length() > 0 && line.charAt(0)=='>') {
				String[] procHeader = line.split(PREF_SEP, 2);
				if(procHeader.length<2 || !survivors.containsKey(procHeader[0])) {
					throw new IOException("Garbled FASTA header at "+leadersFile.getAbsolutePath());
				}
				HashMap<String,PDBSeq> paq = survivors.get(procHeader[0]);
				String pdbCode=processFASTAPDBDesc(procHeader[1]);
				if(pdbCode==null || !paq.containsKey(pdbCode)) {
					throw new IOException("PDB Id "+pdbCode+" was not found! Perhaps the FASTA header was garbled");
				}
				PDBSeq leaderSeq=paq.get(pdbCode);
				leaderSeq.features.put(PDBSeq.ORIGIN_KEY, PDBPREFIX.equals(procHeader[0])?PDB_LABEL:PDBPRE_LABEL);
				leaders.put(leaderSeq.id,leaderSeq);
			}
		}
		
		FH.close();
		
		return leaders;
	}
	
	protected HashMap<String,PDBSeq> chooseLeaders(File workdir, File origprepdb, File origpdb, File analprepdb, File analpdb, File leadersdb, File leadersReport)
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
				pdbArray=copyWithPrefix(analpdb,PDBPREFIX,SURVFH);
			} catch(IOException ioe) {
				throw new IOException("ERROR: Unable to concatenate "+analpdb.getAbsolutePath()+" to "+survdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			try {
				pdbPreArray=copyWithPrefix(analprepdb,PDBPREPREFIX,SURVFH);
			} catch(IOException ioe) {
				throw new IOException("ERROR: Unable to concatenate "+analprepdb.getAbsolutePath()+" to "+survdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
		} finally {
			SURVFH.close();
		}

		HashMap<String,HashMap<String,PDBSeq>> survivors=new HashMap<String,HashMap<String,PDBSeq>>();
		survivors.put(PDBPREFIX,pdbArray);
		survivors.put(PDBPREPREFIX,pdbPreArray);

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
		Runtime r=Runtime.getRuntime();
		
		logStream.println("NOTICE: Launching @CDHIT2Dparams");
		Process p = r.exec(CDHIT2Dparams);
		StreamRedirector sro=new StreamRedirector(p.getInputStream(),logStream,logStream);
		StreamRedirector sre=new StreamRedirector(p.getErrorStream(),logStream,logStream);
		sro.start();
		sre.start();
		
		try {
			int retval = p.waitFor();
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
		
		logStream.println("NOTICE: Launching @CDHITparams");
		p = r.exec(CDHITparams);
		sro=new StreamRedirector(p.getInputStream(),logStream,logStream);
		sre=new StreamRedirector(p.getErrorStream(),logStream,logStream);
		sro.start();
		sre.start();
		try {
			int retval = p.waitFor();
			if(retval!=0)
				throw new IOException("ERROR: system @CDHITparams failed: "+retval);
		} catch(InterruptedException ie) {
			throw new IOException("ERROR: system @CDHITparams failed due "+ie.getMessage());
		}
		
		// Let's catch the leaders!
		HashMap<String,PDBSeq> leaders=parseLeaders(survivors,leadersdb);
		
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

		logStream.println("NOTICE: Launching @BLASTparams");
		BufferedOutputStream lrs=null;
		try {
			lrs=new BufferedOutputStream(new FileOutputStream(leadersReport));
		} catch(IOException ioe) {
			throw new IOException("ERROR: unable to create BLAST report "+leadersReport.getAbsolutePath()+". Reason: "+ioe.getMessage());
		}
		p = r.exec(BLASTparams);
		try {
			sro=new StreamRedirector(p.getInputStream(),lrs,logStream);
			sre=new StreamRedirector(p.getErrorStream(),logStream,logStream);
			sro.start();
			sre.start();
			try {
				int retval = p.waitFor();
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
					logStream.println("This one is really difficult! "+query);
					// We need to save here the information to generate the XML report
					query=null;
				} else if(line.indexOf("Sequences producing significant")==0) {
					logStream.println("An easy one: "+query);
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
			if(!Worigpdb.equals(origpdb))
				copyFile(origpdb,Worigpdb);
		} catch(IOException ioe) {
			throw new IOException("FATAL ERROR: Unable to copy "+origpdb.getAbsolutePath()+" to "+Worigpdb.getAbsolutePath()+" due "+ioe.getMessage()+". Reason:"+ioe.getMessage());
		}

		File Wnewprepdb=new File(workdir,PDBPREFILE);
		try {
			if(!Wnewprepdb.equals(newprepdb))
				copyFile(newprepdb,Wnewprepdb);
		} catch(IOException ioe) {
			throw new IOException("FATAL ERROR: Unable to copy "+newprepdb.getAbsolutePath()+" to "+Wnewprepdb.getAbsolutePath()+" due "+ioe.getMessage()+". Reason:"+ioe.getMessage());
		}
		
		File Wnewpdb=new File(workdir,PDBFILE);
		try {
			if(!Wnewpdb.equals(newpdb))
				copyFile(newpdb,Wnewpdb);
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
				filterFASTAFile(Wnewfiltprepdb,Worigprepdb,newprepdb,analprepdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analprepdb.getAbsolutePath()+" from "+Worigprepdb.getAbsolutePath()+" and "+Wnewprepdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			try {
				filterFASTAFile(Wnewfiltpdb,Worigpdb,newpdb,analpdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analpdb.getAbsolutePath()+" from "+Worigpdb.getAbsolutePath()+" and "+Wnewpdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			
			return null;
		} else {
			// Third, easy filtering phase (new only, 30 residues or more after
			// prunning histidines heads and tails)
			try {
				filterFASTAFile(Worigprepdb,Wnewprepdb,Wnewfiltprepdb,analprepdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analprepdb.getAbsolutePath()+" from "+Worigprepdb.getAbsolutePath()+" and "+Wnewprepdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}
			try {
				filterFASTAFile(Worigpdb,Wnewpdb,Wnewfiltpdb,analpdb);
			} catch(IOException ioe) {
				throw new IOException("FATAL ERROR: Unable to generate "+analpdb.getAbsolutePath()+" from "+Worigpdb.getAbsolutePath()+" and "+Wnewpdb.getAbsolutePath()+". Reason:"+ioe.getMessage());
			}

			// Fourth, heuristics and difficult filtering phase
			leadersdb=new File(workdir,LEADERSDB);
			leadersReport=new File(workdir,LEADERSDB+BLASTPOST);
			return chooseLeaders(workdir,origprepdb,origpdb,analprepdb,analpdb,leadersdb,leadersReport);

			// File leadersprepdb=new File(workdir,LEADERSPRE+PDBPREFILE);
			// File leaderspdb=new File(workdir,LEADERSPRE+PDBFILE);

			// Fifth, other tools?????
		}
	}
	
	public static HashMap<String,PDBSeq> StaticDoGOPHERPrepare(File origprepdb,File newprepdb,File origpdb,File newpdb,File workdir,boolean first)
		throws IOException
	{
		GOPHERPrepare gp=new GOPHERPrepare();
		return gp.doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,first);
	}

	public final static void main(String[] args) {
		if(args.length>=5) {
			File origprepdb=new File(args[0]);
			File newprepdb=new File(args[1]);

			File origpdb=new File(args[2]);
			File newpdb=new File(args[3]);

			File workdir=new File(args[4]);
			boolean first=args.length>5;
			
			try {
				GOPHERPrepare gp=new GOPHERPrepare();
				gp.doGOPHERPrepare(origprepdb,newprepdb,origpdb,newpdb,workdir,first);
				DoExit(0);
			} catch(IOException ioe) {
				System.err.println(ioe.getMessage());
				DoExit(1);
			}
		} else {
			System.err.println("FATAL ERROR: This program needs at least 5 params, in order:\n"
+"*	The filtered, previous week, PDBPre database file in FASTA format.\n"
+"*	The unfiltered, current week, PDBPre database file in FASTA format.\n"
+"*	The filtered, previous week, PDB database file in FASTA format.\n"
+"*	The unfiltered, current week, PDB database file in FASTA format.\n"
+"*	The working directory where to store all the results and intermediate files.\n"
+"\n"
+"	When a sixth optional param is used (the value does not matter), the meaning changes:\n"
+"\n"
+"*	The unfiltered, current week, PDBPre database file in FASTA format.\n"
+"*	The filtered, current week, PDBPre database file in FASTA format (to be generated).\n"
+"*	The unfiltered, current week, PDB database file in FASTA format.\n"
+"*	The filtered, current week, PDB database file in FASTA format (to be generated).\n"
+"*	The working directory where to store all the intermediate files.");
			DoExit(1);
		}
	}
	
	protected final static void DoExit(int status) {
		System.exit(status);
	}
}
