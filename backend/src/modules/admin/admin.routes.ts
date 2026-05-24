import { Router } from 'express';

import { adminController } from './admin.controller';
import { authenticateAdmin } from './admin.auth';
import { validate } from '../../utils/validate';
import {
  categoryIdSchema,
  categoryUpdateSchema,
} from '../category/category.model';
import { placeIdSchema, placeUpdateSchema } from '../place/place.model';
import {
  scheduleIdSchema,
  scheduleUpdateSchema,
} from '../schedule/schedule.model';

export const adminRoutes = Router();

adminRoutes.post('/auth/login', adminController.login);
adminRoutes.use(authenticateAdmin);
adminRoutes.get('/overview', adminController.overview);
adminRoutes.get('/health', adminController.health);
adminRoutes.get('/places', adminController.places);
adminRoutes.get('/categories', adminController.categories);
adminRoutes.get('/schedules', adminController.schedules);
adminRoutes.get('/activity', adminController.activity);
adminRoutes.get('/errors', adminController.errors);
adminRoutes.get('/requests', adminController.requests);
adminRoutes.get('/uploads', adminController.uploads);
adminRoutes.get('/users', adminController.users);
adminRoutes.post('/images/check', adminController.checkImages);
adminRoutes.get('/maintenance/retention/preview', adminController.retentionPreview);
adminRoutes.post('/maintenance/retention/run', adminController.runRetention);
adminRoutes.patch('/places/:id', validate(placeUpdateSchema), adminController.updatePlace);
adminRoutes.delete('/places/:id', validate(placeIdSchema), adminController.deletePlace);
adminRoutes.patch(
  '/categories/:id',
  validate(categoryUpdateSchema),
  adminController.updateCategory,
);
adminRoutes.delete(
  '/categories/:id',
  validate(categoryIdSchema),
  adminController.deleteCategory,
);
adminRoutes.patch(
  '/schedules/:id',
  validate(scheduleUpdateSchema),
  adminController.updateSchedule,
);
adminRoutes.delete(
  '/schedules/:id',
  validate(scheduleIdSchema),
  adminController.deleteSchedule,
);
