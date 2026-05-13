package co.edu.grid.microservices;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.logging.Logger;

@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
public class ErrorResource {

    private static final Logger LOG = Logger.getLogger(ErrorResource.class);

    @GET
    @Path("/error")
    public Response triggerError() {
        LOG.warn("Simulando error intencional en GET /api/error");
        String s = null;
        return Response.ok(s.length()).build(); // NullPointerException intencional
    }
}
