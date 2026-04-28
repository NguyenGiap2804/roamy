import { Router } from 'express';

import { validate } from '../../utils/validate';
import { scheduleController } from './schedule.controller';
import {
  scheduleCreateSchema,
  scheduleIdSchema,
  scheduleListSchema,
  scheduleUpdateSchema,
} from './schedule.model';

export const scheduleRoutes = Router();

scheduleRoutes.get('/', validate(scheduleListSchema), scheduleController.findAll);
scheduleRoutes.post('/', validate(scheduleCreateSchema), scheduleController.create);
scheduleRoutes.patch('/:id', validate(scheduleUpdateSchema), scheduleController.update);
scheduleRoutes.delete('/:id', validate(scheduleIdSchema), scheduleController.delete);
