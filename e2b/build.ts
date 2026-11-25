// Build the template in E2B's cloud (no local Docker): `bun e2b/build.ts`
// Needs E2B_API_KEY. Template name: E2B_POSTIZ_TEMPLATE (default "postiz").
import { Template, defaultBuildLogger } from "e2b";
import { template } from "./template";

await Template.build(template, process.env.E2B_POSTIZ_TEMPLATE || "postiz", {
  cpuCount: 4,
  memoryMB: 8192,
  onBuildLogs: defaultBuildLogger(),
});
