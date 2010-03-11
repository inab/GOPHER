package org.cnio.scombio.jmfernandez.GOPHER;

import java.util.Arrays;
import java.util.Collection;
import java.util.Iterator;
import java.util.List;

/**
 * MiscHelper is a class which contains static methods
 * which help on common tasks like string array joining
 * 
 * @author jmfernandez
 *
 */
public class MiscHelper {
    public static <T> String join(Collection<T> s, String delimiter) {
        StringBuilder buffer = new StringBuilder();
        Iterator<T> iter = s.iterator();
        while (iter.hasNext()) {
            buffer.append(iter.next());
            if (iter.hasNext()) {
                buffer.append(delimiter);
            }
        }
        return buffer.toString();
    }
    
    public static <T> List<T> subList(List<T> origin,int start,int length) {
    	return origin.subList(start, start+length);
    }
    
    public static <T> List<T> subList(List<T> origin,int start) {
    	return origin.subList(start, origin.size());
    }
    
    public static <T> List<T> subList(T[] origin,int start,int length) {
    	return subList(Arrays.asList(origin),start,length);
    }
    
    public static <T> List<T> subList(T[] origin,int start) {
    	return subList(Arrays.asList(origin),start);
    }
    
    public static <T> T[] subArray(T[] origin,int start,int length) {
    	return subList(origin,start,length).toArray(origin);
    }
    
    public static <T> T[] subArray(T[] origin,int start) {
    	return subList(origin,start).toArray(origin);
    }
}
