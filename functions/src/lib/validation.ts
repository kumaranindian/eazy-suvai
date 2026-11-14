import type { z } from "zod";

import { appError } from "./errors";

/**
 * Validates callable input with a zod schema. Every callable must use this
 * (architecture §7).
 *
 * @param schema The zod schema.
 * @param data The raw `request.data`.
 * @return The parsed, typed data.
 */
export function parseInput<S extends z.ZodType>(schema: S, data: unknown): z.infer<S> {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw appError("invalid-input", "Invalid input.", {
      issues: result.error.issues.map((i) => ({
        path: i.path.join("."),
        message: i.message,
      })),
    });
  }
  return result.data;
}
