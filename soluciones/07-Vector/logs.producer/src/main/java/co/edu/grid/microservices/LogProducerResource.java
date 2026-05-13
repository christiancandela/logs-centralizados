package co.edu.grid.microservices;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.logging.Logger;

@Path("/logs")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class LogProducerResource {

    private static final Logger LOG = Logger.getLogger(LogProducerResource.class);

    @POST
    public Response post(LogRequest log) {
        LOG.log(log.level(),log.message());
        return Response.ok(log).build();
    }
}