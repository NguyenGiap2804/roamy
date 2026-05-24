import { NextFunction, Request, Response } from 'express';

import { observabilityService } from '../observability/observability.service';
import { requireUserId } from '../auth/auth.middleware';
import { sendResponse } from '../../utils/response';
import { placeService } from './place.service';

export class PlaceController {
  async findAll(req: Request, res: Response, next: NextFunction) {
    try {
      const categoryId = typeof req.query.categoryId === 'string' ? req.query.categoryId : undefined;
      const sort = req.query.sort === 'rating' ? 'rating' as const : undefined;
      const limit = typeof req.query.limit === 'string' ? parseInt(req.query.limit, 10) : undefined;
      const places = await placeService.findAll({
        userId: requireUserId(req),
        categoryId,
        sort,
        limit: Number.isFinite(limit) ? limit : undefined,
      });
      return sendResponse(res, 200, 'Places fetched successfully', places);
    } catch (error) {
      return next(error);
    }
  }

  async findById(req: Request, res: Response, next: NextFunction) {
    try {
      const place = await placeService.findById(req.params.id as string, requireUserId(req));
      return sendResponse(res, 200, 'Place fetched successfully', place);
    } catch (error) {
      return next(error);
    }
  }

  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const place = await placeService.create(requireUserId(req), req.body);
      void observabilityService.recordSystemEvent({
        type: 'place',
        action: 'create',
        resourceType: 'place',
        resourceId: place.id,
        message: `Created place ${place.name}`,
        userId: req.userId,
        deviceId: req.deviceId,
        requestId: req.requestId,
        metadata: { name: place.name, categoryId: place.categoryId },
      });
      return sendResponse(res, 201, 'Place created successfully', place);
    } catch (error) {
      return next(error);
    }
  }

  async update(req: Request, res: Response, next: NextFunction) {
    try {
      const place = await placeService.update(req.params.id as string, req.body, requireUserId(req));
      void observabilityService.recordSystemEvent({
        type: 'place',
        action: 'update',
        resourceType: 'place',
        resourceId: place.id,
        message: `Updated place ${place.name}`,
        userId: req.userId,
        deviceId: req.deviceId,
        requestId: req.requestId,
        metadata: { changedFields: Object.keys(req.body ?? {}) },
      });
      return sendResponse(res, 200, 'Place updated successfully', place);
    } catch (error) {
      return next(error);
    }
  }

  async delete(req: Request, res: Response, next: NextFunction) {
    try {
      const deleted = await placeService.delete(req.params.id as string, requireUserId(req));
      void observabilityService.recordSystemEvent({
        type: 'place',
        action: 'delete',
        resourceType: 'place',
        resourceId: deleted.id,
        message: `Deleted place ${deleted.id}`,
        userId: req.userId,
        deviceId: req.deviceId,
        requestId: req.requestId,
      });
      return sendResponse(res, 200, 'Place deleted successfully', deleted);
    } catch (error) {
      return next(error);
    }
  }
}

export const placeController = new PlaceController();
