import { Router } from 'express';

import { adminController } from './admin.controller';
import { authenticateAdmin } from './admin.auth';

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
