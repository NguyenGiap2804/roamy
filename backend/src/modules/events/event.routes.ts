import { Router } from 'express';

import { validate } from '../../utils/validate';
import { eventController } from './event.controller';
import { eventCreateSchema } from './event.model';

export const eventRoutes = Router();

eventRoutes.post('/', validate(eventCreateSchema), eventController.create);
