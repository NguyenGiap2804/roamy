import { NextFunction, Request, Response } from 'express';

import { adminImageHealthService } from './admin.image-health';
import { loginAdmin } from './admin.auth';
import { adminService, AdminListOptions } from './admin.service';
import { categoryService } from '../category/category.service';
import { retentionService } from '../maintenance/retention.service';
import { observabilityService } from '../observability/observability.service';
import { placeService } from '../place/place.service';
import { scheduleService } from '../schedule/schedule.service';
import { sendResponse } from '../../utils/response';

export class AdminController {
  login(req: Request, res: Response, next: NextFunction) {
    try {
      const result = loginAdmin(
        String(req.body?.email ?? ''),
        String(req.body?.password ?? ''),
        { ipAddress: req.ip || req.socket.remoteAddress },
      );
      return sendResponse(res, 200, 'Admin logged in successfully', result);
    } catch (error) {
      return next(error);
    }
  }

  overview = this.handle('Admin overview fetched successfully', () =>
    adminService.overview(),
  );

  health = this.handle('Admin health fetched successfully', () =>
    adminService.health(),
  );

  places = this.handle('Admin places fetched successfully', (req) =>
    adminService.listPlaces(listOptions(req)),
  );

  categories = this.handle('Admin categories fetched successfully', (req) =>
    adminService.listCategories(listOptions(req)),
  );

  schedules = this.handle('Admin schedules fetched successfully', (req) =>
    adminService.listSchedules(listOptions(req)),
  );

  activity = this.handle('Admin activity fetched successfully', (req) =>
    adminService.listActivity(listOptions(req)),
  );

  errors = this.handle('Admin errors fetched successfully', (req) =>
    adminService.listErrors(listOptions(req)),
  );

  requests = this.handle('Admin requests fetched successfully', (req) =>
    adminService.listRequests(listOptions(req)),
  );

  uploads = this.handle('Admin uploads fetched successfully', (req) =>
    adminService.listUploads(listOptions(req)),
  );

  users = this.handle('Admin users fetched successfully', (req) =>
    adminService.listUsers(listOptions(req)),
  );

  retentionPreview = this.handle(
    'Admin retention preview fetched successfully',
    () => retentionService.preview(),
  );

  runRetention = this.mutate(
    'Admin retention cleanup finished successfully',
    async (req) => {
      const result = await retentionService.run();
      await recordAdminEvent(req, {
        action: 'maintenance.retention.run',
        resourceType: 'maintenance',
        message: 'Admin ran retention cleanup',
        metadata: { deleted: result.deleted, policy: result.policy },
      });
      return result;
    },
  );

  checkImages = this.mutate(
    'Admin image health check finished successfully',
    async (req) => {
      const result = await adminImageHealthService.check({
        limit: numberQuery(req.query.limit),
        q: stringQuery(req.query.q),
      });
      await recordAdminEvent(req, {
        action: 'image.health.check',
        resourceType: 'image',
        message: 'Admin checked place image health',
        metadata: {
          total: result.total,
          ok: result.ok,
          broken: result.broken,
          missing: result.missing,
        },
      });
      return result;
    },
  );

  updatePlace = this.mutate('Admin place updated successfully', async (req) => {
    const place = await placeService.update(req.params.id as string, req.body);
    await recordAdminEvent(req, {
      action: 'place.update',
      resourceType: 'place',
      resourceId: place.id,
      message: `Admin updated place ${place.name}`,
      changedFields: Object.keys(req.body ?? {}),
    });
    return place;
  });

  deletePlace = this.mutate('Admin place deleted successfully', async (req) => {
    const deleted = await placeService.delete(req.params.id as string);
    await recordAdminEvent(req, {
      action: 'place.delete',
      resourceType: 'place',
      resourceId: deleted.id,
      message: `Admin deleted place ${deleted.id}`,
    });
    return deleted;
  });

  updateCategory = this.mutate(
    'Admin category updated successfully',
    async (req) => {
      const category = await categoryService.update(
        req.params.id as string,
        req.body,
      );
      await recordAdminEvent(req, {
        action: 'category.update',
        resourceType: 'category',
        resourceId: category.id,
        message: `Admin updated category ${category.name}`,
        changedFields: Object.keys(req.body ?? {}),
      });
      return category;
    },
  );

  deleteCategory = this.mutate(
    'Admin category deleted successfully',
    async (req) => {
      const deleted = await categoryService.delete(req.params.id as string);
      await recordAdminEvent(req, {
        action: 'category.delete',
        resourceType: 'category',
        resourceId: deleted.id,
        message: `Admin deleted category ${deleted.id}`,
      });
      return deleted;
    },
  );

  updateSchedule = this.mutate(
    'Admin schedule updated successfully',
    async (req) => {
      const schedule = await scheduleService.update(
        req.params.id as string,
        req.body,
      );
      await recordAdminEvent(req, {
        action: 'schedule.update',
        resourceType: 'schedule',
        resourceId: schedule.id,
        message: `Admin updated schedule ${schedule.id}`,
        changedFields: Object.keys(req.body ?? {}),
      });
      return schedule;
    },
  );

  deleteSchedule = this.mutate(
    'Admin schedule deleted successfully',
    async (req) => {
      const deleted = await scheduleService.delete(req.params.id as string);
      await recordAdminEvent(req, {
        action: 'schedule.delete',
        resourceType: 'schedule',
        resourceId: deleted.id,
        message: `Admin deleted schedule ${deleted.id}`,
      });
      return deleted;
    },
  );

  private handle<T>(
    message: string,
    load: (req: Request) => Promise<T>,
  ) {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const data = await load(req);
        return sendResponse(res, 200, message, data);
      } catch (error) {
        return next(error);
      }
    };
  }

  private mutate<T>(
    message: string,
    operation: (req: Request) => Promise<T>,
  ) {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const data = await operation(req);
        return sendResponse(res, 200, message, data);
      } catch (error) {
        return next(error);
      }
    };
  }
}

export const adminController = new AdminController();

function listOptions(req: Request): AdminListOptions {
  return {
    q: stringQuery(req.query.q),
    page: numberQuery(req.query.page),
    limit: numberQuery(req.query.limit),
    status: stringQuery(req.query.status),
    type: stringQuery(req.query.type),
    severity: stringQuery(req.query.severity),
    categoryId: stringQuery(req.query.categoryId),
    imageStatus: stringQuery(req.query.imageStatus),
    minRating: numberQuery(req.query.minRating),
    from: stringQuery(req.query.from),
    to: stringQuery(req.query.to),
  };
}

async function recordAdminEvent(
  req: Request,
  input: {
    action: string;
    resourceType: string;
    resourceId?: string;
    message: string;
    changedFields?: string[];
    metadata?: Record<string, unknown>;
  },
) {
  await observabilityService.recordSystemEvent({
    type: 'admin',
    action: input.action,
    resourceType: input.resourceType,
    resourceId: input.resourceId ?? null,
    message: input.message,
    deviceId: req.deviceId,
    requestId: req.requestId,
    metadata: {
      ...(input.metadata ?? {}),
      ...(input.changedFields ? { changedFields: input.changedFields } : {}),
    },
  });
}

function stringQuery(value: unknown) {
  return typeof value === 'string' ? value : undefined;
}

function numberQuery(value: unknown) {
  if (typeof value !== 'string') {
    return undefined;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}
