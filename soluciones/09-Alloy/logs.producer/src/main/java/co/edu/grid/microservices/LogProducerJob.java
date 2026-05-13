package co.edu.grid.microservices;

import io.quarkus.scheduler.Scheduled;
import io.quarkus.scheduler.ScheduledExecution;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.jboss.logging.Logger;
import org.jboss.logging.Logger.Level;

import java.util.concurrent.ThreadLocalRandom;

@ApplicationScoped              
public class LogProducerJob {

    private final Logger log;

    @Inject
    public LogProducerJob(Logger log) {
        this.log = log;
    }

    @Scheduled(every="60s")
    void produceLogsEveryMinute(ScheduledExecution execution) {
        produceLog("Log de prueba "+execution.getScheduledFireTime());
    }

    @Scheduled(cron="0 15 10 * * ?") 
    void cronJob(ScheduledExecution execution) {
        produceLog("Log de prueba "+execution.getScheduledFireTime());
    }

    private void produceLog(String message) {
        log.log(generateRandomLevel(),message);
    }

    private Level generateRandomLevel(){
        final var values = Level.values();
        return values[ThreadLocalRandom.current().nextInt(values.length)];
    }
}