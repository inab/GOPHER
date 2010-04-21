package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.zip.GZIPInputStream;

/**
 * 
 * @author jmfernandez
 *
 */
public class PDBParser {
	protected final static String PDBPREPREFIX="N";
	protected final static String PDBPREFIX="P";
	protected final static char FASTA_HEADER_PREFIX='>';
	protected final static char PREF_SEP=':';
	protected final static String PREF_SEP_STRING=new String(new char[] {PREF_SEP});
	protected final static String FASTA_PDB_HEADER_PREFIX=FASTA_HEADER_PREFIX+"PDB"+PREF_SEP;
	protected final static int SegSize=60;

	// Global variables and constants, mainly used by static methods
	protected final static String[] ARTIFACTS={
		"CLON",		// 'Cloning Artifact'
		"EXPR",		// 'Expression Tag'
		"INIT",		// 'Initiating Methionine'
		"LEADER",	// 'Leader Sequence'
	};
	
	/**
	 * This static method fetches from a reader the lines which are FASTA headers
	 * @param FH The reader used to fetch the FASTA headers
	 * @return A list with the FASTA headers, unparsed
	 * @throws IOException
	 */
	public static List<String> ReadFASTAHeaders(BufferedReader FH)
		throws IOException
	{
		ArrayList<String> headers=new ArrayList<String>();
		
		String line;
		while((line=FH.readLine())!=null) {
			if(line.length() > 0 && line.charAt(0)==FASTA_HEADER_PREFIX) {
				headers.add(line.substring(1));
			}
		}
		
		return headers;
	}

	/**
	 * This static method extracts the PDB Ids from a list of FASTA headers
	 * which come from a FASTA file previously generated inside this class
	 * @param origHeaders A list with the FASTA header lines
	 * @return A set with the extracted PDB Ids
	 */
	protected static Set<String> ExtractPDBIdsFromFASTAHeaders(List<String> origHeaders) {
		// Let's process the origHeaders, so we get the PDB Ids in a set
		// And we are going to ban at whole entry level, not at individual chains one,
		HashSet<String> origPDBIds=new HashSet<String>();
		for(String header: origHeaders) {
			if(header.indexOf(FASTA_PDB_HEADER_PREFIX)==0) {
				origPDBIds.add(header.substring(FASTA_PDB_HEADER_PREFIX.length(), header.indexOf(PDBChain.CHAIN_SEP)));
			}
		}
		
		return origPDBIds;
	}
	
	public static void WriteFASTASeq(PrintStream DEST,CharSequence header,CharSequence sequence) {
		WriteFASTASeq(DEST,header,sequence,0);
	}
	
	public static void WriteFASTASeq(PrintStream DEST,final CharSequence header,final CharSequence sequence,final int lineSize) {
		DEST.println(FASTA_PDB_HEADER_PREFIX+header);
		
		if(lineSize>0) {
			CharSequence prev_seq=sequence;
			while(prev_seq.length()>lineSize) {
				DEST.println(prev_seq.subSequence(0, lineSize));
				prev_seq = prev_seq.subSequence(lineSize, prev_seq.length());
			}
			if(prev_seq.length()>0)
				DEST.println(prev_seq);
		} else {
			DEST.println(sequence);
		}
	}
	
	// And now, the instance variables
	protected CIFDict dict;
	
	protected HashMap<String, Character> toOneAA;
	protected HashSet<String> notAA;
	protected HashMap<String,PDBSeq> chainadvs=new HashMap<String,PDBSeq>();
	
	// The artifacts file
	protected PrintStream AFILE;
	// The error messages file
	protected PrintStream ERR;
	
	public PDBParser(File cifdict)
		throws IOException
	{
		this(cifdict,(PrintStream)null);
	}

	public PDBParser(File cifdict, File artifactsFile)
		throws IOException
	{
		this(cifdict,new PrintStream(new BufferedOutputStream(new FileOutputStream(artifactsFile))));
	}
	
	public PDBParser(File cifdict, PrintStream AFILE)
		throws IOException
	{
		this(cifdict,AFILE,System.err);
	}

	/**
	 * PDB parser object has all the methods needed to parse PDB files and get
	 * the aminoacid sequences, either filtered or unfiltered.
	 * 
	 * @param cifdict The file pointing to the CIFDict dictionary
	 * @throws IOException
	 */
	public PDBParser(File cifdict, PrintStream AFILE, PrintStream ERR)
		throws IOException
	{
		// Let's read CIF dictionary
		dict= new CIFDict(cifdict);
		toOneAA = dict.getMapping();
		notAA = dict.getNotMapping();
		this.AFILE = AFILE;
		this.ERR = ERR;
	}
	
	/**
	 * This method takes as input a PDB file or a directory which has as descendants
	 * PDB files, and it will return the parsed, filtered result. Those files which are not PDB
	 * files are simply discarded. Additionally, you can get the unfiltered and/or filtered
	 * sequences inside files, along with the found artifacts (only used for debugging).
	 * 
	 * @param input The input file or directory
	 * @param origHeaders The headers in FASTA format from the survivors of a previous run
	 * @param sequencesFile The file where aminoacid sequences found in the different PDB files are dumped, unfiltered
	 * @param clippedSelFile File where all new aminoacid sequences from the parsed PDBs, with unknown aminoacids clipped from both sides, are written
	 * @param prunedSelFile File where all new aminoacid sequences from the parsed PDBs which fulfill the requisites, with artifacts removed, are dumped
	 * @param propagateErrors Propagate exception when an error is found
	 * @return The list with only the new PDBSeq sequences, pruned and clipped
	 * @throws IOException
	 */
	public List<PDBSeq> parsePDBs(File input, final List<String> origHeaders, final File sequencesFile, final File clippedSelFile, final File prunedSelFile, boolean propagateErrors)
		throws IOException
	{
		return parsePDBs(new File[] { input },origHeaders,sequencesFile,clippedSelFile,prunedSelFile,propagateErrors);
	}
	
	/**
	 * This method takes as input a list of PDB files or directories which have as descendants
	 * PDB files, and it will return the parsed, filtered result. Those files which are not PDB
	 * files are simply discarded. Additionally, you can get the unfiltered and/or filtered
	 * sequences inside files, along with the found artifacts (only used for debugging).
	 * 
	 * @param inputQueue The array with the input files/directories
	 * @param origHeaders The headers in FASTA format from the survivors of a previous run
	 * @param sequencesFile The file where aminoacid sequences found in the different PDB files are dumped, unfiltered
	 * @param clippedSelFile File where all new aminoacid sequences from the parsed PDBs, with unknown aminoacids clipped from both sides, are written
	 * @param prunedSelFile File where all new aminoacid sequences from the parsed PDBs which fulfill the requisites, with artifacts removed, are dumped
	 * @param propagateErrors Propagate exception when an error is found
	 * @return The list with only the new PDBSeq sequences, pruned and clipped
	 * @throws IOException
	 */
	public List<PDBSeq> parsePDBs(File[] inputQueue, final List<String> origHeaders, final File sequencesFile, final File clippedSelFile, final File prunedSelFile, boolean propagateErrors)
		throws IOException
	{
		ArrayList<PDBSeq> survivors=new ArrayList<PDBSeq>();
		chainadvs=new HashMap<String,PDBSeq>();
		
		FileOutputStream fuout = null;
		BufferedOutputStream buout = null;
		PrintStream UOUT = null;
		
		FileOutputStream fout = null;
		BufferedOutputStream bout = null;
		PrintStream OUT = null;
		
		FileOutputStream ffout = null;
		BufferedOutputStream bfout = null;
		PrintStream FOUT = null;
		
		// Now, let's work!
		if(sequencesFile!=null) {
			fuout = new FileOutputStream(sequencesFile);
			buout = new BufferedOutputStream(fuout);
			UOUT = new PrintStream(buout);
		}
		
		if(clippedSelFile!=null) {
			fout = new FileOutputStream(clippedSelFile);
			bout = new BufferedOutputStream(fout);
			OUT = new PrintStream(bout);
		}
		
		if(prunedSelFile!=null) {
			ffout = new FileOutputStream(prunedSelFile);
			bfout = new BufferedOutputStream(ffout);
			FOUT = new PrintStream(bfout);
		}
		
		Set<String> origPDBIds=ExtractPDBIdsFromFASTAHeaders(origHeaders);
		
		List<File> dynDirQueue=Arrays.asList(inputQueue);
		
		try {
			while(dynDirQueue.size()>0) {
				ArrayList<File> newDynDirQueue = new ArrayList<File>();
				for(File dirname: dynDirQueue) {
					try {
						List<File> moreDirQueue = parsePDBDirEntry(dirname, propagateErrors, origPDBIds, survivors, UOUT, OUT, FOUT);
						newDynDirQueue.addAll(moreDirQueue);
					} catch(IOException ioe) {
						if(propagateErrors) {
							ERR.println("ERROR: Unable to process directory "+dirname.getAbsolutePath());
							throw ioe;
						} else {
							ERR.println("WARNING: Unable to process directory "+dirname.getAbsolutePath());
							ioe.printStackTrace();
						}
					}
				}
				dynDirQueue=newDynDirQueue;
			}
		} finally {
			if(UOUT!=null) {
				UOUT.close();
				try {
					buout.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
				try {
					fuout.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
			
			if(OUT!=null) {
				OUT.close();
				try {
					bout.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
				try {
					fout.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
			
			if(FOUT!=null) {
				FOUT.close();
				try {
					bout.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
				try {
					fout.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
		}
		
		return survivors;
	}
	
	protected List<File> parsePDBDirEntry(File direntry, boolean propagateErrors, Set<String> prevPDBIds, List<PDBSeq> survivors, PrintStream UOUT, PrintStream OUT, PrintStream FOUT)
		throws IOException
	{
		ArrayList<File> dirqueue = new ArrayList<File>();
		
		File[] entries = null;
		if(direntry.isDirectory()) {
			entries = direntry.listFiles();
		} else {
			entries = new File[] { direntry };
		}
		
		for(File entry: entries) {
			String entryName=entry.getName();
			
			// Skip hidden files
			if(entry.isHidden() || entryName.equals(".") || entryName.equals("..")) {
				continue;
			}
			
			if(entry.isDirectory()) {
				dirqueue.add(entry);
			} else if(entryName.endsWith(".ent.Z") || entryName.endsWith(".ent.gz") || entryName.endsWith(".ent")) {
				try {
					List<PDBSeq> newSurvivors = parsePDBFile(entry,prevPDBIds,UOUT,OUT,FOUT);
					if(survivors!=null && newSurvivors!=null) {
						survivors.addAll(newSurvivors);
					}
				} catch(IOException ioe) {
					if(propagateErrors) {
						throw ioe;
					} else {
						ERR.println("WARNING: Unable to process file "+entry.getAbsolutePath());
						ioe.printStackTrace();
					}
				}
			} else if(propagateErrors) {
				throw new IOException(entry.getAbsolutePath()+" is neither a directory nor a PDB file!");
			} else {
				ERR.println("WARNING: "+entry.getAbsolutePath()+" is neither a directory nor a PDB file!");
			}
		}
		
		return dirqueue;
	}
	
	protected List<PDBSeq> parsePDBFile(File entry)
		throws IOException
	{
		return parsePDBFile(entry, null, null, null, null);
	}

	protected List<PDBSeq> parsePDBFile(File entry,final Set<String> prevPDBIds)
		throws IOException
	{
		return parsePDBFile(entry, prevPDBIds, null, null, null);
	}

	protected List<PDBSeq> parsePDBFile(File entry, PrintStream OUT, PrintStream FOUT, PrintStream AFILE)
		throws IOException
	{
		return parsePDBFile(entry, null, OUT, FOUT, AFILE);
	}
	
	/**
	 * This is the beast's brain, where a PDB file is parsed
	 * @param dirEntry The File object pointing to a PDB file, which could (or could not) be compressed
	 * @param prevPDBIds The set of previously found PDB ids, so we can completely skip the parse task
	 * @param UOUT The PrintStream where we can print all the found sequences, unfiltered
	 * @param OUT The PrintStream where we can print all the found sequences, filtered
	 * @param FOUT The PrintStream where we can print only new sequences, filtered
	 * @return
	 * @throws IOException
	 */
	protected List<PDBSeq> parsePDBFile(File dirEntry,final Set<String> prevPDBIds, PrintStream UOUT, PrintStream OUT, PrintStream FOUT)
		throws IOException
	{
		FileInputStream fpdbh = null;
		BufferedInputStream bpdbh = null;
		GZIPInputStream gpdbh = null;
		InputStreamReader ipdbh = null;
		BufferedReader PDBH = null;
		
		ArrayList<PDBSeq> parsed = new ArrayList<PDBSeq>();
		
		// File it's just open, let's read it!
		try {
			fpdbh = new FileInputStream(dirEntry);
			bpdbh = new BufferedInputStream(fpdbh);
			try {
				gpdbh = new GZIPInputStream(bpdbh);
			} catch(IOException ioe) {
				// This exception is usually fired either
				// on unknown compression method or on
				// unrecognized stream, so IgnoreIT(R)!!
			}
			ipdbh = new InputStreamReader((gpdbh!=null)?gpdbh:bpdbh);
			PDBH = new BufferedReader(ipdbh);
			
			String pdbcode=null;
			String current_molid=null;
			String current_desc=null;
			// StringBuilder compline=null;
			ArrayList<StringBuilder> comparr=new ArrayList<StringBuilder>();
			PDBChains chains= null;
			StringBuilder title=null;
			String header=null;
			String prev_chain=null;
			PDBCoord prevCoord=null;
			String prev_subcomp=null;
			boolean badchain=false;
			HashSet<String> ignoreChain=new HashSet<String>();
			int numModels=1;
			boolean doRemark465=false;
			
			String line;
			int readingState=0;
			while((line=PDBH.readLine())!=null) {
				// Line by line
				if(readingState==0) {
					if(line.startsWith("HEADER")) {
						String fheader=line.split("[ \t]+",2)[1];
						String[] htoken=fheader.split("\\s+");
						pdbcode=htoken[htoken.length-1];
						
						// Only store when new chains can be added
						if(prevPDBIds!=null && prevPDBIds.contains(pdbcode)) {
							parsed=null;
							
							// And we can completely skip this parse job when we are not going to save
							// the raw chain sequences
							if(UOUT==null && OUT==null) {
								break;
							}
						}
						
						chains= new PDBChains(pdbcode, true, dict);
						header=MiscHelper.join(MiscHelper.subList(htoken,0,htoken.length-2)," ");
					} else if(line.startsWith("TITLE")) {
						if(title!=null) {
							String ctitle=line.split("[ \t]+",3)[2].replaceFirst("[ \t]+$","");
							title.append(' ').append(ctitle);
						} else {
							title=new StringBuilder(line.split("[ \t]+",2)[1].replaceFirst("[ \t]+$",""));
						}
					/*
					} else if(line.startsWith("COMPND") || (compline!=null && line.startsWith("SOURCE"))) {
						if(current_molid!=null || compline!=null) {
							if(line.startsWith("SOURCE")) {
								if(compline!=null)
									compline.append(';');
							} else if(compline!=null) {
								String pre_compline=line.split("[ \t]+",3)[2];
								if(pre_compline.indexOf(':')==-1) {
									compline.append(' ').append(pre_compline);
								} else {
									if(!compline.toString().endsWith(";"))
										compline.append(';');
									ERR.println("JOM "+compline);
									String[] procres = PROCCOMP(compline.toString(),current_desc,chaindescs);
									if(procres!=null) {
										if(procres[0]!=null)
											prev_subcomp=procres[0];
										if(procres[1]!=null)
											current_molid=procres[1];
										if(procres[2]!=null)
											current_desc=procres[2];
									}
									compline=new StringBuilder(pre_compline);
								}
							} else {
								compline = new StringBuilder(line.split("[ \t]+",3)[2]);
							}
						} else {
							compline=new StringBuilder(line.split("[ \t]+",2)[1]);
							if(compline.indexOf("NULL")==0)
								break;
						}
						compline=new StringBuilder(compline.toString().replaceFirst("[ \t]+$","").replaceAll("\\\\+", ""));
						if(compline.indexOf(":")==-1) {
							if(prev_subcomp!=null) {
								if("MOL_ID".equals(prev_subcomp)) {
									compline=new StringBuilder(prev_subcomp).append(": ").append(current_molid).append(compline);
								} else if("MOLECULE".equals(prev_subcomp)) {
									compline=new StringBuilder(prev_subcomp).append(": ").append(current_desc).append(' ').append(compline);
								} else if("CHAIN".equals(prev_subcomp)) {
									compline=new StringBuilder(prev_subcomp).append(": ").append(compline);
								} else {
									continue;
								}
								//$prev_subcomp=undef;
							} else {
								ERR.println("BLAMEPDB: "+pdbcode+" "+compline);
							}
						} else {
							prev_subcomp=null;
						}
						String[] procres = PROCCOMP(compline.toString(),current_desc,chaindescs);
						if(procres!=null) {
							if(procres[0]!=null)
								prev_subcomp=procres[0];
							if(procres[1]!=null)
								current_molid=procres[1];
							if(procres[2]!=null)
								current_desc=procres[2];
							compline=null;
						}
					*/
					} else if(line.startsWith("COMPND")) {
						int chunk=(comparr.size()==0)?2:3;
						String compchunk = line.split("[ \t]+",chunk)[chunk-1].replaceFirst("[ \t]+$","").replaceAll("\\\\+", "");
						if(compchunk.indexOf(':')!=-1) {
							comparr.add(new StringBuilder(compchunk));
						} else if(comparr.size()>0) {
							StringBuilder tb = comparr.get(comparr.size()-1);
							if(tb.charAt(tb.length()-1)!='-')
								tb.append(' ');
							tb.append(compchunk);
						} else {
							ERR.println("Jammed case!!!! "+pdbcode);
							break;
						}
					} else if(line.startsWith("SOURCE")) {
						for(StringBuilder compline: comparr) {
							if(!compline.toString().endsWith(";"))
								compline.append(';');
							
							// ERR.println("PROCE "+compline);
							String[] procres = PROCCOMP(compline.toString(),current_desc,chains);
							if(procres!=null) {
								if(procres[0]!=null)
									prev_subcomp=procres[0];
								if(procres[1]!=null)
									current_molid=procres[1];
								if(procres[2]!=null)
									current_desc=procres[2];
							}
						}
					} else if(line.startsWith("NUMMDL ")) {
						numModels=Integer.parseInt(line.substring(10, 14).trim());
						if(numModels>0)
							chains.setNumModels(numModels);
					} else if(line.startsWith("REMARK 465") && line.length()>=26) {
						if(AFILE!=null)
							AFILE.println(line);
						if(doRemark465) {
							// Let's store these missing residues for further reconstruction
							String res = line.substring(15,18).trim();
							String chain = line.substring(19,20).trim();
							try {
								int pos = Integer.parseInt(line.substring(21, 26).trim());
								char pos_ins = line.charAt(26);
								chains.storeMissingResidue(chain, new PDBRes(res, pos, pos_ins));
							} catch(NumberFormatException nfe) {
								// NaN or NaE!?!
								ERR.println("MAYBEERROR["+pdbcode+"]R: "+line);
							}
						} else if(line.contains("M RES C SSSEQI")) {
							doRemark465=true;
						} 
					} else if(line.startsWith("DBREF ")) {
						String localchain = line.substring(12,13).trim();
						PDBCoord startPosition = new PDBCoord(Integer.parseInt(line.substring(14, 18).trim()),line.charAt(18));
						PDBCoord endPosition = new PDBCoord(Integer.parseInt(line.substring(20, 24).trim()),line.charAt(24));
						String db=line.substring(26, 32).trim();
						String id=line.substring(33, 41).trim();
						chains.addMapping(localchain, db, id, startPosition, endPosition);
						
					} else if(line.startsWith("DBREF1 ")) {
						String localchain = line.substring(12,13).trim();
						PDBCoord startPosition = new PDBCoord(Integer.parseInt(line.substring(14, 18).trim()),line.charAt(18));
						PDBCoord endPosition = new PDBCoord(Integer.parseInt(line.substring(20, 24).trim()),line.charAt(24));
						String db=line.substring(26, 32).trim();
						String id=line.substring(47, 67).trim();
						chains.addMapping(localchain, db, id, startPosition, endPosition);
						
					} else if(line.startsWith("SEQADV ")) {
						// See PDB manual documentation about SEQADV
						String conflict=line.substring(49).trim();
						for(String artifact: ARTIFACTS) {
							// Is this artifact interesting for us?
							if(conflict.startsWith(artifact) || conflict.indexOf("\t"+artifact)!=-1) {
								if(AFILE!=null)
									AFILE.println(line.substring(7));
								
								String ires = line.substring(12,15).trim();
								String localchain = line.substring(16,17).trim();
								String lposition = line.substring(18, 22).trim();
								if(lposition.length()==0)
									ERR.println("MAYBEERROR["+pdbcode+"]S: "+line);
								else {
									PDBAmino amino = new PDBAmino(toOneAA.get(ires),Integer.parseInt(lposition),line.charAt(22));
									// Is it an insertion?
									// line.substring(22, 23);
									String db=line.substring(24, 28).trim();
									String id=line.substring(29, 38).trim();
									
									// String sres = line.substring(39,42).trim();
									// String sposition = line.substring(43,48).trim();
									
									if(toOneAA.containsKey(ires)) {
										chains.appendToArtifact(localchain, db, id, artifact, amino);
										
										// ERR.println("IRES "+ires+"("+((ireschar!=null)?ireschar:'?')+")"+" LC "+localchain+" POS "+position+" SReS "+sres+" SPOS "+sposition);
									}
								}
								
								break;
							}
						}
					} else if(line.startsWith("SEQRES ") || line.startsWith("ATOM ") || line.startsWith("HETATM ") || line.startsWith("MODEL ")) {
						readingState=1;
					}
				}
				
				// This state is related to sequence reading using SEQRES lines 
				if(readingState==1) {
					// We are reading sequences
					String localchain = null;
					if(line.startsWith("SEQRES ")) {
						String[] seqlines=line.substring(19,70).trim().split("\\s+");
						localchain=line.substring(11, 12).trim();
						
						// Now, let's keep the track
						if(!chains.appendToSeqChain(localchain, seqlines)) {
							badchain=true;
							ignoreChain.add(localchain);
						}
					} else {
						readingState=2;
					}
					// At last, let's save the fragment of chain's sequence
					if(prev_chain==null || localchain==null || !localchain.equals(prev_chain)) {
						PDBSeq anotherChain = PRINTCMD(OUT, FOUT, pdbcode,prev_chain,chains,badchain,dirEntry);
						if(anotherChain!=null) {
							// Mapping stuff will disappear from here because it must be applied from inside
							List<PDBChain.Mapping> maplist = chains.getMappingList(prev_chain);
							if(maplist!=null) {
								// int seqLength=anotherChain.sequence.length();
								int mappedLength=0;
								int artifactsLength=0;
								for(PDBChain.Mapping map: maplist) {
									mappedLength += map.end.sub(map.start)+1;
									List<PDBChain.Fragment> chainArtifacts = map.getFragmentList();
									if(chainArtifacts!=null) {
										for(PDBChain.Fragment artifact: chainArtifacts) {
											artifactsLength+=artifact.end.sub(artifact.start)+1;
											// ERR.println("PDB "+pdbcode+" CHAIN "+prev_chain+" START "+artifact.start+" END "+artifact.end+" REASON "+artifact.reason);
										}
									}
								}
								// if((mappedLength+artifactsLength)!=seqLength)
								//	ERR.println("KUACK!!!! "+pdbcode+CHAIN_SEP+prev_chain+" length is "+seqLength+" but coordinates map "+mappedLength+" and artifacts map "+artifactsLength);
							}
//							List<PDBArtifact.Fragment> chainArtifacts = map.getFragmentList();
//							if(chainArtifacts!=null) {
//								for(PDBArtifact.Fragment artifact: chainArtifacts) {
//									ERR.println("PDB "+pdbcode+" CHAIN "+prev_chain+" START "+artifact.start+" END "+artifact.end+" REASON "+artifact.reason);
//								}
//							}
							
							if(parsed!=null)
								parsed.add(anotherChain);
						}
						badchain=false;
						
						prev_chain = localchain;
					}
						
				}
				
				// This one was introduced because the residues with their true chain 1D coordinates are here
				if(readingState==2) {
					if(line.startsWith("MODEL ")) {
						int modelNo=Integer.parseInt(line.substring(10, 14).trim());
						if(modelNo>0)
							chains.setCurrentModel(modelNo);
					} else if(line.startsWith("ATOM ") || line.startsWith("HETATM")) {
						String chain = line.substring(21,22).trim();
						if(chains.hasChain(chain) && !ignoreChain.contains(chain) && chains.isOpenAtomChain(chain)) {
							String residue = line.substring(17,20).trim();
							int coord = Integer.parseInt(line.substring(22,26).trim());
							char coord_ins=line.charAt(26);
							PDBRes resCoord = new PDBRes(residue, coord, coord_ins);
							if(prev_chain==null || !prev_chain.equals(chain) || !resCoord.equals(prevCoord)) {
								boolean hasPrev=true;
								if(prev_chain==null || !prev_chain.equals(chain)) {
								/*
									// We are starting a chain, so let's pad it first
									artifacts.padFirst(chain,new PDBCoord(coord, coord_ins));
								} else if((prev_coord+1)!=coord && !(prev_coord==coord && prev_coord_ins!=coord_ins)) {
									if(artifacts.hasMissingResidues(chain)) { 
										ERR.println("ERROR: Residue coordinate mismatch! Prev: "+prev_coord+" New: "+coord);
										if(coord<prev_coord) {
											ERR.println("ERRORDEBUG["+pdbcode+"]A: "+line);
											return null;
										}
										artifacts.padAtomChain(chain, new PDBCoord(prev_coord,prev_coord_ins).contextInc(), new PDBCoord(coord,coord_ins).contextDec());
									} else {
										// No available fix... So, we can do nothing
										//doUpdate=false;
									}
								*/
									hasPrev=false;
								}
								
								chains.appendToAtomChain(chain, resCoord, (hasPrev)?prevCoord:null);
								prev_chain = chain;
								prevCoord = resCoord;
							}
						}
					} else if(line.startsWith("TER ")) {
						// Now, let's look for REMARKed residues beyond this limit...
						String chain = line.substring(21,22).trim();
						if(chains.hasChain(chain)) {
							chains.padAtomBoth(chain);
							//ERR.println("DEBUG: "+pdbcode+" Chain "+chain+" TER");
						}
					} else if(line.startsWith("ENDMDL")) {
						prev_chain=null;
						prevCoord = null;
					} else if(line.startsWith("END")) {
						// The right moment to compare, jarl!
						List<HashMap<String,PDBChain>> lchains=chains.lchains;
						
						ERR.println("REPORT "+chains.pdbcode);
						int modelpos=(lchains.size()>1)?1:0;
						for(HashMap<String,PDBChain> chainatoms: lchains) {
							ERR.println("Chains by   ATOM"+(modelpos==0?"":" (model "+modelpos+")")+": "+MiscHelper.join(chainatoms.keySet(), ", "));
							modelpos++;
						}
						
						HashMap<String,PDBChain> chainSeqs = lchains.get(0);
						for(PDBChain entry: chainSeqs.values()) {
							StringBuilder aminoSeqBuilder = entry.getSeqAminos();
							
							if(aminoSeqBuilder!=null) {
								String aminoSeq = PDBChain.ClipSequence(aminoSeqBuilder);
								if(UOUT!=null)
									WriteFASTASeq(UOUT,entry.getName()+" mol:protein length:"+aminoSeq.length()+"  "+entry.getDescription(),aminoSeq,SegSize);
								
								// Has passed the filters?
								PDBSeq pruned = entry.getPrunedSequence();
								if(pruned!=null) {
									CharSequence prunedSeq = pruned.sequence;
									if(OUT!=null)
										WriteFASTASeq(OUT,pruned.id+" mol:protein(pruned) length:"+prunedSeq.length()+"  "+pruned.iddesc,prunedSeq);
									
									// Is it a new sequence?
									if(parsed!=null) {
										if(FOUT!=null) {
											WriteFASTASeq(FOUT,pruned.id+" mol:protein(pruned) length:"+prunedSeq.length()+"  "+pruned.iddesc,prunedSeq);
										}
									}
								}
								
								// The comparisons which will be inside PDBChain
								/*
								String chainName = entry.chainName;
								modelpos=(lchains.size()>1)?1:0;
								for(HashMap<String,PDBChain> chainatoms: lchains) {
									PDBChain chain = chainatoms.get(chainName);
									StringBuilder chainSeqBuilder = chain.getAminos();
									if(chainSeqBuilder!=null) {
										String chainSeq=PDBChain.ClipSequence(chainSeqBuilder);
										boolean equalchain=chainSeq.equals(aminoSeq);
										ERR.println("\tCHAIN "+chainName+(modelpos==0?"":" (model "+modelpos+")")+" does"+(equalchain?" not":"")+" differ");
										if(!equalchain) {
											ERR.println("\t\tSEQRES => "+aminoSeq);
											ERR.println("\t\tATOM   => "+chainSeq);
										}
									}
									modelpos++;
								}
								*/
							} else {
								ERR.println("No protein sequence at "+entry.getName());
							}
						}
					}
				}
			}
			
			return parsed;
		} finally {
			if(PDBH!=null) {
				try {
					PDBH.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
			if(ipdbh!=null) {
				try {
					ipdbh.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
			if(gpdbh!=null) {
				try {
					gpdbh.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
			if(bpdbh!=null) {
				try {
					bpdbh.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
			if(fpdbh!=null) {
				try {
					fpdbh.close();
				} catch(IOException ioe) {
					// IgnoreIT(R)
				}
			}
		}
	}
	
	protected PDBSeq PRINTCMD(PrintStream OUT, PrintStream FOUT, String pdbcode, String prev_chain, PDBChains chains, boolean badchain,File direntry)
		throws IOException
	{
		PDBSeq pdb = null;
		if(prev_chain!=null) {
			StringBuilder prev_seqB = chains.getSeqChain(prev_chain);
			String prev_seq = (prev_seqB!=null)?prev_seqB.toString():null;
			String chaincode = pdbcode+PDBChain.CHAIN_SEP+prev_chain;
			if(prev_seq!=null && !badchain && !prev_seq.matches("^X+$")) {
				if(!chains.hasChain(prev_chain))
					ERR.println("BLAMEPDB: "+pdbcode);
				
				// First, internal storage
				if(chainadvs!=null) {
					// Let's process the sequence
					pdb = new PDBSeq(chaincode,chains.getChainDescription(prev_chain),new StringBuilder(prev_seq));
					pdb.features.put(PDBSeq.ORIGIN_KEY, GOPHERPrepare.PDB_LABEL);
					pdb.features.put(PDBSeq.PATH_KEY, direntry);
				}
				
				if(OUT!=null) {
					WriteFASTASeq(OUT,chaincode+" mol:protein length:"+prev_seq.length()+"  "+chains.getChainDescription(prev_chain),prev_seq,SegSize);
				}
				if(FOUT!=null) {
					WriteFASTASeq(FOUT,chaincode+" mol:protein length:"+prev_seq.length()+"  "+chains.getChainDescription(prev_chain),prev_seq,SegSize);
				}
			} else {
				ERR.println("NOTICE: "+chaincode+" is not a protein sequence");
			}
		}
		// $badchain=undef;
		
		return pdb;
	}
	
	protected String[] PROCCOMP(String compline,String current_desc,PDBChains chains)
	{
		int ridx=compline.lastIndexOf(';');
		if(ridx!=-1 && ridx==(compline.length()-1)) {
			String prev_subcomp=null;
			String current_molid=null;
			// String current_desc=null;
			
			compline=compline.substring(0,ridx);
			String[] comps=compline.split("[ \t]*:[ \t]*",2);
			prev_subcomp=comps[0];
			if(comps.length==1)
				ERR.println("JORL "+compline);
			String compdata=comps[1];
			if("MOL_ID".equals(prev_subcomp)) {
				current_molid=compdata;
			} else if("MOLECULE".equals(prev_subcomp)) {
				current_desc=compdata;
			} else if("CHAIN".equals(prev_subcomp)) {
				if(compdata.length()==0)
					compdata="NULL";
				for(String chain: compdata.split("[ ,]+")) {
					if("NULL".equals(chain))
						chain="";
					chains.setChainDescription(chain, current_desc);
				}
			}
			// $compline=undef;
			
			return new String[] {
				prev_subcomp,
				current_molid,
				current_desc
			};
		} else {
			return null;
		}
	}
	
	/**
	 * 
	 * @param input The input directory or file to be processed
	 * @param origHeaders The original headers to be used, in FASTA format
	 * @return The list of sequences which have survived to the filtering
	 * @throws IOException
	 */
	public List<PDBSeq> filterByPDBHeaders(File input,final List<String> origHeaders)
		throws IOException
	{
		ArrayList<File> dynDirQueue=new ArrayList<File>();
		dynDirQueue.add(input);
		
		return filterByPDBHeaders(dynDirQueue,origHeaders);
	}
	
	/**
	 * 
	 * @param inputs The input directories or files to be processed
	 * @param origHeaders The original headers to be used, in FASTA format
	 * @return The list of sequences which have survived to the filtering
	 * @throws IOException
	 */
	public List<PDBSeq> filterByPDBHeaders(List<File> inputs,final List<String> origHeaders)
		throws IOException
	{
		ArrayList<PDBSeq> survivors=new ArrayList<PDBSeq>();
		
		ArrayList<File> dynDirQueue=new ArrayList<File>();
		dynDirQueue.addAll(inputs);
		
		Set<String> origPDBIds=ExtractPDBIdsFromFASTAHeaders(origHeaders);
		
		while(dynDirQueue.size()>0) {
			ArrayList<File> newDynDirQueue = new ArrayList<File>();
			for(File dirname: dynDirQueue) {
				try {
					List<File> moreDirQueue = filterByPDBHeaders(dirname,origPDBIds,survivors);
					newDynDirQueue.addAll(moreDirQueue);
				} catch(IOException ioe) {
					ERR.println("WARNING: Unable to process directory "+dirname.getAbsolutePath());
					ioe.printStackTrace();
				}
			}
			dynDirQueue=newDynDirQueue;
		}
	
		return survivors;
	}
	
	protected List<File> filterByPDBHeaders(File directory,final Set<String> prevPDBIds,ArrayList<PDBSeq> survivors)
		throws IOException
	{
		if(!directory.isDirectory()) {
			throw new IOException(directory.getAbsolutePath()+" is not a directory!");
		}
		
		ArrayList<File> dirqueue = new ArrayList<File>();
		for(File direntry: directory.listFiles()) {
			String direntryName=direntry.getName();
			if(direntryName.equals(".") || direntryName.equals("..")) {
				continue;
			}
			
			if(direntry.isDirectory()) {
				dirqueue.add(direntry);
			} else if(direntryName.endsWith(".ent") || direntryName.endsWith(".ent.Z") || direntryName.endsWith(".ent.gz")) {
				try {
					survivors.addAll(parsePDBFile(direntry,prevPDBIds));
				} catch(IOException ioe) {
					ERR.println("WARNING: Unable to process file "+direntry.getAbsolutePath());
					ioe.printStackTrace();
				}
			}
		}
		
		return dirqueue;
			
	}
	
	/**
	 * The internal method used to free resources either under request
	 * or called by finalize
	 * @throws IOException
	 */
	private void freeResources()
		throws IOException
	{
		if(AFILE!=null && AFILE!=System.out && AFILE!=System.err) {
			AFILE.close();
			AFILE=null;
		}
		if(ERR!=null && ERR!=System.out && ERR!=System.err) {
			ERR.close();
			ERR=null;
		}
	}
	
	@Override
	protected void finalize()
		throws Throwable
	{
		freeResources();
		super.finalize();
	}
	
	public final static void main(String[] args)
		throws Throwable
	{
		if(args.length>4) {
			File destfile=new File(args[0]);
			File destUnfilteredFile=new File(args[1]);
			File artifactsFile=new File(args[2]);
			File cifdict=new File(args[3]);
			ArrayList<File> dq=new ArrayList<File>();
			for(String arg:MiscHelper.subList(args, 3)) {
				dq.add(new File(arg));
			}
			File[] dirqueue=new File[] {};
			dirqueue=dq.toArray(dirqueue);
			PDBParser p = new PDBParser(cifdict, artifactsFile);
			p.parsePDBs(dirqueue, null, destUnfilteredFile, destfile, null, false);
		} else {
			System.err.println(
				"This program needs:\n"+
				"	* A file where the PDB sequence chains are going to be saved in FASTA format.\n"+
				"	* A file where the interesting artifacts are going to be saved in pseudo SEQADV format (like SEQADV line, without SEQADV particle).\n"+
				"	* The CIF dictionary.\n"+
				"	* and one or more directories populated with PDB entries"
			);
		}
	}
}
