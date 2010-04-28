/**
 * 
 */
package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.ArrayList;
import java.util.HashMap;

class Mapping {
	/**
	 * 
	 */
	private final PDBChain pdbChain;
	public final String chain;
	public final String db;
	public final String id;
	public PDBCoord start;
	public PDBCoord end;
	
	protected ArrayList<Fragment> fraglist;
	protected HashMap<PDBCoord,Fragment> fraghash;
	
	Mapping(PDBChain pdbChain, String chain, String db, String id, PDBCoord start, PDBCoord stop) {
		this.pdbChain = pdbChain;
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
			followFragment = this.pdbChain.ignoreReason || reason.equals(frag.reason);
		}

		if(followFragment) {
			// An extension of an existing artifact
			Fragment frag = getFragment(residue);
			PDBCoord futureEnd = new PDBCoord(frag.add(residue)).contextInc();
			
			// Updating the hash
			fraghash.put(futureEnd, frag);
			fraghash.remove(residue);
		} else {
			// A new artifact!!!
			Fragment newfrag = new Fragment(reason,residue);
			PDBCoord futureEnd = new PDBCoord(residue).contextInc();
			
			fraglist.add(newfrag);
			fraghash.put(futureEnd, newfrag);
		}
	}
}