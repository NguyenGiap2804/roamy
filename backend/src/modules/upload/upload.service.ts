import { v2 as cloudinary } from 'cloudinary';
import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

import { ValidationError } from '../../utils/errors';

const uploadsDir = path.join(process.cwd(), 'uploads');

export const supportedImageMimeTypes = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/heic',
  'image/heif',
]);

export class UploadService {
  async uploadImage(file: Express.Multer.File, requestOrigin: string) {
    validateUploadedImage(file);

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

export function validateUploadedImage(file: Express.Multer.File) {
  if (!supportedImageMimeTypes.has(file.mimetype)) {
    throw new ValidationError(
      'Only JPEG, PNG, WebP, GIF, HEIC, and HEIF images are allowed',
    );
  }

  if (!file.buffer.length) {
    throw new ValidationError('Uploaded image is empty');
  }

  if (!matchesImageSignature(file.buffer, file.mimetype)) {
    throw new ValidationError('Uploaded file is not a valid image');
  }
}

function matchesImageSignature(buffer: Buffer, mimetype: string) {
  switch (mimetype) {
    case 'image/jpeg':
    case 'image/jpg':
      return isJpeg(buffer);
    case 'image/png':
      return isPng(buffer);
    case 'image/webp':
      return isWebp(buffer);
    case 'image/gif':
      return isGif(buffer);
    case 'image/heic':
    case 'image/heif':
      return isHeicLike(buffer);
    default:
      return false;
  }
}

function isJpeg(buffer: Buffer) {
  return (
    buffer.length >= 3 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff
  );
}

function isPng(buffer: Buffer) {
  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  return (
    buffer.length >= pngSignature.length &&
    pngSignature.every((byte, index) => buffer[index] === byte)
  );
}

function isGif(buffer: Buffer) {
  if (buffer.length < 6) {
    return false;
  }

  const header = buffer.subarray(0, 6).toString('ascii');
  return header === 'GIF87a' || header === 'GIF89a';
}

function isWebp(buffer: Buffer) {
  return (
    buffer.length >= 12 &&
    buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
    buffer.subarray(8, 12).toString('ascii') === 'WEBP'
  );
}

function isHeicLike(buffer: Buffer) {
  if (buffer.length < 12) {
    return false;
  }

  if (buffer.subarray(4, 8).toString('ascii') !== 'ftyp') {
    return false;
  }

  const brand = buffer.subarray(8, 12).toString('ascii');
  return [
    'heic',
    'heix',
    'hevc',
    'hevx',
    'heim',
    'heis',
    'mif1',
    'msf1',
  ].includes(brand);
}
