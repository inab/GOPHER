package org.cnio.scombio.jmfernandez.GOPHER;

public class PDBRes
	extends PDBCoord
{
	protected String res;
	
	public PDBRes(String res) {
		this(res,Integer.MIN_VALUE);
	}
	
	public PDBRes(String res,int coord) {
		this(res,coord,' ');
	}
	public PDBRes(String res,int coord,char coord_ins) {
		super(coord,coord_ins);
		this.res = res;
	}
	
	public String toString() {
		return res;
	}
}
