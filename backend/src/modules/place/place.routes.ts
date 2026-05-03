import { Router } from 'express';
import { z } from 'zod';

import { validate } from '../../utils/validate';
import { placeController } from './place.controller';
import { placeCreateSchema, placeIdSchema, placeUpdateSchema } from './place.model';

export const placeRoutes = Router();

const placeListSchema = z.object({
  query: z.object({
    categoryId: z.uuid().optional(),
    sort: z.enum(['rating', 'createdAt']).optional(),
    limit: z.coerce.number().int().min(1).max(50).optional(),
  }),
});

placeRoutes.get('/', validate(placeListSchema), placeController.findAll);
placeRoutes.get('/:id', validate(placeIdSchema), placeController.findById);
placeRoutes.post('/', validate(placeCreateSchema), placeController.create);
placeRoutes.patch('/:id', validate(placeUpdateSchema), placeController.update);
placeRoutes.delete('/:id', validate(placeIdSchema), placeController.delete);
