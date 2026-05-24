import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import helmet from 'helmet';
import path from 'path';

import { adminRoutes } from './modules/admin/admin.routes';
import { categoryRoutes } from './modules/category/category.routes';
import { eventRoutes } from './modules/events/event.routes';
import { placeRoutes } from './modules/place/place.routes';
import { scheduleRoutes } from './modules/schedule/schedule.routes';
import { uploadRoutes } from './modules/upload/upload.routes';
import { errorMiddleware, notFoundHandler } from './middlewares/error.middleware';
import { requestLogMiddleware } from './middlewares/request-log.middleware';
import { sendResponse } from './utils/response';

dotenv.config();

export const app = express();

app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        'img-src': ["'self'", 'data:', 'blob:', 'https:'],
      },
    },
  }),
);
app.use(
  cors({
    origin: process.env.CORS_ORIGIN === '*' ? '*' : process.env.CORS_ORIGIN,
  }),
);
app.use(express.json());
app.use(requestLogMiddleware);
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

app.get('/health', (_req, res) => {
  return sendResponse(res, 200, 'Roamy Backend is healthy', {
    service: 'roamy-backend',
    uptime: process.uptime(),
  });
});

app.use('/api/v1/categories', categoryRoutes);
app.use('/api/v1/places', placeRoutes);
app.use('/api/v1/schedules', scheduleRoutes);
app.use('/api/v1/upload', uploadRoutes);
app.use('/api/v1/events', eventRoutes);
app.use('/api/v1/admin', adminRoutes);

const adminDistPath = path.join(process.cwd(), 'admin', 'dist');
app.use('/admin', express.static(adminDistPath));
app.get(/^\/admin(?:\/.*)?$/, (_req, res, next) => {
  res.sendFile(path.join(adminDistPath, 'index.html'), (error) => {
    if (error) {
      next();
    }
  });
});

app.use(notFoundHandler);
app.use(errorMiddleware);
