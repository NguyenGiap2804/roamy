import { NextFunction, Request, Response } from 'express';

import { loginAdmin } from './admin.auth';
import { adminService, AdminListOptions } from './admin.service';
import { sendResponse } from '../../utils/response';

export class AdminController {
  login(req: Request, res: Response, next: NextFunction) {
    try {
      const result = loginAdmin(String(req.body?.email ?? ''), String(req.body?.password ?? ''));
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
}

export const adminController = new AdminController();

function listOptions(req: Request): AdminListOptions {
  return {
    q: stringQuery(req.query.q),
    page: numberQuery(req.query.page),
    limit: numberQuery(req.query.limit),
    status: stringQuery(req.query.status),
    type: stringQuery(req.query.type),
  };
}

function stringQuery(value: unknown) {
  return typeof value === 'string' ? value : undefined;
}

function numberQuery(value: unknown) {
  return typeof value === 'string' ? Number(value) : undefined;
}
