package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

/**
 * 
 * @author jmfernandez
 *
 */
public class PDBChains {
	protected final String pdbcode;
	protected final boolean ignoreReason;
	protected boolean isSharedMissingList;
	
	protected final CIFDict dict;
	protected final HashMap<String, Character> toOneAA;
	protected final HashSet<String> notAA;
	
	protected int currModel;
	
	protected Map<String,PDBChain> chains;
	protected List<Map<String,PDBChain>> lchains;
	
	public PDBChains(String pdbcode, boolean ignoreReason,CIFDict dict) {
		this.pdbcode=pdbcode;
		this.ignoreReason=ignoreReason;
		this.dict = dict;
		toOneAA = dict.getMapping();
		notAA = dict.getNotMapping();
		currModel = 1;
		lchains = new ArrayList<Map<String,PDBChain>>();
		chains = new HashMap<String,PDBChain>();
		lchains.add(chains);
		
		isSharedMissingList=true;
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
		currModel = modelNo;
		chains = getModel(modelNo);
	}
	
	private Map<String,PDBChain> getModel(int modelNo) {
		if(modelNo>=lchains.size()) 
			setNumModels(modelNo);
		
		return lchains.get(modelNo-1);
	}
	
	private List<LabelledSegment<PDBAmino>> getMissingList(int modelNo, String chainName) {
		Map<String,PDBChain> tmpchains = getModel(isSharedMissingList?1:modelNo);
		return (tmpchains.containsKey(chainName))?tmpchains.get(chainName).getMissingList():null; 
	}
	
	private List<LabelledSegment<PDBAmino>> getMissingList(String chainName) {
		return getMissingList(1,chainName);
	}
	
	protected PDBChain getChain(String chainName) {
		PDBChain chain = null;
		if(!chains.containsKey(chainName)) {
			chain=new PDBChain(pdbcode,currModel,chainName,toOneAA,notAA,ignoreReason,getMissingList(chainName));
			chains.put(chainName, chain);
		} else {
			chain = chains.get(chainName);
		}
		
		return chain;
	}
	
	protected PDBChain getModelChain(int modelNo, String chainName) {
		PDBChain chain = null;
		Map<String,PDBChain> chains=getModel(modelNo);
		if(!chains.containsKey(chainName)) {
			chain=new PDBChain(pdbcode,modelNo,chainName,toOneAA,notAA,ignoreReason,getMissingList(modelNo,chainName));
			chains.put(chainName, chain);
		} else {
			chain = chains.get(chainName);
		}
		
		return chain;
	}
	
	public boolean hasChain(String chainName) {
		return chains.containsKey(chainName);
	}
	
	public String getChainDescription(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.getDescription();
	}
	
	public void setChainDescription(String chainName, String description) {
		PDBChain chain = getChain(chainName);
		chain.setDescription(description);
	}
	
	public Mapping addMapping(String chainName, String db, String id, PDBCoord start, PDBCoord stop) {
		PDBChain chain = getChain(chainName);
		return chain.addMapping(db, id, start, stop);
	}
	
	public void appendToArtifact(String chainName, String db, String id, String reason, PDBAmino residue) {
		// System.err.println("FOUND ARTIFACT FOR CHAIN '"+chain+"'");
		PDBChain chain = getChain(chainName);
		chain.appendToArtifact(db, id, reason, residue);
	}
	
	public boolean hasMissingResidues(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.hasMissingResidues();
	}
	
	public boolean storeMissingResidue(int modelNo, String chainName, PDBRes residue) {
		if(modelNo>0) {
			isSharedMissingList=false;
		} else {
			isSharedMissingList=true;
			modelNo=1;
		}
		PDBChain chain = getModelChain(modelNo,chainName);
		return chain.storeMissingResidue(residue);
	}
	
	public boolean appendToSeqChain(String chainName, String... residues) {
		PDBChain chain = getChain(chainName);
		return chain.appendToSeqChain(residues);
	}
	
	public boolean appendToAtomChain(String chainName, PDBRes residue, PDBCoord prev_coord) {
		PDBChain chain = getChain(chainName);
		return chain.appendToResChain(residue,prev_coord);
	}
	
	public boolean isOpenAtomChain(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.isOpen();
	}
	
	public boolean padAtomBoth(String chainName) {
		PDBChain chain = getChain(chainName);
		return chain.doTER();
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
