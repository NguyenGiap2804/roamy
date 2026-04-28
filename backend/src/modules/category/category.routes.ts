import { Router } from 'express';

import { validate } from '../../utils/validate';
import { categoryController } from './category.controller';
import { categoryCreateSchema } from './category.model';

export const categoryRoutes = Router();

categoryRoutes.get('/', categoryController.findAll);
categoryRoutes.post('/', validate(categoryCreateSchema), categoryController.create);
