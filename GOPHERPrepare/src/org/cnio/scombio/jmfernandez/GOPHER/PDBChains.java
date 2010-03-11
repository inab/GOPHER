package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;

/**
 * 
 * @author jmfernandez
 *
 */
public class PDBChains {
	protected String pdbcode;
	protected boolean ignoreReason;
	protected int currModel;
	
	protected CIFDict dict;
	protected HashMap<String, Character> toOneAA;
	protected HashSet<String> notAA;
	
	protected HashMap<String,PDBChain> chains;
	protected List<HashMap<String,PDBChain>> lchains;
	public PDBChains(String pdbcode, boolean ignoreReason,CIFDict dict) {
		this.pdbcode=pdbcode;
		this.ignoreReason=ignoreReason;
		this.dict = dict;
		toOneAA = dict.getMapping();
		notAA = dict.getNotMapping();
		currModel = 1;
		lchains = new ArrayList<HashMap<String,PDBChain>>();
		chains = new HashMap<String,PDBChain>();
		lchains.add(chains);
	}
	
	public void setNumModels(int numModel) {
		int atSize=lchains.size();
		if(atSize!=numModel) {
			if(atSize<numModel) {
				for(int origin=atSize;origin<numModel;origin++) {
					lchains.add(new HashMap<String,PDBChain>());
				}	
			} else {
				lchains = lchains.subList(0, numModel);
			}
		}
	}
	
	public void setCurrentModel(int modelNo) {
		if(modelNo>=lchains.size())
			setNumModels(modelNo);

		currModel = modelNo;
		chains = lchains.get(modelNo-1);
	}
	
	private List<List<PDBAmino>> getMissingList(String chainName) {
		HashMap<String,PDBChain> tmpchains = lchains.get(0);
		return (tmpchains.containsKey(chainName))?tmpchains.get(chainName).getMissingList():null; 
	}
	
	protected PDBChain getChain(String chainName) {
		PDBChain chain = null;
		if(!chains.containsKey(chainName)) {
			chain=new PDBChain(pdbcode,chainName,toOneAA,notAA,ignoreReason,getMissingList(chainName));
			chains.put(chainName, chain);
		} else {
			chain = chains.get(chainName);
		}
		
		return chain;
	}
	
	public PDBChain.Mapping addMapping(String chainName, String db, String id, PDBCoord start, PDBCoord stop) {
		PDBChain chain = getChain(chainName);
		return chain.addMapping(db, id, start, stop);
	}
	
	public void appendToArtifact(String chainName, String db, String id, String reason, PDBAmino residue) {
		// System.err.println("FOUND ARTIFACT FOR CHAIN '"+chain+"'");
		PDBChain chain = getChain(chainName);
		chain.appendToArtifact(db, id, reason, residue);
	}
	
	public List<PDBChain.Mapping> getMappingList(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.getMappingList();
	}
	
	public boolean hasMissingResidues(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.hasMissingResidues();
	}
	
	public boolean storeMissingResidue(String chainName, PDBRes residue) {
		PDBChain chain = getChain(chainName);
		return chain.storeMissingResidue(residue);
	}
	
	public boolean appendToSeqChain(String chainName, String... residues) {
		PDBChain chain = getChain(chainName);
		return chain.appendToSeqChain(residues);
	}
	
	public boolean appendToAtomChain(String chainName, PDBRes residue, PDBCoord prev_coord) {
		PDBChain chain = getChain(chainName);
		return chain.appendToChain(residue,prev_coord);
	}
	
	public boolean isOpenAtomChain(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.isOpen();
	}
	
	public boolean padAtomBoth(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.padBoth();
	}
	
	public StringBuilder getSeqChain(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.getSeqAminos();
	}
	
	public StringBuilder getAtomChain(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.getAminos();
	}
}
