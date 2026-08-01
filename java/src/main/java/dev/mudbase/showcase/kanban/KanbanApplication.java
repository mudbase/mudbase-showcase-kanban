package dev.mudbase.showcase.kanban;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Mudbase Showcase — Kanban: a team task board served entirely by Mudbase (cloud.mudbase.dev) —
 * auth, database, role-based access control, no custom backend of any kind. This Spring Boot +
 * Thymeleaf app is the Java reimplementation of the reference Next.js app at ../web - same
 * Mudbase project, same three collections (lists/cards/activity) plus the single-document
 * `boards` collection that supplies a real ObjectId board id, same RBAC matrix and business
 * rules; see plan/build-plan.md for what deliberately differs (server-rendered forms instead of
 * client-side drag/drop or realtime, and why).
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class KanbanApplication {

  public static void main(String[] args) {
    SpringApplication.run(KanbanApplication.class, args);
  }
}
