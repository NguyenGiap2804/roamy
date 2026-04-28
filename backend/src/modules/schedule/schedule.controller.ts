import { NextFunction, Request, Response } from 'express';

import { sendResponse } from '../../utils/response';
import { scheduleService } from './schedule.service';

export class ScheduleController {
  async findAll(req: Request, res: Response, next: NextFunction) {
    try {
      const date = typeof req.query.date === 'string' ? req.query.date : undefined;
      const schedules = await scheduleService.findAll(date);
      return sendResponse(res, 200, 'Schedules fetched successfully', schedules);
    } catch (error) {
      return next(error);
    }
  }

  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const schedule = await scheduleService.create(req.body);
      return sendResponse(res, 201, 'Schedule created successfully', schedule);
    } catch (error) {
      return next(error);
    }
  }

  async update(req: Request, res: Response, next: NextFunction) {
    try {
      const schedule = await scheduleService.update(req.params.id as string, req.body);
      return sendResponse(res, 200, 'Schedule updated successfully', schedule);
    } catch (error) {
      return next(error);
    }
  }

  async delete(req: Request, res: Response, next: NextFunction) {
    try {
      const deleted = await scheduleService.delete(req.params.id as string);
      return sendResponse(res, 200, 'Schedule deleted successfully', deleted);
    } catch (error) {
      return next(error);
    }
  }
}

export const scheduleController = new ScheduleController();
