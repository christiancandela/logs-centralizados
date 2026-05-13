package co.edu.grid.microservices;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.jboss.logging.Logger;


public record LogRequest(@NotNull Logger.Level level, @NotBlank String message) {
}
