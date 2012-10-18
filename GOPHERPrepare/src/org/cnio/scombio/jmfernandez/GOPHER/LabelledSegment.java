package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.ArrayList;
import java.util.List;
import java.util.TreeMap;

class LabelledSegment<A extends PDBCoord> {
	protected final static char INS_TREND_UNKNOWN='0';
	protected final static char INS_TREND_INCREASING='<';
	protected final static char INS_TREND_DECREASING='>';
	protected final static char INS_TREND_SLOPE='/';
	protected final static char INS_FORWARD_START='@';	// i.e. 64
	protected final static char INS_FORWARD_START_PDB=' ';
	protected final static char INS_TREND_START=INS_FORWARD_START+1;
	protected final static char INS_TREND_END='Z';
	protected final static char INS_BACKWARD_MASK=INS_FORWARD_START | 0x20; // i.e. 64+32
	
	protected final static char DEFAULT_SEGMENT_KIND='a';
	protected final static char MISSING_SEGMENT_KIND='m';
	
	protected static <A extends PDBCoord> void TreeSegmentPopulation(final LabelledSegment<A> currSegment,int segmentPos,final TreeMap<PDBCoord,Integer> atomLeftCoord,final TreeMap<PDBCoord,Integer> atomRightCoord) { 
		// Although segments should be more or less consistent
		// each segment should have an independent missing mode
		boolean missingMode=false;
		
		List<A> currAminoSegment=currSegment.segment;
		
		if(currAminoSegment.size()>1) {
			PDBCoord firstAmino = currAminoSegment.get(0);
			PDBCoord secondAmino = currAminoSegment.get(1);
			missingMode=!(firstAmino.coord==secondAmino.coord && firstAmino.coord_ins!=secondAmino.coord_ins);
		}
		
		// Now, applying to the coordinates of the segment
		A left=currAminoSegment.get(0);
		A right=currAminoSegment.get(currAminoSegment.size()-1);
		PDBCoord leftCoord = new PDBCoord(missingMode,left);
		PDBCoord rightCoord = new PDBCoord(missingMode,right);
		atomLeftCoord.put(leftCoord, segmentPos);
		atomRightCoord.put(rightCoord, segmentPos);
	}
	
	protected static List<LabelledSegment<PDBAmino>> SegmentsDetection(final List<PDBAmino> chainAminos,final TreeMap<PDBCoord,Integer> atomLeftCoord,final TreeMap<PDBCoord,Integer> atomRightCoord) {
		// First, segment detection in sequence
		LabelledSegment<PDBAmino> currAminoSegment=new LabelledSegment<PDBAmino>();
		List<LabelledSegment<PDBAmino>> aminoSegments=new ArrayList<LabelledSegment<PDBAmino>>();
		aminoSegments.add(currAminoSegment);
		
		// We must be sure the trees are clear
		atomLeftCoord.clear();
		atomRightCoord.clear();
		
		int segmentPos=0;
		for(PDBAmino curAmino: chainAminos) {
			LabelledSegment<PDBAmino> result = currAminoSegment.add(curAmino);
			if(result!=null) {
				// At last, save it here
				TreeSegmentPopulation(currAminoSegment, segmentPos, atomLeftCoord, atomRightCoord);
				aminoSegments.add(result);
				currAminoSegment=result;
				segmentPos++;
			}
		}
		
		// Final case
		TreeSegmentPopulation(currAminoSegment,segmentPos,atomLeftCoord,atomRightCoord);
		
		return aminoSegments;
	}
	
	public static boolean IsBackwards(char insCode) {
		return (insCode & INS_BACKWARD_MASK)==INS_BACKWARD_MASK;
	}
	
	protected char prevINS;
	protected char kindINS;
	protected A prevCoord;
	protected final List<A> segment;
	protected final char segmentKind;
	
	public LabelledSegment(char segmentKind, A newCoord) {
		this(segmentKind);
		add(newCoord);
	}
	
	public LabelledSegment(char segmentKind) {
		this(segmentKind,new ArrayList<A>());
	}
	
	public LabelledSegment() {
		this(DEFAULT_SEGMENT_KIND);
	}
	
	public LabelledSegment(List<A> segment) {
		this(DEFAULT_SEGMENT_KIND,segment);
	}

	
	public LabelledSegment(char segmentKind,List<A> segment) {
		this.segment = segment;
		this.segmentKind = segmentKind;
		prevINS=INS_TREND_UNKNOWN;
		kindINS=INS_TREND_UNKNOWN;
		prevCoord=(segment!=null && segment.size()>0)?segment.get(segment.size()-1):null;
	}
	
	public A firstCoord() {
		return segment.get(0);
	}
	
	public A lastCoord() {
		return segment.get(segment.size()-1);
	}
	
	public void insertSegment(LabelledSegment<? extends A> newSegment) {
		A last=newSegment.segment.get(newSegment.segment.size()-1);
		int intraRight=segment.size()-1;
		for(;intraRight>0 && segment.get(intraRight).compareTo(last)>0;intraRight--) {
		}
		
		// And now, insertion
		segment.addAll(intraRight, newSegment.segment);
	}
	
	public LabelledSegment<A> add(A newCoord) {
		LabelledSegment<A> retval = null;
		
		boolean createNewSegment=true;
		if(prevCoord!=null) {
			switch(prevINS) {
				// Unknown trend
				case INS_TREND_UNKNOWN:
					if((prevCoord.coord+1)==newCoord.coord && prevCoord.coord_ins == newCoord.coord_ins) {
						createNewSegment=false;
						prevINS=(newCoord.coord_ins==INS_FORWARD_START_PDB)?INS_FORWARD_START:newCoord.coord_ins;
						kindINS=prevINS;
					} else if(prevCoord.coord==(newCoord.coord+1) && prevCoord.coord_ins == newCoord.coord_ins) {
						createNewSegment=false;
						prevINS=(newCoord.coord_ins==INS_FORWARD_START_PDB)?INS_FORWARD_START:newCoord.coord_ins;
						prevINS |= INS_BACKWARD_MASK;
						kindINS=prevINS;
					} else if(prevCoord.coord==newCoord.coord) {
						if(prevCoord.coord_ins>INS_FORWARD_START && (newCoord.coord_ins-prevCoord.coord_ins)==1) {
							createNewSegment=false;
							prevINS=INS_TREND_INCREASING;
							kindINS=prevINS;
						} else if(newCoord.coord_ins>INS_FORWARD_START && (prevCoord.coord_ins-newCoord.coord_ins)==1) {
							createNewSegment=false;
							prevINS=INS_TREND_DECREASING;
							kindINS=prevINS;
						}
					} else if((prevCoord.coord+1)==newCoord.coord && prevCoord.coord_ins==INS_TREND_END && newCoord.coord_ins==INS_TREND_START) {
						createNewSegment=false;
						prevINS=INS_TREND_INCREASING;
						kindINS=prevINS;
					} else if(prevCoord.coord==(newCoord.coord+1) && prevCoord.coord_ins==INS_TREND_START && newCoord.coord_ins==INS_TREND_END) {
						createNewSegment=false;
						prevINS=INS_TREND_DECREASING;
						kindINS=prevINS;
					}
					break;
				// Increasing trend, constant coord
				case INS_TREND_INCREASING:
					if(
						(prevCoord.coord==newCoord.coord && (newCoord.coord_ins-prevCoord.coord_ins)==1) ||
						((prevCoord.coord+1)==newCoord.coord && prevCoord.coord_ins==INS_TREND_END && newCoord.coord_ins==INS_TREND_START)
					)
						createNewSegment=false;
					break;
				// Increasing trend, constant coord
				case INS_TREND_DECREASING:
					if(
						(prevCoord.coord==newCoord.coord && (prevCoord.coord_ins-newCoord.coord_ins)==1) ||
						(prevCoord.coord==(newCoord.coord+1) && prevCoord.coord_ins==INS_TREND_START && newCoord.coord_ins==INS_TREND_END)
					)
						createNewSegment=false;
					break;
				// Constant ins code
				default:
					if(prevCoord.coord_ins == newCoord.coord_ins) {
						if(IsBackwards(prevINS)) {
							if(prevCoord.coord==(newCoord.coord+1)) {
								createNewSegment=false;
							}
						} else if((prevCoord.coord+1)==newCoord.coord) {
							createNewSegment=false;
						}
					}
			}
		} else {
			createNewSegment=false;
			kindINS=(newCoord.coord_ins==INS_FORWARD_START_PDB)?INS_FORWARD_START:newCoord.coord_ins;
		}
		
		if(createNewSegment) {
			retval=new LabelledSegment<A>(segmentKind,newCoord);
		} else {
			segment.add(newCoord);
			prevCoord=newCoord;
		}
		
		return retval;
	}
	
	public void doTreeSegmentPopulation(int segmentPos,final TreeMap<PDBCoord,Integer> leftCoord,final TreeMap<PDBCoord,Integer> rightCoord) {
		TreeSegmentPopulation(this,segmentPos,leftCoord,rightCoord);
	}
}
