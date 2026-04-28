import { NextFunction, Request, Response } from 'express';

import { sendResponse } from '../../utils/response';
import { categoryService } from './category.service';

export class CategoryController {
  async findAll(_req: Request, res: Response, next: NextFunction) {
    try {
      const categories = await categoryService.findAll();
      return sendResponse(res, 200, 'Categories fetched successfully', categories);
    } catch (error) {
      return next(error);
    }
  }

  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const category = await categoryService.create(req.body);
      return sendResponse(res, 201, 'Category created successfully', category);
    } catch (error) {
      return next(error);
    }
  }
}

export const categoryController = new CategoryController();
