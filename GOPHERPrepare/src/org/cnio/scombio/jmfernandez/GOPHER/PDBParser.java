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
import java.util.Map;
import java.util.Set;
import java.util.Map.Entry;
import java.util.zip.GZIPInputStream;

/**
 * 
 * @author jmfernandez
 *
 */
public class PDBParser {
	protected final static String[] ARTIFACTS={
		"CLON",		// 'Cloning Artifact'
		"EXPR",		// 'Expression Tag'
		"INIT",		// 'Initiating Methionine'
		"LEADER",	// 'Leader Sequence'
	};
	
	protected final static int segsize=60;

	protected CIFDict dict;
	
	protected HashMap<String, Character> toOneAA;
	protected HashSet<String> notAA;
	protected HashMap<String,PDBSeq> chainadvs=new HashMap<String,PDBSeq>();
	
	protected PrintStream OUT;
	protected PrintStream AFILE;
	
	public PDBParser(File cifdict)
		throws IOException
	{
		// Let's read CIF dictionary
		dict= new CIFDict(cifdict);
		toOneAA = dict.getMapping();
		notAA = dict.getNotMapping();
	}
	
	public void mgetdbParser(File[] dirqueue, File destfile, File artifactsFile)
		throws IOException
	{
		chainadvs=new HashMap<String,PDBSeq>();
		
		// Now, let's work!
		// open($OUT,'>',$destfile)  or die("ERROR: Unable to create FASTA file $destfile");
		FileOutputStream fout = new FileOutputStream(destfile);
		BufferedOutputStream bout = new BufferedOutputStream(fout);
		OUT = new PrintStream(bout);
		
		// open($AFILE,'>',$artifactsFile)  or die("ERROR: Unable to create artifacts info file $artifactsFile");
		FileOutputStream fart = new FileOutputStream(artifactsFile);
		BufferedOutputStream bart = new BufferedOutputStream(fart);
		AFILE = new PrintStream(bart);
		
		List<File> dynDirQueue=Arrays.asList(dirqueue);
		
		try {
			while(dynDirQueue.size()>0) {
				ArrayList<File> newDynDirQueue = new ArrayList<File>();
				for(File dirname: dynDirQueue) {
					try {
						List<File> moreDirQueue = parsePDBDirectory(dirname);
						newDynDirQueue.addAll(moreDirQueue);
					} catch(IOException ioe) {
						System.err.println("WARNING: Unable to process directory "+dirname.getAbsolutePath());
						ioe.printStackTrace();
					}
				}
				dynDirQueue=newDynDirQueue;
			}
		} finally {
			AFILE.close();
			try {
				bart.close();
			} catch(IOException ioe) {
				// IgnoreIT(R)
			}
			try {
				fart.close();
			} catch(IOException ioe) {
				// IgnoreIT(R)
			}
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
	}
	
	protected List<File> parsePDBDirectory(File dirname)
		throws IOException
	{
		ArrayList<File> dirqueue = new ArrayList<File>();
		
		if(dirname.isDirectory()) {
			for(File direntry: dirname.listFiles()) {
				String direntryName=direntry.getName();
				if(direntryName.equals(".") || direntryName.equals("..")) {
					continue;
				}
				
				if(direntry.isDirectory()) {
					dirqueue.add(direntry);
				} else if(direntryName.endsWith(".ent.Z") || direntryName.endsWith(".ent.gz") || direntryName.endsWith(".ent")) {
					try {
						parsePDBFile(direntry);
					} catch(IOException ioe) {
						System.err.println("WARNING: Unable to process file "+direntry.getAbsolutePath());
						ioe.printStackTrace();
					}
				}
			}
		} else if(dirname.getName().endsWith(".ent.Z") || dirname.getName().endsWith(".ent.gz") || dirname.getName().endsWith(".ent")) {
			try {
				parsePDBFile(dirname);
			} catch(IOException ioe) {
				System.err.println("WARNING: Unable to process file "+dirname.getAbsolutePath());
				ioe.printStackTrace();
			}
		} else {
			throw new IOException(dirname.getAbsolutePath()+" is not a directory!");
		}
		
		return dirqueue;
	}
	
	protected List<PDBSeq> parsePDBFile(File direntry)
		throws IOException
	{
		return parsePDBFile(direntry,null);
	}
	
	protected List<PDBSeq> parsePDBFile(File direntry,final List<String> headers)
		throws IOException
	{
		FileInputStream fpdbh = null;
		BufferedInputStream bpdbh = null;
		GZIPInputStream gpdbh = null;
		InputStreamReader ipdbh = null;
		BufferedReader PDBH = null;
		
		ArrayList<PDBSeq> parsed = new ArrayList<PDBSeq>();
		
		// Ya he abierto el fichero, ¡vamos a leer!
		try {
			fpdbh = new FileInputStream(direntry);
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
			HashMap<String,String> chaindescs=new HashMap<String,String>();
			PDBChains artifacts= null;
			StringBuilder title=null;
			String header=null;
			String prev_chain=null;
			int prev_coord=-1;
			char prev_coord_ins=' ';
			String prev_subcomp=null;
			boolean badchain=false;
			HashSet<String> ignoreChain=new HashSet<String>();
			PDBSeq pdb = null;
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
						artifacts= new PDBChains(pdbcode, true, dict);
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
									System.err.println("JOM "+compline);
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
								System.err.println("BLAMEPDB: "+pdbcode+" "+compline);
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
							System.err.println("Jammed case!!!! "+pdbcode);
							break;
						}
					} else if(line.startsWith("SOURCE")) {
						for(StringBuilder compline: comparr) {
							if(!compline.toString().endsWith(";"))
								compline.append(';');
							
							// System.err.println("PROCE "+compline);
							String[] procres = PROCCOMP(compline.toString(),current_desc,chaindescs);
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
							artifacts.setNumModels(numModels);
					} else if(line.startsWith("REMARK 465") && line.length()>=26) {
						AFILE.println(line);
						if(doRemark465) {
							// Let's store these missing residues for further reconstruction
							String res = line.substring(15,18).trim();
							String chain = line.substring(19,20).trim();
							try {
								int pos = Integer.parseInt(line.substring(21, 26).trim());
								char pos_ins = line.charAt(26);
								artifacts.storeMissingResidue(chain, new PDBRes(res, pos, pos_ins));
							} catch(NumberFormatException nfe) {
								// NaN or NaE!?!
								System.err.println("MAYBEERROR["+pdbcode+"]R: "+line);
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
						artifacts.addMapping(localchain, db, id, startPosition, endPosition);
						
					} else if(line.startsWith("DBREF1 ")) {
						String localchain = line.substring(12,13).trim();
						PDBCoord startPosition = new PDBCoord(Integer.parseInt(line.substring(14, 18).trim()),line.charAt(18));
						PDBCoord endPosition = new PDBCoord(Integer.parseInt(line.substring(20, 24).trim()),line.charAt(24));
						String db=line.substring(26, 32).trim();
						String id=line.substring(47, 67).trim();
						artifacts.addMapping(localchain, db, id, startPosition, endPosition);
						
					} else if(line.startsWith("SEQADV ")) {
						// See PDB manual documentation about SEQADV
						String conflict=line.substring(49).trim();
						for(String artifact: ARTIFACTS) {
							// Is this artifact interesting for us?
							if(conflict.startsWith(artifact) || conflict.indexOf("\t"+artifact)!=-1) {
								AFILE.println(line.substring(7));
								
								String ires = line.substring(12,15).trim();
								String localchain = line.substring(16,17).trim();
								String lposition = line.substring(18, 22).trim();
								if(lposition.length()==0)
									System.err.println("MAYBEERROR["+pdbcode+"]S: "+line);
								else {
									PDBAmino amino = new PDBAmino(toOneAA.get(ires),Integer.parseInt(lposition),line.charAt(22));
									// Is it an insertion?
									// line.substring(22, 23);
									String db=line.substring(24, 28).trim();
									String id=line.substring(29, 38).trim();
									
									String sres = line.substring(39,42).trim();
									String sposition = line.substring(43,48).trim();
									
									if(toOneAA.containsKey(ires)) {
										artifacts.appendToArtifact(localchain, db, id, artifact, amino);
										
										// System.err.println("IRES "+ires+"("+((ireschar!=null)?ireschar:'?')+")"+" LC "+localchain+" POS "+position+" SReS "+sres+" SPOS "+sposition);
									}
								}
								
								break;
							}
						}
					} else if(line.startsWith("SEQRES ") || line.startsWith("ATOM ") || line.startsWith("HETATM ") || line.startsWith("MODEL ")) {
						readingState=1;
					}
				}
				
				if(readingState==1) {
					// We are reading sequences
					String localchain = null;
					if(line.startsWith("SEQRES ")) {
						String[] seqlines=line.substring(19,70).trim().split("\\s+");
						localchain=line.substring(11, 12).trim();
						
						// Now, let's keep the track
						if(!artifacts.appendToSeqChain(localchain, seqlines)) {
							badchain=true;
							ignoreChain.add(localchain);
						}
					} else {
						readingState=2;
					}
					// At last, let's save the fragment of chain's sequence
					if(prev_chain==null || localchain==null || !localchain.equals(prev_chain)) {
						PDBSeq anotherChain = PRINTCMD(pdbcode,prev_chain,artifacts,badchain,chaindescs,direntry);
						if(anotherChain!=null) {
							// Mapping stuff will disappear from here because it must be applied from inside
							List<PDBChain.Mapping> maplist = artifacts.getMappingList(prev_chain);
							if(maplist!=null) {
								int seqLength=anotherChain.sequence.length();
								int mappedLength=0;
								int artifactsLength=0;
								for(PDBChain.Mapping map: maplist) {
									mappedLength += map.end.sub(map.start)+1;
									List<PDBChain.Fragment> chainArtifacts = map.getFragmentList();
									if(chainArtifacts!=null) {
										for(PDBChain.Fragment artifact: chainArtifacts) {
											artifactsLength+=artifact.end.sub(artifact.start)+1;
											//System.err.println("PDB "+pdbcode+" CHAIN "+prev_chain+" START "+artifact.start+" END "+artifact.end+" REASON "+artifact.reason);
										}
									}
								}
								// if((mappedLength+artifactsLength)!=seqLength)
								//	System.err.println("KUACK!!!! "+pdbcode+"_"+prev_chain+" length is "+seqLength+" but coordinates map "+mappedLength+" and artifacts map "+artifactsLength);
							}
//								List<PDBArtifact.Fragment> chainArtifacts = map.getFragmentList();
//								if(chainArtifacts!=null) {
//									for(PDBArtifact.Fragment artifact: chainArtifacts) {
//										System.err.println("PDB "+pdbcode+" CHAIN "+prev_chain+" START "+artifact.start+" END "+artifact.end+" REASON "+artifact.reason);
//									}
//								}
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
							artifacts.setCurrentModel(modelNo);
					} else if(line.startsWith("ATOM ") || line.startsWith("HETATM")) {
						String chain = line.substring(21,22).trim();
						if(chaindescs.containsKey(chain) && !ignoreChain.contains(chain) && artifacts.isOpenAtomChain(chain)) {
							String residue = line.substring(17,20).trim();
							int coord = Integer.parseInt(line.substring(22,26).trim());
							char coord_ins=line.charAt(26);
							if(prev_chain==null || !prev_chain.equals(chain) || prev_coord!=coord || prev_coord_ins!=coord_ins) {
								boolean hasPrev=true;
								if(prev_chain==null || !prev_chain.equals(chain)) {
								/*
									// We are starting a chain, so let's pad it first
									artifacts.padFirst(chain,new PDBCoord(coord, coord_ins));
								} else if((prev_coord+1)!=coord && !(prev_coord==coord && prev_coord_ins!=coord_ins)) {
									if(artifacts.hasMissingResidues(chain)) { 
										System.err.println("ERROR: Residue coordinate mismatch! Prev: "+prev_coord+" New: "+coord);
										if(coord<prev_coord) {
											System.err.println("ERRORDEBUG["+pdbcode+"]A: "+line);
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
								
								artifacts.appendToAtomChain(chain, new PDBRes(residue, coord, coord_ins), (hasPrev)?new PDBCoord(prev_coord,prev_coord_ins):null);
								prev_chain = chain;
								prev_coord = coord;
								prev_coord_ins=coord_ins;
							}
						}
					} else if(line.startsWith("TER ")) {
						// Now, let's look for REMARKed residues beyond this limit...
						String chain = line.substring(21,22).trim();
						if(chaindescs.containsKey(chain)) {
							artifacts.padAtomBoth(chain);
							//System.err.println("DEBUG: "+pdbcode+" Chain "+chain+" TER");
						}
					} else if(line.startsWith("ENDMDL")) {
						prev_chain=null;
						prev_coord=-1;
						prev_coord_ins=' ';
					} else if(line.startsWith("END")) {
						// The right moment to compare, jarl!
						List<HashMap<String,PDBChain>> lchains=artifacts.lchains;
						
						System.err.println("REPORT "+artifacts.pdbcode);
						int modelpos=(lchains.size()>1)?1:0;
						for(HashMap<String,PDBChain> chainatoms: lchains) {
							System.err.println("Chains by   ATOM"+(modelpos==0?"":" (model "+modelpos+")")+": "+MiscHelper.join(chainatoms.keySet(), ", "));
							modelpos++;
						}
						
						HashMap<String,PDBChain> chainseqs = lchains.get(0);
						for(PDBChain entry: chainseqs.values()) {
							StringBuilder aminoseqbuilder = entry.getSeqAminos();
							if(aminoseqbuilder!=null) {
								String aminoseq = PDBChain.ClipSequence(aminoseqbuilder);
								String chainName = entry.chainName;
								modelpos=(lchains.size()>1)?1:0;
								for(HashMap<String,PDBChain> chainatoms: lchains) {
									PDBChain chain = chainatoms.get(chainName);
									StringBuilder chainseqbuilder = chain.getAminos();
									if(chainseqbuilder!=null) {
										String chainseq=PDBChain.ClipSequence(chainseqbuilder);
										boolean equalchain=chainseq.equals(aminoseq);
										System.err.println("\tCHAIN "+chainName+(modelpos==0?"":" (model "+modelpos+")")+" does"+(equalchain?" not":"")+" differ");
										if(!equalchain) {
											System.err.println("\t\tSEQRES => "+aminoseq);
											System.err.println("\t\tATOM   => "+chainseq);
										}
									}
									modelpos++;
								}
							} else {
								System.err.println("No protein sequence at "+artifacts.pdbcode+"_"+entry.chainName);
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
	
	protected PDBSeq PRINTCMD(String pdbcode, String prev_chain, PDBChains artifacts, boolean badchain, HashMap<String,String> chaindescs,File direntry)
		throws IOException
	{
		PDBSeq pdb = null;
		if(prev_chain!=null) {
			StringBuilder prev_seqB = artifacts.getSeqChain(prev_chain);
			String prev_seq = (prev_seqB!=null)?prev_seqB.toString():null;
			String chaincode = pdbcode+"_"+prev_chain;
			if(prev_seq!=null && !badchain && !prev_seq.matches("^X+$")) {
				if(!chaindescs.containsKey(prev_chain))
					System.err.println("BLAMEPDB: "+pdbcode);
				
				// First, internal storage
				if(chainadvs!=null) {
					// Let's process the sequence
					pdb = new PDBSeq(chaincode,chaindescs.get(prev_chain),new StringBuilder(prev_seq));
					pdb.features.put(PDBSeq.ORIGIN_KEY, GOPHERPrepare.PDB_LABEL);
					pdb.features.put(PDBSeq.PATH_KEY, direntry);
				}
				
				if(OUT!=null) {
					OUT.println(">PDB:"+chaincode+" mol:protein length:"+prev_seq.length()+"  "+chaindescs.get(prev_chain));
					while(prev_seq.length()>segsize) {
						OUT.println(prev_seq.substring(0, segsize));
						prev_seq = prev_seq.substring(segsize, prev_seq.length());
					}
					if(prev_seq.length()>0)
						OUT.println(prev_seq);
				}
			} else {
				System.err.println("NOTICE: "+chaincode+" is not a protein sequence");
			}
		}
		// $badchain=undef;
		
		return pdb;
	}
	
	protected String[] PROCCOMP(String compline,String current_desc,HashMap<String,String> chaindescs)
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
				System.err.println("JORL "+compline);
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
					chaindescs.put(chain, current_desc);
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
	
	public List<PDBSeq> filterByPDBHeaders(File directory,final List<String> origheaders)
		throws IOException
	{
		ArrayList<PDBSeq> survivors=new ArrayList<PDBSeq>();
		
		ArrayList<File> dynDirQueue=new ArrayList<File>();
		dynDirQueue.add(directory);
		
		while(dynDirQueue.size()>0) {
			ArrayList<File> newDynDirQueue = new ArrayList<File>();
			for(File dirname: dynDirQueue) {
				try {
					List<File> moreDirQueue = filterByPDBHeaders(dirname,origheaders,survivors);
					newDynDirQueue.addAll(moreDirQueue);
				} catch(IOException ioe) {
					System.err.println("WARNING: Unable to process directory "+dirname.getAbsolutePath());
					ioe.printStackTrace();
				}
			}
			dynDirQueue=newDynDirQueue;
		}
	
		return survivors;
	}
	
	protected List<File> filterByPDBHeaders(File directory,final List<String> headers,ArrayList<PDBSeq> survivors)
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
			} else if(direntryName.endsWith(".ent.Z") || direntryName.endsWith(".ent.gz")) {
				try {
					survivors.addAll(parsePDBFile(direntry));
				} catch(IOException ioe) {
					System.err.println("WARNING: Unable to process file "+direntry.getAbsolutePath());
					ioe.printStackTrace();
				}
			}
		}
		
		return dirqueue;
			
	}
	
	public final static void main(String[] args)
		throws Throwable
	{
		if(args.length>3) {
			File destfile=new File(args[0]);
			File artifactsFile=new File(args[1]);
			File cifdict=new File(args[2]);
			ArrayList<File> dq=new ArrayList<File>();
			for(String arg:MiscHelper.subList(args, 3)) {
				dq.add(new File(arg));
			}
			File[] dirqueue=new File[] {};
			dirqueue=dq.toArray(dirqueue);
			PDBParser p = new PDBParser(cifdict);
			p.mgetdbParser(dirqueue, destfile, artifactsFile);
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
