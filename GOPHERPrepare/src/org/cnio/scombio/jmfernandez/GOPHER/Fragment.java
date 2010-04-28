/**
 * 
 */
package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.ArrayList;
import java.util.List;

class Fragment {
	public String reason;
	public final PDBCoord start;
	public final PDBCoord end;
	protected List<PDBAmino> seq;
	
	Fragment(String reason,PDBAmino residue) {
		// This is needed, because we are 
		start = new PDBCoord(residue);
		end = new PDBCoord(residue);
		this.reason = reason;
		seq=new ArrayList<PDBAmino>();
		seq.add(residue);
	}
	
	public PDBCoord add(PDBAmino residue) {
		seq.add(residue);
		return end.contextInc();
	}
	
	public List<PDBAmino> getSequence() {
		return seq;
	}
}