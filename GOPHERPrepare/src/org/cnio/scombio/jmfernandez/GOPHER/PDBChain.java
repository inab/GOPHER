package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.Map.Entry;

public class PDBChain {
	// This method removes from an aminoacid sequence the aminoacids from the
	// beginning and end
	protected static String ClipSequence(StringBuilder seq) {
		int minSub=0;
		int maxSub=seq.length();
		
		for(int cbi=0;cbi<maxSub;cbi++) {
			if(seq.charAt(cbi)!='X') {
				break;
			}
			minSub++;
		}

		for(int cbi=maxSub-1;cbi>=minSub;cbi--) {
			if(seq.charAt(cbi)!='X') {
				maxSub=cbi+1;
				break;
			}
		}
		
		return (minSub<maxSub)?seq.substring(minSub,maxSub):"";
	}
	
	class Fragment {
		public String reason;
		public PDBCoord start;
		public PDBCoord end;
		public StringBuilder seq;
		
		Fragment(String reason,PDBAmino residue) {
			// This is needed, because we are 
			start = new PDBCoord(residue);
			end = new PDBCoord(residue);
			this.reason = reason;
			seq=new StringBuilder().append(residue.amino);
		}
		
		public PDBCoord add(char residue) {
			seq.append(residue);
			return end.contextInc();
		}
		
		public StringBuilder getSequence() {
			return seq;
		}
	};
	
	class Mapping {
		public String chain;
		public String db;
		public String id;
		public PDBCoord start;
		public PDBCoord end;
		
		protected ArrayList<Fragment> fraglist;
		protected HashMap<PDBCoord,Fragment> fraghash;
		
		Mapping(String chain, String db, String id, PDBCoord start, PDBCoord stop) {
			this.chain = chain;
			this.db = db;
			this.id = id;
			this.start = start;
			this.end = stop;
			
			fraglist = new ArrayList<Fragment>();
			fraghash = new HashMap<PDBCoord,Fragment>();
		}
		
		public ArrayList<Fragment> getFragmentList() {
			return fraglist;
		}
		
		public boolean containsPos(PDBCoord pos) {
			return fraghash.containsKey(pos);
		}
		
		public Fragment getFragment(PDBCoord pos) {
			return fraghash.get(pos);
		}
		
		public void followFragment(String reason, PDBAmino residue) {
			boolean followFragment=false;
			if(containsPos(residue)) {
				Fragment frag = getFragment(residue);
				followFragment = ignoreReason || reason.equals(frag.reason);
			}

			if(followFragment) {
				// An extension of an existing artifact
				Fragment frag = getFragment(residue);
				PDBCoord futureEnd = new PDBCoord(frag.add(residue.amino)).contextInc();
				
				// Updating the hash
				fraghash.put(futureEnd, frag);
				fraghash.remove(residue);
			} else {
				// A new artifact!!!
				Fragment newfrag = new Fragment(reason,residue);
				PDBCoord futureEnd = new PDBCoord(residue.amino).contextInc();
				
				fraglist.add(newfrag);
				fraghash.put(futureEnd, newfrag);
			}
		}
	};
	
	protected final String pdbcode;
	protected final String chainName;
	protected boolean ignoreReason;
	protected Map<String, Character> toOneAA;
	protected Set<String> notAA;
	protected StringBuilder[] chainseqs;
	protected List<PDBCoord> chaincoords;
	// Segments of missing residues
	protected List<List<PDBAmino>> missingList;
	// Leftmost residues of the segment, ordered
	protected TreeMap<PDBCoord,Integer> missingLeft;
	// Rightmost residues of the segment, ordered
	protected TreeMap<PDBCoord,Integer> missingRight;
	protected PDBAmino prevMissingAmino;
	
	protected PDBCoord missingBeforeFirst;
	protected int missingBeforeFirstDistance;
	protected boolean[] isJammeds;
	protected boolean isTERChain;
	protected ArrayList<Mapping> artifactMapping;
	protected HashMap<String,Mapping> artifactHash;
	
	public PDBChain(String pdbcode, String chainName, Map<String, Character> toOneAA, Set<String> notAA, boolean ignoreReason) {
		this(pdbcode, chainName, toOneAA, notAA, ignoreReason,null);
	}
	
	public PDBChain(String pdbcode, String chainName, Map<String, Character> toOneAA, Set<String> notAA, boolean ignoreReason, List<List<PDBAmino>> missingList) {
		this.pdbcode = pdbcode;
		this.chainName = chainName;
		this.toOneAA = toOneAA;
		this.notAA = notAA;
		this.ignoreReason=ignoreReason;
		chainseqs = new StringBuilder[] { null, null };
		chaincoords=new ArrayList<PDBCoord>();
		initMissing(missingList);
		artifactMapping=new ArrayList<Mapping>();
		artifactHash=new HashMap<String,Mapping>();
		isTERChain=false;
		isJammeds = new boolean[] { false, false };
	}
	
	private void initMissing(List<List<PDBAmino>> missingList) {
		this.missingList = missingList; 
		prevMissingAmino=null;
		if(missingList!=null) {
			missingLeft = new TreeMap<PDBCoord,Integer>();
			missingRight = new TreeMap<PDBCoord,Integer>();
			missingBeforeFirst = null;
			missingBeforeFirstDistance = -1;
		} else {
			missingLeft = null;
			missingRight = null;
		}
	}
	
	private void populateMissing() {
		// Reset
		missingLeft.clear();
		missingRight.clear();
		
		// Detecting missing mode for the chain
		int segmentPos=0;
		
		// Each segment could have an independent missing mode
		// but they should be more or less consistent
		boolean missingMode=false;
		
		for(List<PDBAmino> missingSegment: missingList) {
			if(missingSegment.size()>1) {
				PDBCoord firstMissing = missingSegment.get(0);
				PDBCoord secondMissing = missingSegment.get(1);
				missingMode=!(firstMissing.coord==secondMissing.coord && firstMissing.coord_ins!=secondMissing.coord_ins);
				if(missingMode==true)  break;
			}
		}
		
		for(List<PDBAmino> missingSegment: missingList) {
			// Now, applying to the coordinates of the segment
			PDBAmino left=missingSegment.get(0);
			PDBAmino right=missingSegment.get(missingSegment.size()-1);
			PDBCoord leftCoord = new PDBCoord(missingMode,left);
			PDBCoord rightCoord = new PDBCoord(missingMode,right);
			missingLeft.put(leftCoord, segmentPos);
			missingRight.put(rightCoord, segmentPos);
			
			segmentPos++;
		}
	}
	
	public List<List<PDBAmino>> getMissingList() {
		return missingList;
	}
	
	public boolean appendToChain(PDBRes... residues) {
		return appendToChain(false, residues);
	}
	
	public boolean appendToSeqChain(String... residues) {
		return appendToChain(true, residues);
	}
	
	protected boolean appendToChain(boolean isSeq, String... residues) {
		if(isTERChain)
			return false;
		
		int chainIdx=isSeq?1:0;
		
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
							System.err.println("WARNING: Jammed chain: '"+ires+"' in "+pdbcode+"_"+chainName);
							piece.append('X');
						//} else {
						//	$localseq=undef;
						//	last;
						//}
					} else {
						piece.append('X');
						System.err.println("WARNING: Unknown aminoacid '"+ires+"' in "+pdbcode+"_"+chainName+"!!!");
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

	protected boolean appendToChain(boolean isSeq, PDBRes... residues) {
		if(isTERChain)
			return false;
		
		int chainIdx=isSeq?1:0;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			StringBuilder piece=new StringBuilder();
			for(PDBRes pres: residues) {
				String ires = pres.res;
				if(ires.length()==3) {
				// Por definición en PDB, los aminoácidos se expresan
				// en códigos de 3 letras
					if(toOneAA.containsKey(ires)) {
						piece.append(toOneAA.get(ires));
					} else if(notAA.contains(ires)) {
						//if(length($localseq)>0 || (defined($prev_chain) && defined($prev_seq) && $localchain eq $prev_chain && length($prev_seq)>0)) {
							System.err.println("WARNING: Jammed chain: '"+ires+"' at "+pres.coord+pres.coord_ins+" in "+pdbcode+"_"+chainName);
							piece.append('X');
						//} else {
						//	$localseq=undef;
						//	last;
						//}
					} else {
						piece.append('X');
						System.err.println("WARNING: Unknown aminoacid '"+ires+"' at "+pres.coord+pres.coord_ins+"' in "+pdbcode+"_"+chainName+"!!!");
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
			if(!isJammeds[chainIdx]) {
				chainseqs[chainIdx].append(piece);
				chaincoords.addAll(Arrays.asList(residues));
			}
		}
		
		return retval;
	}

	protected boolean appendToChain(boolean isSeq, PDBAmino... residues) {
		if(isTERChain)
			return false;
		
		int chainIdx=isSeq?1:0;
		
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
			chaincoords.addAll(Arrays.asList(residues));
		}
		
		return retval;
	}

	// Just before appending, looking for missing...
	public boolean appendToChain(PDBRes residue,PDBCoord prev_coord) {
		if(isTERChain)
			return false;
		
		if(!isJammeds[0] && chainseqs[0] == null)
			chainseqs[0] = new StringBuilder();
		
		boolean retval = !isJammeds[0];
		
		if(retval) {
			if(hasMissingResidues()) {
				if(prev_coord==null) {
					// Time to populate the other structures
					populateMissing();
				}
				Entry<PDBCoord,Integer> highMark=missingRight.lowerEntry(residue);
				if(highMark!=null) {
					// Need this one for checks
					if(prev_coord==null) {
						missingBeforeFirst = highMark.getKey();
						missingBeforeFirstDistance = residue.sub(missingBeforeFirst);
					}
					
					//System.err.println("DEBUG PDBCOORD:"+new PDBCoord(highMark.getKey())+" PDBAMINO: "+new PDBCoord(highMark.getValue())+" PDBSEARCH: "+new PDBCoord(residue));
					PDBCoord highRef= highMark.getKey();
					// Must be the value, otherwise it can give a NPE
					int highPos=highMark.getValue();
					int lowPos=highPos+1;
					boolean newFirstMissing=false;
					if(prev_coord!=null) {
						/*
						//lowPos=0;
						System.err.println("DEBUG PDB "+pdbcode+"_"+chainName+" HIGH "+highPos+" RES "+residue+new PDBCoord(residue));
					} else {
					*/
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
							PDBCoord first = chaincoords.get(0);
							Entry<PDBCoord,Integer> newMissingBefore=missingRight.lowerEntry(first);
							if(newMissingBefore!=null) {
								missingBeforeFirst = newMissingBefore.getKey();
								missingBeforeFirstDistance=first.sub(missingBeforeFirst);
							}
						}
					}
				}
			}
			
			if(retval)
				retval = appendToChain(false,residue);
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
		
		int chainIdx=isSeq?1:0;
		
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
			chaincoords.addAll(0,Arrays.asList(residues));
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
		
		int chainIdx=isSeq?1:0;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			char[] piece=new char[numres];
			for(int counter=0; counter<numres; counter++) {
				piece[counter]='X';
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
		
		int chainIdx=isSeq?1:0;
		
		if(!isJammeds[chainIdx] && chainseqs[chainIdx] == null)
			chainseqs[chainIdx] = new StringBuilder();
		
		boolean retval = !isJammeds[chainIdx];
		
		if(retval) {
			char[] piece=new char[numres];
			for(int counter=0; counter<numres; counter++) {
				piece[counter]='X';
			}
			chainseqs[chainIdx].insert(0, piece);
		}
		
		return retval;
	}
	
	public boolean hasMissingResidues() {
		return missingList!=null;
		//return missingList!=null && (missing==null || missing.size()>0);
	}
	
	public boolean isTER() {
		return isTERChain;
	}
	
	public boolean isOpen() {
		return !isTERChain;
	}
	
	public void putTER() {
		isTERChain=true;
	}
	
	public String toString(boolean isSeq) {
		int chainIdx=isSeq?1:0;
		return (chainseqs[chainIdx]!=null)?chainseqs[chainIdx].toString():null;
	}
	
	public String toString() {
		return (chainseqs[0]!=null)?chainseqs[0].toString():(chainseqs[1]!=null?chainseqs[1].toString():null);
	}
	
	public boolean storeMissingResidue(PDBRes residue) {
		boolean good=false;
		
		String res = residue.res;
		if(res.length()==3) {
			if(!hasMissingResidues()) {
				missingList = new ArrayList<List<PDBAmino>>();
				missingLeft = new TreeMap<PDBCoord,Integer>();
				missingRight = new TreeMap<PDBCoord,Integer>();
				prevMissingAmino = null;
			}
			
			char aminochar='X';
		// Por definición en PDB, los aminoácidos se expresan
		// en códigos de 3 letras
			if(toOneAA.containsKey(res)) {
				aminochar = toOneAA.get(res);
			} else if(notAA.contains(res)) {
				//if(length($localseq)>0 || (defined($prev_chain) && defined($prev_seq) && $localchain eq $prev_chain && length($prev_seq)>0)) {
				System.err.println("WARNING: Jammed remark chain: '"+res+"' at "+residue.coord+residue.coord_ins+" in "+pdbcode+"_"+chainName);
				//} else {
				//	$localseq=undef;
				//	last;
				//}
			} else {
				System.err.println("WARNING: Unknown remark aminoacid '"+res+"' at "+residue.coord+residue.coord_ins+" in "+pdbcode+"_"+chainName+"!!!");
			}
			PDBAmino amino=new PDBAmino(aminochar,residue.coord,residue.coord_ins);
			// Order of these sentences is very important!
			boolean createNewMissingSegment=true;
			if(prevMissingAmino!=null) {
				if((prevMissingAmino.coord+1)==residue.coord && prevMissingAmino.coord_ins == residue.coord_ins) {
					createNewMissingSegment=false;
				} else if(prevMissingAmino.coord==residue.coord) {
					createNewMissingSegment=false;
				}
			}
			
			if(createNewMissingSegment) {
				missingList.add(new ArrayList<PDBAmino>());
			}
			// At last, save it here
			missingList.get(missingList.size()-1).add(amino);
			prevMissingAmino = amino;
			
			good=true;
		//} else if(length($ires)==1) {
		//	# Y los nucleótidos en códigos de una letra
		//	$localseq=undef;
		//	last;
		}
		
		return good;
	}
	
	/*
	public boolean padFirst(PDBCoord firstKnownCoordRes) {
		if(isTERChain)
			return false;
		
		boolean retval=hasMissingResidues();
		if(retval) {
			int maxMissing=-1;
			if(missing.containsKey(missingList.get(0))) {
				maxMissing=1;
				int missingSize=missingList.size();
				for(;maxMissing<missingSize && missing.containsKey(missingList.get(maxMissing));maxMissing++) {
				}
				
			} else {
				Entry<PDBCoord,PDBAmino> entry=missing.lowerEntry(firstKnownCoordRes);

				if(entry!=null) {
					maxMissing = missingHash.get(entry.getValue()) + 1;
					//PDBCoord newKnownCoordRes=entry.getKey();
					//int numUnknown=firstKnownCoordRes.sub(newKnownCoordRes)-1;
					//if(numUnknown>0)
					//	prepadChain(false,numUnknown);
					//prependToChain(false,entry.getValue());
					//firstKnownCoordRes=newKnownCoordRes;
				}
			}
			
			if(maxMissing>0) {
				PDBAmino[] toPrepend = missingList.subList(0, maxMissing).toArray(new PDBAmino[0]);
				retval = prependToChain(false,toPrepend);
				if(retval) {
					// Removing already used missing aminoacids from TreeMap
					for(PDBAmino amino: toPrepend) {
						missing.remove(amino);
					}
				}
			}
		}
		return retval;
	}
	
	protected boolean padLast(PDBCoord lastKnownCoordRes) {
		if(isTERChain)
			return false;
		
		boolean retval=hasMissingResidues();
		if(retval) {
			Entry<PDBCoord, PDBAmino> entry=missing.higherEntry(lastKnownCoordRes);
			
			if(entry!=null) {
				int pos = missingHash.get(entry.getValue());
				PDBAmino[] toAppend = missingList.subList(pos,missingList.size()).toArray(new PDBAmino[0]);
				retval = appendToChain(false,toAppend);
				if(retval) {
					// Removing already used missing aminoacids from TreeMap
					for(PDBAmino amino: toAppend) {
						missing.remove(amino);
					}
				}	
				
				//PDBCoord newKnownCoordRes=entry.getKey();
				//int numUnknown=newKnownCoordRes.sub(lastKnownCoordRes)-1;
				//System.err.println("DEBUG: "+pdbcode+"_"+chainName+" old: "+lastKnownCoordRes.coord+lastKnownCoordRes.coord_ins+" new: "+newKnownCoordRes.coord+newKnownCoordRes.coord_ins+" diff: "+numUnknown);
				//if(numUnknown>0)
				//	padChain(false,numUnknown);
				//appendToChain(false,entry.getValue());
				//lastKnownCoordRes=newKnownCoordRes;
			}
			
			if(missing.size()>0) {
				System.err.println("DEBUGWARNING: "+pdbcode+"_"+chainName+" has "+missing.size()+" unplaced missing residues");
			}
		}
		
		// No more atoms for this chain
		putTER();
		
		return retval;
	}
	*/
	
	public boolean padBoth() {
		if(isTERChain)
			return false;
		
		boolean retval = false;
		if(chaincoords.size()>0 && hasMissingResidues()) {
			Integer[] missingSurvivors = missingLeft.values().toArray(new Integer[0]);
			Arrays.sort(missingSurvivors);
			boolean checkFirst=true;
			retval=true;
			for(Integer iMissing: missingSurvivors) {
				PDBAmino[] toPrepend = missingList.get(iMissing).toArray(new PDBAmino[0]);
				if(checkFirst) {
					PDBCoord firstKnownCoordRes=chaincoords.get(0);
					checkFirst=toPrepend[toPrepend.length-1].compareTo(firstKnownCoordRes)<0;
				}
				if(checkFirst) {
					retval &= prependToChain(false,toPrepend);
					checkFirst=false;
				} else {
					retval &= appendToChain(false,toPrepend);
				}
			}
		/*
			PDBCoord firstKnownCoordRes=chaincoords.get(0);
			PDBCoord lastKnownCoordRes=chaincoords.get(chaincoords.size()-1);
			Entry<PDBCoord, Integer> higherEntry=missingLeft.higherEntry(lastKnownCoordRes);
			
			
			
			if(missing.containsKey(missingList.get(0).get(0))) {
				int maxMissing=1;
				int missingSize=missingList.size();
				for(;maxMissing<missingSize && missing.containsKey(missingList.get(maxMissing));maxMissing++) {
				}
				
				int endDistance = missingList.get(0).sub(lastKnownCoordRes);
				int beginDistance = firstKnownCoordRes.sub(missingList.get(maxMissing-1));

				PDBAmino[] toPrepend = missingList.subList(0, maxMissing).toArray(new PDBAmino[0]);
				if((beginDistance<endDistance && beginDistance>0) || endDistance<=0) {
					retval = prependToChain(false,toPrepend);
				} else {
					retval = appendToChain(false,toPrepend);
				}
				if(retval) {
					// Removing already used missing aminoacids from TreeMap
					for(PDBAmino amino: toPrepend) {
						missing.remove(amino);
					}
				}
			} else {
				// padFirst
				int maxMissing=-1;
				Entry<PDBCoord,PDBAmino> lowerEntry=missing.lowerEntry(firstKnownCoordRes);
				if(lowerEntry!=null) {
					maxMissing = missingHash.get(lowerEntry.getValue()) + 1;
					//PDBCoord newKnownCoordRes=entry.getKey();
					//int numUnknown=firstKnownCoordRes.sub(newKnownCoordRes)-1;
					//if(numUnknown>0)
					//	prepadChain(false,numUnknown);
					//prependToChain(false,entry.getValue());
					//firstKnownCoordRes=newKnownCoordRes;
				}

				if(maxMissing>0) {
					PDBAmino[] toPrepend = missingList.subList(0, maxMissing).toArray(new PDBAmino[0]);
					retval = prependToChain(false,toPrepend);
					if(retval) {
						// Removing already used missing aminoacids from TreeMap
						for(PDBAmino amino: toPrepend) {
							missing.remove(amino);
						}
					}
				}

				// padLast
				if(higherEntry!=null) {
					int pos = missingHash.get(higherEntry.getValue());
					PDBAmino[] toAppend = missingList.subList(pos,missingList.size()).toArray(new PDBAmino[0]);
					retval &= appendToChain(false,toAppend);
					if(retval) {
						// Removing already used missing aminoacids from TreeMap
						for(PDBAmino amino: toAppend) {
							missing.remove(amino);
						}
					}	

					//PDBCoord newKnownCoordRes=higherEntry.getKey();
					//int numUnknown=newKnownCoordRes.sub(lastKnownCoordRes)-1;
					//System.err.println("DEBUG: "+pdbcode+"_"+chainName+" old: "+lastKnownCoordRes.coord+lastKnownCoordRes.coord_ins+" new: "+newKnownCoordRes.coord+newKnownCoordRes.coord_ins+" diff: "+numUnknown);
					//if(numUnknown>0)
					//	padChain(false,numUnknown);
					//appendToChain(false,higherEntry.getValue());
					//lastKnownCoordRes=newKnownCoordRes;
				}
			}
			
			if(missing.size()>0) {
				System.err.println("DEBUGWARNING: "+pdbcode+"_"+chainName+" has "+missing.size()+" unplaced missing residues");
			}
		*/
		}
		
		putTER();
		
		return retval;
	}
	
	public Mapping addMapping(String db, String id, PDBCoord start, PDBCoord stop) {
		Mapping m = new Mapping(chainName, db, id, start, stop);
		artifactMapping.add(m);
		artifactHash.put(db+":"+id,m);
		
		return m;
	}
	
	
	public void appendToArtifact(String db, String id, String reason,PDBAmino residue) {
		// System.err.println("FOUND ARTIFACT FOR CHAIN '"+chain+"'");
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
			System.err.println("JARL! "+pdbcode);
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
	
	public StringBuilder getAminos(boolean isSeq) {
		int chainIdx=isSeq?1:0;
		return (chainseqs[chainIdx]!=null)?chainseqs[chainIdx]:null;
	}
}
