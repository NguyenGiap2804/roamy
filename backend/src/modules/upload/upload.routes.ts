import { NextFunction, Request, Response, Router } from "express";
import multer from "multer";
import { ValidationError } from "../../utils/errors";
import { sendResponse } from "../../utils/response";
import { supportedImageMimeTypes, uploadService } from "./upload.service";

export const uploadRoutes = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (_req, file, cb) => {
    if (supportedImageMimeTypes.has(file.mimetype)) {
      cb(null, true);
    } else {
      cb(
        new ValidationError(
          "Only JPEG, PNG, WebP, GIF, HEIC, and HEIF images are allowed",
        ),
      );
    }
  },
});

function uploadImage(req: Request, res: Response, next: NextFunction) {
  upload.single("image")(req, res, (error) => {
    if (error instanceof multer.MulterError) {
      if (error.code === "LIMIT_FILE_SIZE") {
        return next(new ValidationError("Image must be 5MB or smaller"));
      }

      return next(new ValidationError(error.message));
    }

    return next(error);
  });
}

export function createUploadHandler(service = uploadService) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.file) {
        throw new ValidationError("No image provided");
      }

      const requestOrigin = `${req.protocol}://${req.get("host")}`;
      const url = await service.uploadImage(req.file, requestOrigin);

      return sendResponse(res, 200, "Image uploaded successfully", { url });
    } catch (error) {
      return next(error);
    }
  };
}

uploadRoutes.post("/", uploadImage, createUploadHandler());
