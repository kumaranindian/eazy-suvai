import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onObjectFinalized } from "firebase-functions/v2/storage";

import { processUploadedImage, type ImageStore } from "./process-image";

/** ImageStore backed by a Cloud Storage bucket. */
export function bucketStore(bucketName?: string): ImageStore {
  const bucket = getStorage().bucket(bucketName);
  return {
    async read(path) {
      const [data] = await bucket.file(path).download();
      return data;
    },
    async write(path, data, { contentType, cacheControl, metadata }) {
      await bucket.file(path).save(data, {
        resumable: false,
        contentType,
        metadata: { contentType, cacheControl, metadata },
      });
    },
    async remove(path) {
      await bucket.file(path).delete({ ignoreNotFound: true });
    },
  };
}

/**
 * Storage trigger on the default bucket: validates uploads under
 * `restaurants/{rid}/images/` and writes renditions (M02, FR-102).
 * See {@link processUploadedImage}.
 */
export const processImage = onObjectFinalized(
  { memory: "1GiB", timeoutSeconds: 120, concurrency: 1 },
  async (event) => {
    const object = event.data;
    await processUploadedImage(
      { db: getFirestore(), store: bucketStore(object.bucket) },
      {
        name: object.name,
        contentType: object.contentType,
        size: object.size,
        metadata: object.metadata,
        timeCreated: object.timeCreated,
      },
    );
  },
);
