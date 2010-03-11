package org.cnio.scombio.jmfernandez.GOPHER;

public final class PDBAmino
	extends PDBCoord
{
	protected char amino;
	
	public PDBAmino() {
		this('X');
	}
	
	public PDBAmino(char amino) {
		this(amino,Integer.MIN_VALUE);
	}
	
	public PDBAmino(char amino,int coord) {
		this(amino,coord,' ');
	}
	
	public PDBAmino(char amino,int coord,char coord_ins) {
		super(coord,coord_ins);
		this.amino = amino;
	}
	
	public String toString() {
		return Character.toString(amino);
	}
}
