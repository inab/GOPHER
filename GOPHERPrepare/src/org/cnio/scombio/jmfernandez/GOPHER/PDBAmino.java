package org.cnio.scombio.jmfernandez.GOPHER;

public final class PDBAmino
	extends PDBCoord
{
	public final static char UnknownAmino='X';
	protected char amino;
	
	public PDBAmino() {
		this(UnknownAmino);
	}
	
	public PDBAmino(char amino) {
		this(amino,Integer.MIN_VALUE);
	}
	
	public PDBAmino(char amino,int coord) {
		this(amino,coord,' ');
	}
	
	public PDBAmino(char amino,PDBCoord coord) {
		super(coord.coord,coord.coord_ins);
		this.amino = amino;
	}
	
	public PDBAmino(char amino,int coord,char coord_ins) {
		super(coord,coord_ins);
		this.amino = amino;
	}
	
	public String toString() {
		return Character.toString(amino);
	}
}
