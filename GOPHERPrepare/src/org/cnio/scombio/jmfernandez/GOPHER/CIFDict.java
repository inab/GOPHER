package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.HashSet;
import java.util.logging.Logger;
import java.util.Map;
import java.util.zip.GZIPInputStream;

/**
 * 
 * @author jmfernandez
 *
 */
public class CIFDict {
	protected final static Logger LOG=Logger.getLogger(CIFDict.class.getName());
	protected HashMap<String, Character> toOneAA;
	protected HashSet<String> notAA;
	
	public CIFDict(File cifdict)
		throws IOException
	{
		toOneAA = new HashMap<String,Character>();
		HashMap<String,String[]> toOneAADeriv = new HashMap<String,String[]>();
		notAA = new HashSet<String>();
		
		FileInputStream fis = null;
		GZIPInputStream gis = null;
		
		fis = new FileInputStream(cifdict);
		try {
			gis = new GZIPInputStream(fis);
		} catch(IOException ioe) {
			// IgnoreIT(R)
		}
		
		InputStreamReader isr = new InputStreamReader((gis!=null)?gis:fis);
		BufferedReader br = new BufferedReader(isr);
		
		boolean isPep = false;
		String threeLet = null;
		// boolean isAmb = false;
		Character oneLet = null;
		String[] parents = new String[]{};
		try {
			String line;
			while((line = br.readLine())!=null) {
				// '_chem_comp.type' => if($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING');
				// '_chem_comp.pdbx_type' => if($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING');
				if(line.startsWith("_chem_comp.type") || line.startsWith("_chem_comp.pdbx_type")) {
					if(isPep && threeLet!=null) {
						// Let's save it!
						// if(isAmb) {
						//	LOG.warning("aminoacid "+threeLet+" is ambiguous (one letter "+oneLet+", parents "+parents.toString()+")");
						// }
						
						// toOneAA.put(threeLet, (oneLet!=null && oneLet.equals('?'))?((parents.length>0)?parents:'X'):oneLet);
						
						if(oneLet!=null && oneLet.equals('?')) {
							if(parents.length>0) {
								toOneAADeriv.put(threeLet, parents);
							} else {
								toOneAA.put(threeLet, 'X');
							}
						} else {
							toOneAA.put(threeLet,oneLet);
						}
						
						// LOG.fine("aminoacid "+threeLet+" is "+oneLet");
					}
					
					String[] tokens=line.split("[ \t]+",2);
					String first = tokens[0];
					String type = tokens[1].toUpperCase().replaceAll("[\"']+", "").replaceFirst("[ \t]+$","");
					
					
					if("_chem_comp.type".equals(first)) {
						isPep = ("ATOMP".equals(type) || "L-PEPTIDE LINKING".equals(type));
					} else {
						isPep = isPep || ("ATOMP".equals(type) || "L-PEPTIDE LINKING".equals(type));
					}
					
					// isAmb=false;
					oneLet=null;
					threeLet=null;
					parents=new String[]{};
				} else if(!isPep && line.startsWith("_chem_comp.three_letter_code")) {
					String[] tokens=line.split("[ \t]+",2);
					String elem = tokens[1].toUpperCase().replaceAll("[\"']+", "").replaceFirst("[ \t]+$","");
				
					notAA.add(elem);
				} else if(isPep) {
					if(
						line.startsWith("_chem_comp.pdbx_ambiguous_flag") ||
						line.startsWith("_chem_comp.one_letter_code") ||
						line.startsWith("_chem_comp.three_letter_code") ||
						line.startsWith("_chem_comp.mon_nstd_parent_comp_id") ||
						line.startsWith("_chem_comp.pdbx_replaced_by")
					) {
						String[] tokens=line.split("[ \t]+",2);
						String first = tokens[0];
						String elem = tokens[1].toUpperCase().replaceAll("[\"']+", "").replaceFirst("[ \t]+$","");
						
						if("_chem_comp.pdbx_ambiguous_flag".equals(first)) {
							// if(!"N".equals(elem))
							// 	isAmb=true;
						} else if("_chem_comp.one_letter_code".equals(first)) {
							oneLet=elem.charAt(0);
						} else if("_chem_comp.three_letter_code".equals(first)) {
							threeLet=elem;
						} else if("_chem_comp.mon_nstd_parent_comp_id".equals(first)) {
							parents=elem.split("[ ,]+");
							if("?".equals(parents[0])) {
								parents=new String[] {};
							}
						} else if("_chem_comp.pdbx_replaced_by".equals(first)) {
							if(! "?".equals(elem) && parents.length==0) {
								parents=new String[] {elem};
							}
						}
					}
				}
			}
		} finally {
			try {
				br.close();
			} catch(IOException ioe) {
				// IgnoreIT(R)
			}
			try {
				isr.close();
			} catch(IOException ioe) {
				// IgnoreIT(R)
			}
			try {
				if(gis!=null)
					gis.close();
			} catch(IOException ioe) {
				// IgnoreIT(R)
			}
			try {
				if(fis!=null)
					fis.close();
			} catch(IOException ioe) {
				// IgnoreIT(R)
			}
		}
		
		if(isPep && threeLet!=null) {
			// Let's save it!
			// if(isAmb) {
			//	LOG.warning("aminoacid $threeLet is ambiguous (one letter "+oneLet+" parents "+parents.toString()+")");
			// }
			
			// toOneAA.put(threeLet, (oneLet!=null && oneLet.equals('?'))?((parents.length>0)?parents:'X'):oneLet);
			
			if(oneLet!=null && oneLet.equals('?')) {
				if(parents.length>0) {
					toOneAADeriv.put(threeLet, parents);
				} else {
					toOneAA.put(threeLet, 'X');
				}
			} else {
				toOneAA.put(threeLet,oneLet);
			}
			
			// LOG.fine("aminoacid "+threeLet+" is "+oneLet);
		}
		
		// Last, setting up the hashes!
		for(Map.Entry<String,String[]> kv: toOneAADeriv.entrySet()) {
			// Character one;
			String[] tval = kv.getValue();
			do {
				String alt = (tval.length>0)?tval[0]:"UNK";
				if(toOneAA.containsKey(alt)) {
					toOneAA.put(kv.getKey(), toOneAA.get(alt));
					break;
				} else if(toOneAADeriv.containsKey(alt)) {
					tval = toOneAADeriv.get(alt);
				} else {
					toOneAA.put(kv.getKey(), 'X');
					break;
				}
			} while(tval.getClass().isArray());
			
			//	LOG.fine(kv.getKey()+" interpreted as "+alt);
			//	one=(Character)tval;
			// } else {
			//	one=(Character)val;
			// LOG.fine(kv.getKey()+" is "+one);
		}
	}
	
	public HashMap<String,Character> getMapping()
	{
		return toOneAA;
	}
	
	public HashSet<String> getNotMapping()
	{
		return notAA;
	}
}
