package net.local.webapp;

import java.util.HashMap;
import java.util.Map;

import javax.servlet.ServletContext;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.Response;

import com.profesorfalken.jpowershell.PowerShell;
import com.profesorfalken.jpowershell.PowerShellNotAvailableException;
import com.profesorfalken.jpowershell.PowerShellResponse;

@Path("/getip")
public class vm2ip {
	
	@Context ServletContext _context;
	
	@GET
	@Path("/{param}")
	public Response getMsg(@PathParam("param") String msg) {
		String output = "Jersey say : " + msg;
		return Response.status(200).entity(output).build();
	}
	
	public String fetchIP(String scriptFullPath, String host, String vm) {
		PowerShell powerShell = null;
		PowerShellResponse response = null;
		try {
			// Creates PowerShell session
			powerShell = PowerShell.openSession();
			// Increase timeout to give enough time to the script to finish
			Map<String, String> config = new HashMap<String, String>();
			config.put("maxWait", "80000");
	
		    String script = scriptFullPath;
		    String scriptParams = "-vmName " + vm + " -serverName " + host;
	
		    response = powerShell.configuration(config).executeScript(script, scriptParams);
			// Print results if the script
			String result = response.getCommandOutput();
			return result;
		} catch (PowerShellNotAvailableException ex) {
			// Handle error when PowerShell is not available in the system
			// Maybe try in another way?
		} finally {
			// Always close PowerShell session to free resources.
			if (powerShell != null)
				powerShell.close();
		}
		return null;
	}
	
	@GET
	public Response getIp(@QueryParam("host") String host,
			@QueryParam("vm") String vm/*@Context UriInfo uriInfo*/) {
		String fullPath = _context.getRealPath("/WEB-INF") + "/get-VM-IP.ps1";
		String IP = fetchIP(fullPath, host, vm);
		String output = vm + "@" + host + ":" + IP;
		return Response.status(200).entity(output).build();
		/*
		MultivaluedMap<String, String> queryParams = uriInfo.getQueryParameters(); 
	    String nameParam = queryParams.getFirst("vm");
	    */
		
	}
	
	
}
