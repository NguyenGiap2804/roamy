import { NextFunction, Request, Response } from 'express';

import { observabilityService } from '../observability/observability.service';
import { requireUserId } from '../auth/auth.middleware';
import { sendResponse } from '../../utils/response';
import { categoryService } from './category.service';

export class CategoryController {
  async findAll(req: Request, res: Response, next: NextFunction) {
    try {
      const categories = await categoryService.findAll(requireUserId(req));
      return sendResponse(res, 200, 'Categories fetched successfully', categories);
    } catch (error) {
      return next(error);
    }
  }

  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const category = await categoryService.create(requireUserId(req), req.body);
      void observabilityService.recordSystemEvent({
        type: 'category',
        action: 'create',
        resourceType: 'category',
        resourceId: category.id,
        message: `Created category ${category.name}`,
        userId: req.userId,
        deviceId: req.deviceId,
        requestId: req.requestId,
      });
      return sendResponse(res, 201, 'Category created successfully', category);
    } catch (error) {
      return next(error);
    }
  }
}

export const categoryController = new CategoryController();
