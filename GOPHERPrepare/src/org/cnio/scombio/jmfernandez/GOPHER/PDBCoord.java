package org.cnio.scombio.jmfernandez.GOPHER;

public class PDBCoord implements Comparable<PDBCoord> {
	protected final static double INS_STEP=1.0/(double)('Z'-'A'+2);
	
	public final static PDBCoord LEAST_RESIDUE=new PDBCoord();
	
	protected int coord;
	protected char coord_ins;
	protected boolean comparisonMode;
	
	public PDBCoord() {
		this(Integer.MIN_VALUE);
	}
	
	public PDBCoord(int coord) {
		this(coord,' ');
	}
	
	public PDBCoord(int coord,char coord_ins) {
		this(false,coord,coord_ins);
	}
	public PDBCoord(boolean comparisonMode, int coord,char coord_ins) {
		this.comparisonMode=comparisonMode;
		this.coord = coord;
		this.coord_ins = coord_ins;
	}
	
	public PDBCoord(PDBCoord other) {
		this(false,other);
	}
	
	public PDBCoord(boolean comparisonMode,PDBCoord other) {
		this(comparisonMode,other.coord,other.coord_ins);
	}
	
	public String toString() {
		return Integer.toString(coord)+coord_ins;
	}
	
	/**
	 * Equality comparisons are useful to avoid code replications
	 */
	public boolean equals(Object other) {
		boolean retval=false;
		if(other!=null && other instanceof PDBCoord) {
			PDBCoord cOther = (PDBCoord)other;
			retval=cOther.coord==coord && cOther.coord_ins==coord_ins;
		}
		
		return retval;
	}
	
	/**
	 * I did not want to implement this one, but the contract is the contract.
	 * At least, it has been easy :-)
	 */
	public int hashCode() {
		return coord;
	}
	
	public PDBCoord inc() {
		switch(coord_ins) {
			case 'Z':
				coord_ins=' ';
				coord++;
				break;
			case ' ':
				coord_ins='A';
				break;
			default:
				coord_ins++;
		}
		
		return this;
	}
	
	public PDBCoord contextInc() {
		switch(coord_ins) {
			case 'Z':
				coord_ins=' ';
			case ' ':
				coord++;
				break;
			default:
				coord_ins++;
		}
		
		return this;
	}
	
	public PDBCoord contextDec() {
		switch(coord_ins) {
			case 'A':
				coord_ins=' ';
			case ' ':
				coord--;
				break;
			default:
				coord_ins++;
		}
		
		return this;
	}
	
	private static int ToNumber(char coord_ins) {
		switch(coord_ins) {
			case ' ':
				return 0;
			default:
				return coord_ins-'A'+1;
		}
	}
	
	public int compareTo(PDBCoord o) {
		if(!(comparisonMode || o.comparisonMode)) {
			if(coord < o.coord)
				return -1;
			if(coord > o.coord)
				return 1;
		}
		
		if(coord_ins < o.coord_ins)
			return -1;
		if(coord_ins > o.coord_ins)
			return 1;
		
		if(comparisonMode || o.comparisonMode) { 
			if(coord < o.coord)
				return -1;
			if(coord > o.coord)
				return 1;
		}
		return 0;
	}
	
	private double toNumber() {
		double retval=(double)coord;
		if(coord_ins!=' ') {
			retval+=(double)(coord_ins-'A'+1)*INS_STEP;
		}
		return retval;
	}
	
	public double sub(PDBCoord other) {
		return (comparisonMode || other.comparisonMode)?(toNumber()-other.toNumber()):(coord!=other.coord)?(coord-other.coord):(coord_ins-other.coord_ins);
		//return (ToNumber(coord_ins)-ToNumber(other.coord_ins))*('Z'-'A'+1) +coord-other.coord;
	}
}
