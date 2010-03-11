package org.cnio.scombio.jmfernandez.GOPHER;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.net.JarURLConnection;
import java.net.URL;
import java.net.URLClassLoader;
import java.net.URLStreamHandlerFactory;
import java.util.jar.Attributes;

/**
 * Class loader used by GOPHER, so the job tasks are dynamically loaded.
 * Based on JarClassLoader from Sun Java Tutorials
 * @author jmfernandez
 *
 */
public class GOPHERClassLoader extends URLClassLoader {
	public GOPHERClassLoader(URL url) {
		super(new URL[] { url });
	}
	
	public GOPHERClassLoader(URL[] urls) {
		super(urls);
	}

	public GOPHERClassLoader(URL[] urls, ClassLoader parent) {
		super(urls, parent);
	}

	public GOPHERClassLoader(URL[] urls, ClassLoader parent, URLStreamHandlerFactory factory) {
		super(urls, parent, factory);
	}
	
	/**
	 * It returns the MainClass string from MANIFEST.MF inside any one of
	 * the URLs. It returns the first one it finds, so order does matter.
	 * @return
	 * @throws IOException
	 */
	public String getMainClassName()
		throws IOException
	{
		String retval = null;
		for(URL url: getURLs()) {
			URL u = new URL("jar","", url+"!/");
			JarURLConnection juc = (JarURLConnection)u.openConnection();
			Attributes attr = juc.getMainAttributes();
			if(attr != null) {
				retval = attr.getValue(Attributes.Name.MAIN_CLASS);
				break;
			}
		}
		
		return retval;
	}
	
	/**
	 * This method invokes the public static void main method from the provided URLs.
	 * @param name The name of the class with the public static void main method to invoke. 
	 * @param args The parameters for the main method invocation
	 * @throws ClassNotFoundException
	 * @throws NoSuchMethodException
	 * @throws InvocationTargetException
	 */
	public void invokeMainClass(String name, String[] args)
		throws ClassNotFoundException,
			NoSuchMethodException,
			InvocationTargetException
	{
		Class<?> c = loadClass(name,true);
		Method m = c.getMethod("main", new Class[] { args.getClass() });
		m.setAccessible(true);
		int mods = m.getModifiers();
		if(m.getReturnType() != void.class || !Modifier.isStatic(mods) || !Modifier.isPublic(mods)) {
			throw new NoSuchMethodException("main");
		}
		try {
			m.invoke(null, new Object[] { args });
		} catch(IllegalAccessException iae) {
			// Shouldn't happen with disabled checks
		}
	}
	
	/**
	 * This method invokes the first found public static void main method from the provided URLs.
	 * It is basically a combined, optimized version of invokeMainClass and getMainClassName. 
	 * @param name The name of the class with the public static void main method to invoke. 
	 * @param args The parameters for the main method invocation
	 * @throws ClassNotFoundException
	 * @throws NoSuchMethodException
	 * @throws InvocationTargetException
	 */
	public void invokeMainClass(String[] args)
		throws ClassNotFoundException,
			IOException,
			NoSuchMethodException,
			InvocationTargetException
	{
		invokeClassMethod("main",void.class,(Object)args);
	}
	
	/**
	 * This method invokes the first found public static void main method from the provided URLs.
	 * It is basically a combined, optimized version of invokeMainClass and getMainClassName. 
	 * @param name The name of the class with the public static void main method to invoke. 
	 * @param retvalClass The retval Class for the return value. 
	 * @param args The parameters for the main method invocation
	 * @throws ClassNotFoundException
	 * @throws NoSuchMethodException
	 * @throws InvocationTargetException
	 */
	public <Q,T extends Q> Q invokeClassMethod(String methodName, Class<T> retvalClass, Object... params)
		throws ClassNotFoundException,
			IOException,
			NoSuchMethodException,
			InvocationTargetException

	{
		Class<?>[] paramClasses = new Class[params.length];
		int parami=0;
		for(Object param: params) {
			if(param!=null)
				paramClasses[parami]=param.getClass();
			else
				paramClasses[parami]=Object.class;
			parami++;
		}
		return invokeClassMethod(methodName, retvalClass, paramClasses, params);
	}
	
	public <Q,T extends Q> Q invokeClassMethod(String methodName, Class<T> retvalClass, Class<?>[] paramClasses, Object... params)
		throws ClassNotFoundException,
			IOException,
			NoSuchMethodException,
			InvocationTargetException
	{
		ClassNotFoundException toThrow1=null;
		NoSuchMethodException toThrow2=null;
		T retval=null;
		for(URL url: getURLs()) {
			URL u = new URL("jar","", url+"!/");
			JarURLConnection juc = (JarURLConnection)u.openConnection();
			Attributes attr = juc.getMainAttributes();
			if(attr != null) {
				String name = attr.getValue(Attributes.Name.MAIN_CLASS);
				try {
					Class<?> c = loadClass(name);
					Method m = null;
					EachMethod: for(Method lm: c.getMethods()) {
						if(methodName.equals(lm.getName())) {
							int lmods = lm.getModifiers();
							Class<?>[] lmpars = lm.getParameterTypes();
							if(lm.getReturnType() == retvalClass && Modifier.isStatic(lmods) && Modifier.isPublic(lmods) && lmpars.length==params.length) {
								for(int li=0; li<paramClasses.length; li++) {
									if(!lmpars[li].isAssignableFrom(paramClasses[li])) {
										continue EachMethod;
									}
								}
								m = lm;
								break EachMethod;
							}
						}
					}
					if(m==null) {
						throw new NoSuchMethodException(methodName);
					}
					retval = retvalClass.cast(m.invoke(null, params));
					toThrow1 = null;
					toThrow2 = null;
					break;
				} catch(ClassNotFoundException cnfe) {
					// When main class is not found despite its manifest...
					if(toThrow1==null)
						toThrow1 = cnfe;
					continue;
				} catch(NoSuchMethodException nsme) {
					// When main method is not found despite its manifest...
					if(toThrow2==null)
						toThrow2 = nsme;
					continue;
				} catch(IllegalAccessException iae) {
					// Shouldn't happen with disabled checks
					continue;
				}
			}
		}
		
		// Throwing first caught exceptions
		if(toThrow1!=null)
			throw toThrow1;
		if(toThrow2!=null)
			throw toThrow2;
		
		return retval;
	}
}
