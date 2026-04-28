import { v2 as cloudinary } from 'cloudinary';
import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

const uploadsDir = path.join(process.cwd(), 'uploads');

export class UploadService {
  async uploadImage(file: Express.Multer.File, requestOrigin: string) {
    if (this.hasCloudinaryConfig()) {
      return this.uploadToCloudinary(file);
    }

    return this.uploadToLocalDisk(file, requestOrigin);
  }

  private async uploadToLocalDisk(
    file: Express.Multer.File,
    requestOrigin: string,
  ) {
    await fs.mkdir(uploadsDir, { recursive: true });
    const extension = path.extname(file.originalname) || '.jpg';
    const filename = `${uuidv4()}${extension}`;
    const filepath = path.join(uploadsDir, filename);
    await fs.writeFile(filepath, file.buffer);

    const baseUrl = process.env.PUBLIC_BASE_URL || requestOrigin;
    return `${baseUrl}/uploads/${filename}`;
  }

  private uploadToCloudinary(file: Express.Multer.File) {
    cloudinary.config({
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      api_key: process.env.CLOUDINARY_API_KEY,
      api_secret: process.env.CLOUDINARY_API_SECRET,
    });

    return new Promise<string>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'roamy',
          resource_type: 'image',
        },
        (error, result) => {
          if (error || !result?.secure_url) {
            reject(error ?? new Error('Cloudinary upload failed'));
            return;
          }

          resolve(result.secure_url);
        },
      );

      stream.end(file.buffer);
    });
  }

  private hasCloudinaryConfig() {
    return Boolean(
      process.env.CLOUDINARY_CLOUD_NAME &&
        process.env.CLOUDINARY_API_KEY &&
        process.env.CLOUDINARY_API_SECRET,
    );
  }
}

export const uploadService = new UploadService();
