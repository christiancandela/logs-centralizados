package co.edu.grid.microservices;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.jboss.logging.Logger;
import org.junit.jupiter.api.*;

import java.time.LocalDateTime;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class LogResourceTest {

    private static LogRequest log;

    @BeforeAll
    static void beforeAll() {
        log = new LogRequest(Logger.Level.INFO,"Log Test " + LocalDateTime.now());
    }

    @Test
    @Order(1)
    void testPostEndpoint() {
        var logResult = given()
          .when().body(log).contentType(ContentType.JSON).post("/logs")
          .then()
                .statusCode(200)
                .contentType(ContentType.JSON)
                .body("message",is(log.message()))
                .body("level",is(log.level().toString()))
                .extract().as(LogRequest.class);
    }
}