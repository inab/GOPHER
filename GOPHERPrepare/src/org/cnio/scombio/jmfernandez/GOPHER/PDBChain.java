package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.logging.Logger;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
// import java.util.Map.Entry;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class PDBChain {
	protected final static Logger LOG = Logger.getLogger(PDBChain.class.getName());
	static {
		LOG.setUseParentHandlers(false);
	};
	
	// The residues were read from the atom chains
	protected final static int SEQ_RES_CHAIN=0;
	// The residues were read from the PDB sequence field
	protected final static int SEQ_SEQ_CHAIN=1;
	// The sequence has (hopefully) its cloning artifacts masked
	protected final static int SEQ_MASKED_CHAIN=2;
	// The sequences has both its cloning artifacts and sequence
	// fragments with no structural information, masked
	protected final static int SEQ_MASKED_STRUCT_CHAIN=3;
	
	protected final static char CHAIN_SEP='_';
	
	protected final static int MINSEQLENGTH=30;

	// The beginning of the protein sequence
	protected final static int HMIN=3;
	protected final static int N_TERM_HAREA=30;
	protected final static String[] N_TERM={
		"M.*[HX]{"+HMIN+",}.*ENLYF[QG]",
		"[HX]{"+HMIN+",}.*ENLYF[QG]",
		"M.*[HX]{"+HMIN+",}.*GLVPRGS",
		"[HX]{"+HMIN+",}.*GLVPRGS",
	};
	
	// The end of the protein sequence
	protected final static int C_TERM_HAREA=20;
	protected final static String[] C_TERM={
		"LE[HX]{"+HMIN+",}",
		"EG[HX]{"+HMIN+",}",
		"GS?[HX]{"+HMIN+",}",
		"R[HX]{"+HMIN+",}",
		"[HX]{5,}",
	};
	
	protected static Pattern[] N_TERM_PAT=new Pattern[N_TERM.length];
	protected static Pattern[] C_TERM_PAT=new Pattern[C_TERM.length];
	
	static {
		int patpos=0;
		for(String pat: N_TERM) {
			N_TERM_PAT[patpos++]=Pattern.compile("^"+pat);
		}
		
		patpos=0;
		for(String pat: C_TERM) {
			C_TERM_PAT[patpos++]=Pattern.compile(pat+"$");
		}
	};
	
	/**
		This static method takes a one-line sequence, and it removes
		cloning artifacts from N and C terminal.
		@param curCharSeq The sequence to be pruned of cloning artifacts
		@return The pruned sequence
	*/
	protected static CharSequence PruneSequence(CharSequence curCharSeq) {
		if(curCharSeq==null)  return null;
		
		if(curCharSeq.length()>=MINSEQLENGTH) {
			boolean foundPat;
		
			// Let's prune those cloning artifacts!!!
			do {
				foundPat=false;
				int cutlen=curCharSeq.length();
				int firstPos=cutlen-C_TERM_HAREA;
				CharSequence tail = curCharSeq.subSequence(firstPos,cutlen);
				for(Pattern pat: C_TERM_PAT) {
					Matcher m=pat.matcher(tail);
					if(m.find()) {
						curCharSeq=curCharSeq.subSequence(0,firstPos+m.start());
						
						foundPat=true;
						break;
					}
				}
			} while(foundPat && curCharSeq.length()>=MINSEQLENGTH);
			
			// On both sides!
			if(curCharSeq.length()>=MINSEQLENGTH) {
				do {
					foundPat=false;
					CharSequence head = curCharSeq.subSequence(0,N_TERM_HAREA);
					for(Pattern pat: N_TERM_PAT) {
						Matcher m=pat.matcher(head);
						if(m.find()) {
							curCharSeq=curCharSeq.subSequence(m.end(),curCharSeq.length());
							
							foundPat=true;
							break;
						}
					}
				} while(foundPat && curCharSeq.length()>=MINSEQLENGTH);
				
				// Final check
				if(curCharSeq.length()<MINSEQLENGTH) {
					curCharSeq=null;
				}
			}
		} else {
			curCharSeq=null;
		}
	
		return curCharSeq;
	}

	/**
	 * This method removes from an aminoacid sequence the unknown aminoacids from
	 * the beginning and end
	 * @param seq A StringBuilder object which contains the aminoacid sequence
	 * @return The possibly clipped sequence
	 */
	protected static CharSequence ClipSequence(final CharSequence seq) {
		return ClipSequence(seq,null);
	}
	
	/**
	 * This method removes from an aminoacid sequence the unknown aminoacids from
	 * the beginning and end
	 * @param seq A StringBuilder object which contains the aminoacid sequence
	 * @param hiLo A list where to store the low and high marks
	 * @return The possibly clipped sequence
	 */
	protected static CharSequence ClipSequence(final CharSequence seq,final List<Integer> hiLo) {
		if(seq==null)  return null;
		
		int minSub=0;
		int maxSub=seq.length();
		
		for(int cbi=0;cbi<maxSub;cbi++) {
			if(seq.charAt(cbi)!=PDBAmino.UnknownAmino) {
				break;
			}
			minSub++;
		}

		for(int cbi=maxSub-1;cbi>=minSub;cbi--) {
			if(seq.charAt(cbi)!=PDBAmino.UnknownAmino) {
				maxSub=cbi+1;
				break;
			}
		}
		
		// This information is needed on clipping comparisons
		if(hiLo!=null) {
			hiLo.clear();
			hiLo.add(minSub);
			hiLo.add(maxSub);
		}
		
		return (minSub<maxSub)?seq.subSequence(minSub,maxSub):"";
	}
	
	protected final String pdbcode;
	protected final int modelNo;
	protected final String chainName;
	protected final Map<String, Character> toOneAA;
	protected final Set<String> notAA;
	protected final boolean ignoreReason;
	protected String description;
	protected StringBuilder[] chainseqs;
	protected List<PDBAmino> chainAminos;
	// Segments of missing residues
	protected List<LabelledSegment<PDBAmino>> missingList;
	// Leftmost residues of the segment, ordered
	protected TreeMap<PDBCoord,Integer> missingLeft;
	// Rightmost residues of the segment, ordered
	protected TreeMap<PDBCoord,Integer> missingRight;
	
	protected PDBCoord missingBeforeFirst;
	protected double missingBeforeFirstDistance;
	protected boolean[] isJammeds;
	protected boolean isTERChain;
	protected ArrayList<Mapping> artifactMapping;
	protected HashMap<String,Mapping> artifactHash;
	protected HashSet<PDBCoord> artifactSet;
	
	protected boolean useMaskingHeuristics;
	protected boolean missingUnpopulated;
	
	public PDBChain(final String pdbcode,final String chainName, final Map<String, Character> toOneAA, final Set<String> notAA, final boolean ignoreReason) {
		this(pdbcode, chainName, toOneAA, notAA, ignoreReason, null);
	}
	
	public PDBChain(final String pdbcode, final String chainName, final Map<String, Character> toOneAA, final Set<String> notAA, final boolean ignoreReason, List<LabelledSegment<PDBAmino>> missingList) {
		this(pdbcode, 1, chainName, toOneAA, notAA, ignoreReason, missingList);
	}
	
	public PDBChain(final String pdbcode,final int modelNo, final String chainName, final Map<String, Character> toOneAA, final Set<String> notAA, final boolean ignoreReason) {
		this(pdbcode, modelNo, chainName, toOneAA, notAA, ignoreReason,null);
	}
	
	public PDBChain(final String pdbcode, final int modelNo, final String chainName, final Map<String, Character> toOneAA, final Set<String> notAA, final boolean ignoreReason, List<LabelledSegment<PDBAmino>> missingList) {
		this.pdbcode = pdbcode;
		this.modelNo = modelNo;
		this.chainName = chainName;
		this.toOneAA = toOneAA;
		this.notAA = notAA;
		this.ignoreReason=ignoreReason;
		chainseqs = new StringBuilder[] { null, null, null, null };
		chainAminos=new ArrayList<PDBAmino>();
		initMissing(missingList);
		artifactMapping=new ArrayList<Mapping>();
		artifactHash=new HashMap<String,Mapping>();
		artifactSet = new HashSet<PDBCoord>();
		isTERChain=false;
		isJammeds = new boolean[] { false, false, false, false };
		description = null;
		useMaskingHeuristics=false;
	}
	
	private void initMissing(List<LabelledSegment<PDBAmino>> missingList) {
		this.missingList = missingList!=null?missingList:new ArrayList<LabelledSegment<PDBAmino>>();
		missingLeft = new TreeMap<PDBCoord,Integer>();
		missingRight = new TreeMap<PDBCoord,Integer>();
		missingBeforeFirst = null;
		missingBeforeFirstDistance = -1.0;
		missingUnpopulated = true;
	}
	
	private void populateMissing() {
		// Reset
		if(missingUnpopulated) {
			missingUnpopulated = false;
			// this should be done if we reuse the objects
			// missingLeft.clear();
			// missingRight.clear();
			
			int segmentPos=0;
			for(LabelledSegment<PDBAmino> missingSegment: missingList) {
				LabelledSegment.TreeSegmentPopulation(missingSegment,segmentPos,missingLeft,missingRight);
				segmentPos++;
			}
		}
	}
	
	public String getDescription() {
		return description;
	}
	
	public void setDescription(String description) {
		this.description = description;
	}
	
	public String getChainName() {
		return chainName;
	}
	
	public String getName() {
		return pdbcode+CHAIN_SEP+chainName;
	}
	
	public List<LabelledSegment<PDBAmino>> getMissingList() {
		return missingList;
	}
	
	public boolean appendToSeqChain(String... residues) {
		if(isTERChain)
			return false;
		
		int chainIdx=SEQ_SEQ_CHAIN;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			StringBuilder piece=new StringBuilder();
			for(String ires: residues) {
				if(ires.length()==3) {
				// Por definición en PDB, los aminoácidos se expresan
				// en códigos de 3 letras
					if(toOneAA.containsKey(ires)) {
						piece.append(toOneAA.get(ires));
					} else if(notAA.contains(ires)) {
						//if(length($localseq)>0 || (defined($prev_chain) && defined($prev_seq) && $localchain eq $prev_chain && length($prev_seq)>0)) {
							LOG.warning("Jammed chain: '"+ires+"' in "+getName());
							piece.append(PDBAmino.UnknownAmino);
						//} else {
						//	$localseq=undef;
						//	last;
						//}
					} else {
						piece.append(PDBAmino.UnknownAmino);
						LOG.warning("Unknown aminoacid '"+ires+"' in "+getName()+"!!!");
					}
				//} else if(length($ires)==1) {
				//	# Y los nucleótidos en códigos de una letra
				//	$localseq=undef;
				//	last;
				} else {
					// print STDERR "WARNING: Jammed file: '$ires' in chain '$localchain' in $fullentry\n";
					retval = false;
					isJammeds[chainIdx] = true;
					chainseqs[chainIdx] = null;
					break;
				}
			}
			if(!isJammeds[chainIdx])
				chainseqs[chainIdx].append(piece);
		}
		
		return retval;
	}

	public boolean appendToResChain(PDBRes... residues) {
		if(isTERChain)
			return false;
		
		int chainIdx=SEQ_RES_CHAIN;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			StringBuilder piece=new StringBuilder();
			ArrayList<PDBAmino> pieceList = new ArrayList<PDBAmino>();
			for(PDBRes pres: residues) {
				String ires = pres.res;
				if(ires.length()==3) {
				// Por definición en PDB, los aminoácidos se expresan
				// en códigos de 3 letras
					char oneAmino;
					if(toOneAA.containsKey(ires)) {
						oneAmino=toOneAA.get(ires);
					} else if(notAA.contains(ires)) {
						//if(length($localseq)>0 || (defined($prev_chain) && defined($prev_seq) && $localchain eq $prev_chain && length($prev_seq)>0)) {
							LOG.warning("Jammed chain: '"+ires+"' at position "+pres.coord+pres.coord_ins+" in "+getName());
							oneAmino=PDBAmino.UnknownAmino;
						//} else {
						//	$localseq=undef;
						//	last;
						//}
					} else {
						LOG.warning("Unknown aminoacid '"+ires+"' at "+pres.coord+pres.coord_ins+"' in "+getName()+"!!!");
						oneAmino=PDBAmino.UnknownAmino;
					}
					piece.append(oneAmino);
					pieceList.add(new PDBAmino(oneAmino,pres));
				//} else if(length($ires)==1) {
				//	# Y los nucleótidos en códigos de una letra
				//	$localseq=undef;
				//	last;
				} else if(chainseqs[chainIdx].length()>0 || piece.length()>0) {
					// print STDERR "WARNING: Jammed file: '$ires' in chain '$localchain' in $fullentry\n";
					retval = false;
					isJammeds[chainIdx] = true;
					chainseqs[chainIdx] = null;
					break;
				//} else {
				//	isJammeds[chainIdx] = chainseqs[chainIdx].length()>0;
				//	chainseqs[chainIdx] = null;
				//	break;
				}
			}
			if(retval) {
				if(piece.length()>0) {
					chainseqs[chainIdx].append(piece);
					chainAminos.addAll(pieceList);
				} else {
					retval = false;
				}
			}
		}
		
		return retval;
	}

	protected boolean appendToChain(boolean isSeq, PDBAmino... residues) {
		if(isTERChain)
			return false;
		
		int chainIdx=isSeq?SEQ_SEQ_CHAIN:SEQ_RES_CHAIN;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			char[] piece=new char[residues.length];
			int ipiece=0;
			for(PDBAmino pres: residues) {
				piece[ipiece]=pres.amino;
				ipiece++;
			}
			chainseqs[chainIdx].append(piece);
			chainAminos.addAll(Arrays.asList(residues));
		}
		
		return retval;
	}

	// Just before appending, looking for missing...
	public boolean appendToResChain(PDBRes residue,PDBCoord prev_coord) {
		if(isTERChain)
			return false;
		
		if(!isJammeds[SEQ_RES_CHAIN] && chainseqs[SEQ_RES_CHAIN] == null)
			chainseqs[SEQ_RES_CHAIN] = new StringBuilder();
		
		boolean retval = !isJammeds[SEQ_RES_CHAIN];
		
		if(retval) {
			if(hasMissingResidues()) {
				// Time to populate the other structures (only once!)
				populateMissing();
/*				Entry<PDBCoord,Integer> highMark=missingRight.lowerEntry(residue);
				if(highMark!=null) {
					// Need this one for checks
					if(prev_coord==null) {
						missingBeforeFirst = highMark.getKey();
						missingBeforeFirstDistance = residue.sub(missingBeforeFirst);
					}
					
					//LOG.finest("DEBUG PDBCOORD:"+new PDBCoord(highMark.getKey())+" PDBAMINO: "+new PDBCoord(highMark.getValue())+" PDBSEARCH: "+new PDBCoord(residue));
					PDBCoord highRef= highMark.getKey();
					// Must be the value, otherwise it can give a NPE
					int highPos=highMark.getValue();
					int lowPos=highPos+1;
					boolean newFirstMissing=false;
					if(prev_coord!=null) {
						
						//lowPos=0;
						LOG.finest("DEBUG PDB "+getName()+" HIGH "+highPos+" RES "+residue+new PDBCoord(residue));
					} else {
					
						Entry<PDBCoord, Integer> lowMark=missingLeft.higherEntry(prev_coord);
						if(lowMark!=null) {
							int tmpLowPos=lowMark.getValue();
							if(tmpLowPos<=highPos && (missingBeforeFirst!=highRef || residue.sub(highRef)<missingBeforeFirstDistance)) {
								lowPos = tmpLowPos;
								// No one is lower just now...
								if(missingBeforeFirst==highRef) {
									missingBeforeFirst=null;
									missingBeforeFirstDistance=-1;
									newFirstMissing=true;
								}
							}
						}
					}
					if(lowPos<=highPos) {
						retval=true;
						for(List<PDBAmino> missingSegment: missingList.subList(lowPos,highPos+1)) {
							PDBAmino[] toAppend = missingSegment.toArray(new PDBAmino[0]);
							boolean tmpretval = appendToChain(false,toAppend);
							if(tmpretval) {
								// Removing already used missing aminoacids from TreeMap
								missingLeft.remove(toAppend[0]);
								missingRight.remove(toAppend[toAppend.length-1]);
							}
							retval &= tmpretval;
						}
						if(retval && newFirstMissing) {
							// And now, electing the new missing residue lower than the first known one
							PDBCoord first = chainAminos.get(0);
							Entry<PDBCoord,Integer> newMissingBefore=missingRight.lowerEntry(first);
							if(newMissingBefore!=null) {
								missingBeforeFirst = newMissingBefore.getKey();
								missingBeforeFirstDistance=first.sub(missingBeforeFirst);
							}
						}
					}
				}
*/			}
			
			// if(retval)
				retval = appendToResChain(residue);
		}
		
		return retval;
	}

	protected boolean prependToChain(PDBAmino... residues) {
		return prependToChain(false,residues);
	}
	
	protected boolean prependToSeqChain(PDBAmino... residues) {
		return prependToChain(true,residues);
	}
	
	protected boolean prependToChain(boolean isSeq, PDBAmino... residues) {
		if(isTERChain)
			return false;
		
		int chainIdx=isSeq?SEQ_SEQ_CHAIN:SEQ_RES_CHAIN;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			char aminos[]=new char[residues.length];
			int iamin=0;
			for(PDBAmino amino: residues) {
				aminos[iamin]=amino.amino;
				iamin++;
			}
			chainseqs[chainIdx].insert(0,aminos);
			chainAminos.addAll(0,Arrays.asList(residues));
		}
		
		return retval;
	}
	
	public boolean padChain(int numres) {
		return padChain(false,numres);
	}
	
	public boolean padSeqChain(int numres) {
		return padChain(true,numres);
	}
	
	protected boolean padChain(boolean isSeq, int numres) {
		if(isTERChain)
			return false;
		
		int chainIdx=isSeq?SEQ_SEQ_CHAIN:SEQ_RES_CHAIN;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			char[] piece=new char[numres];
			for(int counter=0; counter<numres; counter++) {
				piece[counter]=PDBAmino.UnknownAmino;
			}
			chainseqs[chainIdx].append(piece);
		}
		
		return retval;
	}
	
	public boolean prepadChain(int numres) {
		return prepadChain(false,numres);
	}
	
	public boolean prepadSeqChain(int numres) {
		return prepadChain(true,numres);
	}
	
	protected boolean prepadChain(boolean isSeq, int numres) {
		if(isTERChain)
			return false;
		
		int chainIdx=isSeq?SEQ_SEQ_CHAIN:SEQ_RES_CHAIN;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			char[] piece=new char[numres];
			for(int counter=0; counter<numres; counter++) {
				piece[counter]=PDBAmino.UnknownAmino;
			}
			chainseqs[chainIdx].insert(0, piece);
		}
		
		return retval;
	}
	
	public boolean hasMissingResidues() {
		return missingList!=null && missingList.size()>0;
		//return missingList!=null && (missing==null || missing.size()>0);
	}
	
	public boolean isTER() {
		return isTERChain;
	}
	
	public boolean isOpen() {
		return !isTERChain;
	}
	
	protected void putTER() {
		isTERChain=true;
	}
	
	public String toString(boolean isSeq) {
		int chainIdx=isSeq?SEQ_SEQ_CHAIN:SEQ_RES_CHAIN;
		return (chainseqs[chainIdx]!=null)?chainseqs[chainIdx].toString():null;
	}
	
	public String toString() {
		return chainseqs[SEQ_MASKED_CHAIN]!=null?chainseqs[SEQ_MASKED_CHAIN].toString():(chainseqs[SEQ_RES_CHAIN]!=null?chainseqs[SEQ_RES_CHAIN].toString():(chainseqs[SEQ_SEQ_CHAIN]!=null?chainseqs[SEQ_SEQ_CHAIN].toString():null));
	}
	
	public boolean storeMissingResidue(PDBRes residue) {
		boolean good=false;
		
		String res = residue.res;
		if(res.length()==3) {
			if(!hasMissingResidues()) {
				missingList.add(new LabelledSegment<PDBAmino>(LabelledSegment.MISSING_SEGMENT_KIND));
			}
			
			char aminochar=PDBAmino.UnknownAmino;
		// Por definición en PDB, los aminoácidos se expresan
		// en códigos de 3 letras
			if(toOneAA.containsKey(res)) {
				aminochar = toOneAA.get(res);
			} else if(notAA.contains(res)) {
				//if(length($localseq)>0 || (defined($prev_chain) && defined($prev_seq) && $localchain eq $prev_chain && length($prev_seq)>0)) {
				LOG.warning("Jammed remark chain: '"+res+"' at "+residue.coord+residue.coord_ins+" in "+getName());
				//} else {
				//	$localseq=undef;
				//	last;
				//}
			} else {
				LOG.warning("Unknown remark aminoacid '"+res+"' at "+residue.coord+residue.coord_ins+" in "+getName()+"!!!");
			}
			PDBAmino amino=new PDBAmino(aminochar,residue);
			// Order of these sentences is very important!
			LabelledSegment<PDBAmino> result = missingList.get(missingList.size()-1).add(amino);
			if(result!=null) {
				// At last, save it here
				missingList.add(result);
			}
			
			good=true;
		//} else if(length($ires)==1) {
		//	# Y los nucleótidos en códigos de una letra
		//	$localseq=undef;
		//	last;
		}
		
		return good;
	}
	
	public boolean isEmpty() {
		return (chainseqs[SEQ_RES_CHAIN]==null || chainseqs[SEQ_RES_CHAIN].length()==0) && (chainseqs[SEQ_SEQ_CHAIN]==null || chainseqs[SEQ_SEQ_CHAIN].length()==0);
	}
	
	/**
	 * Atom chain is terminated, so processing related to missing aminoacids and clone artifact masking can be done
	 */
	public boolean doTER() {
		if(isTERChain || isJammeds[SEQ_SEQ_CHAIN] || isEmpty())
			return false;
		
		// Strange cases, where there is no SEQRES residue but there are ATOM ones!
		if(chainseqs[SEQ_RES_CHAIN]!=null && chainseqs[SEQ_RES_CHAIN].length()>0 && (chainseqs[SEQ_SEQ_CHAIN]==null || chainseqs[SEQ_SEQ_CHAIN].length()==0))
			chainseqs[SEQ_SEQ_CHAIN] = new StringBuilder(chainseqs[SEQ_RES_CHAIN]);
		
		boolean retval = false;
		
		// Masking is only needed when there is any known cloning artifact or unknown aminos
		if((hasMissingResidues() || artifactSet.size()>0) && chainAminos.size()>0) {
			List<LabelledSegment<PDBAmino>> aminoSegments=null;
			if(hasMissingResidues()) {
				// First, segment detection in sequence
				TreeMap<PDBCoord,Integer> atomLeftCoord = new TreeMap<PDBCoord,Integer>();
				TreeMap<PDBCoord,Integer> atomRightCoord = new TreeMap<PDBCoord,Integer>();
				
				List<LabelledSegment<PDBAmino>> newAminoSegments=null;
				try {
					newAminoSegments=LabelledSegment.SegmentsDetection(chainAminos,atomLeftCoord,atomRightCoord);
				} catch(IndexOutOfBoundsException iooe) {
					System.err.println("JOE "+getName()+" "+modelNo);
					throw iooe;
				}
				aminoSegments=new ArrayList<LabelledSegment<PDBAmino>>(newAminoSegments);
				
				// 2A, missing segments positioning just before known sequence segments
				List<Integer> missingLost=new ArrayList<Integer>();
				int missingSeenIdx=0;
				int missingInsertedIdx=-1;
				
				// Missing segments location is an iterative process
				while(missingSeenIdx<missingList.size()) {
					int aminoIdx=missingInsertedIdx+1;
					// Go away when we are out of range
					if(aminoIdx>=aminoSegments.size())
						break;
					
					LabelledSegment<PDBAmino> missingSeen=missingList.get(missingSeenIdx);
					PDBAmino missingSeenFirst=missingSeen.firstCoord();
					PDBAmino missingSeenLast=missingSeen.lastCoord();
					
					// Missing segments must be placed in the same order as they appear
					// in the REMARK 465 sections inside PDB files
					for(;aminoIdx<aminoSegments.size();) {
						LabelledSegment<PDBAmino> aminoSegment=aminoSegments.get(aminoIdx);
						
						// Checking assembly compatibility conditions is tedious
						boolean doInsertion=false;
						boolean before=true;
						if(missingSeen!=null) {
							char segmentTypeSelector=LabelledSegment.INS_TREND_UNKNOWN;
							// Same known kind, no increasing or decreasing 
							if(aminoSegment.kindINS==missingSeen.kindINS) {
								segmentTypeSelector=aminoSegment.kindINS;
							} else if(missingSeen.prevINS==LabelledSegment.INS_TREND_UNKNOWN && aminoSegment.prevINS!=LabelledSegment.INS_TREND_UNKNOWN) {
								segmentTypeSelector=aminoSegment.prevINS;
							} else if(aminoSegment.prevINS==LabelledSegment.INS_TREND_UNKNOWN && missingSeen.prevINS!=LabelledSegment.INS_TREND_UNKNOWN) {
								segmentTypeSelector=missingSeen.prevINS;
							} else if(aminoSegment.kindINS==LabelledSegment.INS_FORWARD_START && missingSeen.prevINS==LabelledSegment.INS_TREND_INCREASING) {
								segmentTypeSelector=LabelledSegment.INS_TREND_SLOPE;
							}
							switch(segmentTypeSelector) {
								case LabelledSegment.INS_TREND_UNKNOWN:
									// We did not know how to handle this situation, so we give up :-(
									break;
								case LabelledSegment.INS_TREND_SLOPE:
									if(
										missingSeenFirst.coord_ins==LabelledSegment.INS_TREND_START &&
										missingSeenFirst.coord==aminoSegment.lastCoord().coord
									) {
										doInsertion=true;
										before=false;
									}
									break;
								case LabelledSegment.INS_TREND_INCREASING:
									if(
										(
											missingSeenLast.coord==aminoSegment.firstCoord().coord &&
											(missingSeenLast.coord_ins+1)==aminoSegment.firstCoord().coord_ins
										) || (
											(missingSeenLast.coord+1)==aminoSegment.firstCoord().coord &&
											missingSeenLast.coord_ins==LabelledSegment.INS_TREND_END &&
											aminoSegment.firstCoord().coord_ins==LabelledSegment.INS_TREND_START
										)
									) {
										doInsertion=true;
										before=true;
									} else if(
										(
											missingSeenFirst.coord==aminoSegment.lastCoord().coord &&
											(aminoSegment.lastCoord().coord_ins+1)==missingSeenFirst.coord_ins
										) || (
											missingSeenFirst.coord==(aminoSegment.lastCoord().coord+1) &&
											aminoSegment.lastCoord().coord_ins==LabelledSegment.INS_TREND_END &&
											missingSeenFirst.coord_ins==LabelledSegment.INS_TREND_START
										)
									) {
										doInsertion=true;
										before=false;
									}
									break;
								case LabelledSegment.INS_TREND_DECREASING:
									if(
										(
											missingSeenLast.coord==aminoSegment.firstCoord().coord &&
											missingSeenLast.coord_ins==(aminoSegment.firstCoord().coord_ins+1)
										) || (
											missingSeenLast.coord==(aminoSegment.firstCoord().coord+1) &&
											missingSeenLast.coord_ins==LabelledSegment.INS_TREND_START &&
											aminoSegment.firstCoord().coord_ins==LabelledSegment.INS_TREND_END
										)
									) {
										doInsertion=true;
										before=true;
									} else if(
										(
											missingSeenFirst.coord==aminoSegment.lastCoord().coord &&
											aminoSegment.lastCoord().coord_ins==(missingSeenFirst.coord_ins+1)
										) || (
											(missingSeenFirst.coord+1)==aminoSegment.lastCoord().coord &&
											aminoSegment.lastCoord().coord_ins==LabelledSegment.INS_TREND_START &&
											missingSeenFirst.coord_ins==LabelledSegment.INS_TREND_END
										)
									) {
										doInsertion=true;
										before=false;
									}
									break;
								default:
									boolean isBackwards=LabelledSegment.IsBackwards(segmentTypeSelector);
									if(isBackwards) {
										if(missingSeenLast.coord==(aminoSegment.firstCoord().coord+1) ||
												aminoSegment.lastCoord().coord==(missingSeenFirst.coord+1)
											) {
												doInsertion=true;
												before=missingSeenLast.coord==(aminoSegment.firstCoord().coord+1);
											}
									} else {
										if((missingSeenLast.coord+1)==aminoSegment.firstCoord().coord ||
												(aminoSegment.lastCoord().coord+1)==missingSeenFirst.coord
											) {
												doInsertion=true;
												before=(missingSeenLast.coord+1)==aminoSegment.firstCoord().coord;
											}
									}
									break;
							}
						}
						
						// At last, we are allowed to add the segment, nice!
						if(doInsertion) {
							// Store missingSegment
							missingInsertedIdx=aminoIdx+(before?0:1);
							aminoSegments.add(missingInsertedIdx, missingSeen);
	
							// Next segment index
							aminoIdx+=2;
							
							// Get a new missing segment
							missingSeenIdx++;
							if(missingSeenIdx<missingList.size()) {
								missingSeen=missingList.get(missingSeenIdx);
								missingSeenFirst=missingSeen.firstCoord();
	
								// It is very ugly checking AGAIN here, but so
								// we can surely discard the segment
								doInsertion=false;
								if(before) {
									char segmentTypeSelector=LabelledSegment.INS_TREND_UNKNOWN;
									
									// Same known kind, no increasing or decreasing 
									if(aminoSegment.kindINS==missingSeen.kindINS) {
										segmentTypeSelector=aminoSegment.kindINS;
									} else if(missingSeen.prevINS==LabelledSegment.INS_TREND_UNKNOWN && aminoSegment.prevINS!=LabelledSegment.INS_TREND_UNKNOWN) {
										segmentTypeSelector=aminoSegment.prevINS;
									} else if(aminoSegment.prevINS==LabelledSegment.INS_TREND_UNKNOWN && missingSeen.prevINS!=LabelledSegment.INS_TREND_UNKNOWN) {
										segmentTypeSelector=missingSeen.prevINS;
									} else if(aminoSegment.kindINS==LabelledSegment.INS_FORWARD_START && missingSeen.prevINS==LabelledSegment.INS_TREND_INCREASING) {
										segmentTypeSelector=LabelledSegment.INS_TREND_SLOPE;
									}
									switch(segmentTypeSelector) {
										case LabelledSegment.INS_TREND_UNKNOWN:
											// We did not know how to handle this situation, so we give up :-(
											break;
										case LabelledSegment.INS_TREND_SLOPE:
											if(
												missingSeenFirst.coord_ins==LabelledSegment.INS_TREND_START &&
												missingSeenFirst.coord==aminoSegment.lastCoord().coord
											) {
												doInsertion=true;
												before=false;
											}
											break;
										case LabelledSegment.INS_TREND_INCREASING:
											if(
												(
													missingSeenFirst.coord==aminoSegment.lastCoord().coord &&
													(aminoSegment.lastCoord().coord_ins+1)==missingSeenFirst.coord_ins
												) || (
													missingSeenFirst.coord==(aminoSegment.lastCoord().coord+1) &&
													aminoSegment.lastCoord().coord_ins==LabelledSegment.INS_TREND_END &&
													missingSeenFirst.coord_ins==LabelledSegment.INS_TREND_START
												)
											) {
												doInsertion=true;
												before=false;
											}
											break;
										case LabelledSegment.INS_TREND_DECREASING:
											if(
												(
													missingSeenFirst.coord==aminoSegment.lastCoord().coord &&
													aminoSegment.lastCoord().coord_ins==(missingSeenFirst.coord_ins+1)
												) || (
													(missingSeenFirst.coord+1)==aminoSegment.lastCoord().coord &&
													aminoSegment.lastCoord().coord_ins==LabelledSegment.INS_TREND_START &&
													missingSeenFirst.coord_ins==LabelledSegment.INS_TREND_END
												)
											) {
												doInsertion=true;
												before=false;
											}
											break;
										default:
											boolean isBackwards=LabelledSegment.IsBackwards(segmentTypeSelector);
											if(isBackwards) {
												if(aminoSegment.lastCoord().coord==(missingSeenFirst.coord+1)) {
													doInsertion=true;
													before=false;
												}
											} else {
												if((aminoSegment.lastCoord().coord+1)==missingSeenFirst.coord) {
													doInsertion=true;
													before=false;
												}
											}
											break;
									}
								}
								
								// Two missing segments have been placed in a row, wow!
								if(doInsertion) {
									missingInsertedIdx=aminoIdx;
									aminoSegments.add(aminoIdx,missingSeen);
									aminoIdx++;
									missingSeenIdx++;
									if(missingSeenIdx<missingList.size()) {
										missingSeen=missingList.get(missingSeenIdx);
										missingSeenFirst=missingSeen.firstCoord();
										missingSeenLast=missingSeen.lastCoord();
									} else {
										missingSeen=null;
									}
								} else {
									missingSeenLast=missingSeen.lastCoord();
								}
							} else {
								// No more entries 8-)
								missingSeen=null;
							}
						} else {
							// And the segment is just here
							aminoIdx++;
						}
					}
					
					// We were not able to put it in its right place
					// so we have to register the missing segment and skip it
					if(missingSeenIdx<missingList.size()) {
						missingLost.add(missingSeenIdx);
						missingSeenIdx++;
					}
				}
				
				if(missingLost.size()>0) {
/*					// 2B, missing segments positioning INSIDE known sequence segments
					// It is a very bad idea, but it is desperation
					for(LabelledSegment<PDBAmino> aminoSegment: aminoSegments) {
						if(missingSeen!=null &&
							aminoSegment.segmentKind!= missingSeen.segmentKind &&
							aminoSegment.prevINS==LabelledSegment.INS_FORWARD_START && missingSeen.prevINS==LabelledSegment.INS_TREND_INCREASING &&
							aminoSegment.isInside(missingSeenLast)
						) {
							aminoSegment.insertSegment(missingSeen);
							
							// Get a new missing segment
							missingSeenIdx++;
							if(missingSeenIdx<missingList.size()) {
								missingSeen=missingList.get(missingSeenIdx);
								missingSeenLast=missingSeen.segment.get(missingSeen.segment.size()-1);
							} else {
								// No more entries 8-)
								missingSeen=null;
							}
						} else {
							// And the segment is just here
							aminoSegments.add(aminoSegment);
						}
					}
*/
					// 2C, missing segments, to the beginning or to the end, depending on what happened
					// They are most of times misplaced, because they should be in order
					int iMis=0;
					for(;iMis<missingLost.size() && missingLost.get(iMis)==iMis;iMis++) {
					}
					if(iMis>0) {
						// All the consecutive unknown segments from the beginning, can be first (just guessing)
						aminoSegments.addAll(0,missingList.subList(0, iMis));
					}
					if(iMis<missingLost.size()) {
						// Other segments should go to the end, but they are most of times misplaced
						for(Integer missingElemIdx: missingLost.subList(iMis, missingLost.size())) {
							aminoSegments.add(missingList.get(missingElemIdx));
						}
					}
				}
			} else {
				aminoSegments=new ArrayList<LabelledSegment<PDBAmino>>();
				aminoSegments.add(new LabelledSegment<PDBAmino>(chainAminos));
			}
			
			// Last, Building the sequence, just unmasked, masked and not structure masked
			StringBuilder rebuiltSequence=new StringBuilder();
			StringBuilder rebuiltPatchedSequence=new StringBuilder();
			StringBuilder rebuiltPatchedStructSequence=new StringBuilder();
			for(LabelledSegment<PDBAmino> anAminoSegment: aminoSegments) {
				boolean isLostSegment = anAminoSegment.segmentKind == LabelledSegment.MISSING_SEGMENT_KIND;
				for(PDBAmino anAmino: anAminoSegment.segment) {
					rebuiltSequence.append(anAmino.amino);
					char patchedAmino = artifactSet.contains(anAmino)?PDBAmino.UnknownAmino:anAmino.amino;
					rebuiltPatchedSequence.append(patchedAmino);
					rebuiltPatchedStructSequence.append(isLostSegment?PDBAmino.UnknownAmino:patchedAmino);
				}
			}
			chainseqs[SEQ_RES_CHAIN]=rebuiltSequence;
			
			// Can we use artifact-masked sequence or will we have to use heuristics?
			if(chainseqs[SEQ_SEQ_CHAIN]==null)
				System.err.println(pdbcode+'_'+chainName+'('+modelNo+')');
			CharSequence clippedSequence = ClipSequence(new StringBuilder(chainseqs[SEQ_SEQ_CHAIN]));
			List<Integer> hiLo = new ArrayList<Integer>();
			CharSequence clippedRebuiltSequence = ClipSequence(new StringBuilder(rebuiltSequence), hiLo);
			CharSequence clippedRebuiltPatchedSequence = ClipSequence(new StringBuilder(rebuiltPatchedSequence));
			CharSequence clippedRebuiltPatchedStructSequence = ClipSequence(new StringBuilder(rebuiltPatchedStructSequence));
			
			if(clippedSequence!=null && rebuiltSequence.toString().equals(chainseqs[SEQ_SEQ_CHAIN].toString())) {
				// It is redundant, but it servers as a marker
				useMaskingHeuristics=false;
				// Used sequence patched with SEQADV info
				chainseqs[SEQ_MASKED_CHAIN]=rebuiltPatchedSequence;
				chainseqs[SEQ_MASKED_STRUCT_CHAIN]=rebuiltPatchedStructSequence;
			} else if(clippedSequence!=null && clippedRebuiltSequence.toString().equals(clippedSequence.toString())) {
				// It is redundant, but it servers as a marker
				useMaskingHeuristics=false;
				// Clipping on sequence patched with SEQADV info based on previous clipping info
				chainseqs[SEQ_MASKED_CHAIN]=new StringBuilder(rebuiltPatchedSequence.substring(hiLo.get(0), hiLo.get(1)));
				chainseqs[SEQ_MASKED_STRUCT_CHAIN]=new StringBuilder(rebuiltPatchedStructSequence.substring(hiLo.get(0), hiLo.get(1)));
			} else if(clippedSequence!=null && clippedRebuiltPatchedSequence.toString().equals(clippedSequence.toString())) {
				// It is redundant, but it serves as a marker
				useMaskingHeuristics=false;
				chainseqs[SEQ_MASKED_CHAIN]=new StringBuilder(clippedRebuiltPatchedSequence);
				chainseqs[SEQ_MASKED_STRUCT_CHAIN]=new StringBuilder(clippedRebuiltPatchedStructSequence);
			} else {
				if(clippedSequence!=null) {
					LOG.finest("MISMATCHES "+getName());
					LOG.finest("\tMissing List Size: "+missingList.size());
					LOG.finest("\tS: "+chainseqs[SEQ_SEQ_CHAIN]);
					LOG.finest("\tA: "+rebuiltSequence);
					LOG.finest("\tR: "+rebuiltPatchedSequence);
					LOG.finest("\tC: "+clippedRebuiltPatchedSequence);
				}
				useMaskingHeuristics=true;
				chainseqs[SEQ_MASKED_STRUCT_CHAIN]=chainseqs[SEQ_MASKED_CHAIN]=chainseqs[SEQ_SEQ_CHAIN];
			}
		} else {
			// In this case is better reusing the same object, because it contains the information we trust
			useMaskingHeuristics=true;
			chainseqs[SEQ_MASKED_STRUCT_CHAIN]=chainseqs[SEQ_RES_CHAIN]=chainseqs[SEQ_MASKED_CHAIN]=chainseqs[SEQ_SEQ_CHAIN];
		}
		
		putTER();
		
		return retval;
	}
	
	public Mapping addMapping(String db, String id, PDBCoord start, PDBCoord stop) {
		Mapping m = new Mapping(this, chainName, db, id, start, stop);
		artifactMapping.add(m);
		artifactHash.put(db+":"+id,m);
		
		return m;
	}
	
	
	public void appendToArtifact(String db, String id, String reason,PDBAmino residue) {
		// New approach
		artifactSet.add(residue);
		
		// Old approach!
		
		// LOG.fine("FOUND ARTIFACT FOR CHAIN '"+chain+"'");
		Mapping map = artifactHash.get(db+":"+id);
		//	addMapping(db,id,Integer.MIN_VALUE,Integer.MIN_VALUE)
		
		// This one only happens on crippled files
		// So, heuristics we are going there!
		if(map==null) {
			if(artifactMapping.size()==1) {
				// We are supposing a bug like the one in 2B3P
				// so, let's create an alias!
				map = artifactMapping.get(0);
				artifactHash.put(db+":"+id,map);
			} else {
				// No way to decide, so
				// new entry...
				map = addMapping(db,id,new PDBCoord(),new PDBCoord());
			}
			LOG.fine("JARL! "+pdbcode);
		}
		
		map.followFragment(reason, residue);
	}
	
	public List<Mapping> getMappingList() {
		return artifactMapping;
	}

	public StringBuilder getSeqAminos() {
		return getAminos(true);
	}
	
	public StringBuilder getAminos() {
		return getAminos(false);
	}
	
	public StringBuilder getMaskedAminos() {
		return chainseqs[SEQ_MASKED_CHAIN];
	}
	
	public StringBuilder getAminos(boolean isSeq) {
		int chainIdx=isSeq?SEQ_SEQ_CHAIN:SEQ_RES_CHAIN;
		return getAminos(chainIdx);
	}
	
	public StringBuilder getAminos(int chainIdx) {
		return (chainseqs[chainIdx]!=null)?chainseqs[chainIdx]:null;
	}
	
	/**
	 * This method returns the chain sequence with the cloning artifacts removed.
	 * The sequence length is at least MINSEQLENGTH. If artifacts mapping was not
	 * possible, then heuristics are used over the aminoacid sequence.
	 * @return The pruned aminoacid sequence, or null 
	 */
	public PDBSeq getPrunedSequence() {
		PDBSeq retval=null;
		
		StringBuilder tmpSeq=getMaskedAminos();
		if(tmpSeq!=null)
			tmpSeq=new StringBuilder(tmpSeq);
		CharSequence prunedSeq = ClipSequence(tmpSeq);
		
		// Do we need cloning artifacts heuristics?
		if(useMaskingHeuristics && prunedSeq!=null && prunedSeq.length()>=MINSEQLENGTH) {
			prunedSeq=ClipSequence(PruneSequence(prunedSeq));
		}
		
		if(prunedSeq!=null && prunedSeq.length()>=MINSEQLENGTH) {
			retval = new PDBSeq(getName(),description,prunedSeq);
		}
		return retval;
	}
	
	/**
	 * This method returns the chain sequence with the cloning artifacts and
	 * sequence sections with no structure removed.
	 * The sequence length is at least MINSEQLENGTH. If artifacts mapping was not
	 * possible, then heuristics are used over the aminoacid sequence.
	 * @return The pruned aminoacid sequence, or null 
	 */
	public PDBSeq getMissingPrunedSequence() {
		PDBSeq retval=null;
		
		StringBuilder tmpSeq=getAminos(SEQ_MASKED_STRUCT_CHAIN);
		if(tmpSeq!=null)
			tmpSeq=new StringBuilder(tmpSeq);
		CharSequence missingPrunedSeq = ClipSequence(tmpSeq);
		
		// Do we need cloning artifacts heuristics?
		if(useMaskingHeuristics && missingPrunedSeq!=null) {
			missingPrunedSeq=ClipSequence(PruneSequence(missingPrunedSeq));
		}
		
		if(missingPrunedSeq!=null) {
			retval = new PDBSeq(getName(),description,missingPrunedSeq);
		}
		return retval;
	}
	
	/**
	 * This protected method is used to propagate the shared information
	 * (SEQRES, SEQADV, DBREF...) from a PDBChain to this one. Mainly
	 * used for chains from different PDB models.
	 * @param chain
	 */
	protected void propagateFrom(PDBChain chain) {
		if(chain!=null) {
			// First, the description
			if(chain.description!=null) {
				this.description = chain.description;
			}
			// Then, the SEQRES sequence
			if(chain.chainseqs[SEQ_SEQ_CHAIN]!=null) {
				this.chainseqs[SEQ_SEQ_CHAIN] = new StringBuilder(chain.chainseqs[SEQ_SEQ_CHAIN]);
				this.isJammeds[SEQ_SEQ_CHAIN] = chain.isJammeds[SEQ_SEQ_CHAIN];
			}
			
			// And of course, the SEQADV info
			this.artifactHash = new HashMap<String,Mapping>(chain.artifactHash);
			this.artifactSet = new HashSet<PDBCoord>(chain.artifactSet);
			this.artifactMapping = new ArrayList<Mapping>(chain.artifactMapping);
		}
	}
}
