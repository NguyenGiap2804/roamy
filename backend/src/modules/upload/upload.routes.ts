import { Router } from 'express';
import multer from 'multer';
import { sendResponse } from '../../utils/response';
import { uploadService } from './upload.service';

export const uploadRoutes = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only images are allowed'));
    }
  },
});

uploadRoutes.post('/', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return sendResponse(res, 400, 'No image provided');
    }

    const requestOrigin = `${req.protocol}://${req.get('host')}`;
    const url = await uploadService.uploadImage(req.file, requestOrigin);

    return sendResponse(res, 200, 'Image uploaded successfully', { url });
  } catch (error) {
    console.error('Upload error:', error);
    return sendResponse(res, 500, `Upload failed: ${error instanceof Error ? error.message : String(error)}`);
  }
});
