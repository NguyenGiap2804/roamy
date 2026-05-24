import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import helmet from 'helmet';
import path from 'path';

import { adminRoutes } from './modules/admin/admin.routes';
import { authRoutes, meRoutes } from './modules/auth/auth.routes';
import { authenticateUser, optionalUser } from './modules/auth/auth.middleware';
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

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/me', meRoutes);
app.use('/api/v1/categories', authenticateUser, categoryRoutes);
app.use('/api/v1/places', authenticateUser, placeRoutes);
app.use('/api/v1/schedules', authenticateUser, scheduleRoutes);
app.use('/api/v1/upload', authenticateUser, uploadRoutes);
app.use('/api/v1/events', optionalUser, eventRoutes);
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
