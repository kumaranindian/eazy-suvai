import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";

import * as impl from "./publish";

/** Callable: dry run or publish of the draft as a new version (M06, FR-063 to FR-066). */
export const publishMenu = onCall({ memory: "512MiB", timeoutSeconds: 120 }, async (request) =>
  impl.publishMenu(getFirestore(), request.auth, request.data),
);

/** Callable: publishes an earlier version again, and replaces the draft (FR-096). */
export const rollbackMenu = onCall(async (request) => impl.rollbackMenu(getFirestore(), request.auth, request.data));

/** Callable: replaces the draft with the live version (FR-096). */
export const discardDraft = onCall(async (request) => impl.discardDraft(getFirestore(), request.auth, request.data));

/** Callable: the draft rendered by the public menu renderer, for the preview (FR-061). */
export const previewMenu = onCall({ memory: "512MiB" }, async (request) =>
  impl.previewMenu(getFirestore(), request.auth, request.data),
);
