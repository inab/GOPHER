package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.zip.GZIPInputStream;

/**
 * 
 * @author jmfernandez
 *
 */
public class CIFDict {
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
		
		boolean ispep = false;
		String threelet = null;
		boolean isamb = false;
		Character onelet = null;
		String[] parents = new String[]{};
		try {
			String line;
			while((line = br.readLine())!=null) {
				// '_chem_comp.type' => if($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING');
				// '_chem_comp.pdbx_type' => if($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING');
				if(line.startsWith("_chem_comp.type") || line.startsWith("_chem_comp.pdbx_type")) {
					if(ispep && threelet!=null) {
						// Let's save it!
						// if(isamb) {
						//	System.err.println("Warning: aminoacid "+threelet+" is ambiguous (one letter "+onelet+", parents "+parents.toString()+")");
						// }
						
						// toOneAA.put(threelet, (onelet!=null && onelet.equals('?'))?((parents.length>0)?parents:'X'):onelet);
						
						if(onelet!=null && onelet.equals('?')) {
							if(parents.length>0) {
								toOneAADeriv.put(threelet, parents);
							} else {
								toOneAA.put(threelet, 'X');
							}
						} else {
							toOneAA.put(threelet,onelet);
						}
						
						// System.err.println("Notice: aminoacid "+threelet+" is "+onelet");
					}
					
					String[] tokens=line.split("[ \t]+",2);
					String first = tokens[0];
					String type = tokens[1].toUpperCase().replaceAll("[\"']+", "").replaceFirst("[ \t]+$","");
					
					
					if("_chem_comp.type".equals(first)) {
						ispep = ("ATOMP".equals(type) || "L-PEPTIDE LINKING".equals(type));
					} else {
						ispep = ispep || ("ATOMP".equals(type) || "L-PEPTIDE LINKING".equals(type));
					}
					
					isamb=false;
					onelet=null;
					threelet=null;
					parents=new String[]{};
				} else if(!ispep && line.startsWith("_chem_comp.three_letter_code")) {
					String[] tokens=line.split("[ \t]+",2);
					String elem = tokens[1].toUpperCase().replaceAll("[\"']+", "").replaceFirst("[ \t]+$","");
				
					notAA.add(elem);
				} else if(ispep) {
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
							if(!"N".equals(elem))
								isamb=true;
						} else if("_chem_comp.one_letter_code".equals(first)) {
							onelet=elem.charAt(0);
						} else if("_chem_comp.three_letter_code".equals(first)) {
							threelet=elem;
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
		
		if(ispep && threelet!=null) {
			// Let's save it!
			// if(isamb) {
			//	System.err.println("Warning: aminoacid $threelet is ambiguous (one letter "+onelet+" parents "+parents.toString()+")");
			// }
			
			// toOneAA.put(threelet, (onelet!=null && onelet.equals('?'))?((parents.length>0)?parents:'X'):onelet);
			
			if(onelet!=null && onelet.equals('?')) {
				if(parents.length>0) {
					toOneAADeriv.put(threelet, parents);
				} else {
					toOneAA.put(threelet, 'X');
				}
			} else {
				toOneAA.put(threelet,onelet);
			}
			
			// System.err.println("Notice: aminoacid "+threelet+" is "+onelet);
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
			
			//	System.err.println(kv.getKey()+" interpreted as "+alt);
			//	one=(Character)tval;
			// } else {
			//	one=(Character)val;
			// System.err.println(kv.getKey()+" is "+one);
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