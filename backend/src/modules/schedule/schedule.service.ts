import { NotFoundError } from '../../utils/errors';
import { placeRepository } from '../place/place.repository';
import { ScheduleCreateInput, ScheduleUpdateInput } from './schedule.model';
import { scheduleRepository } from './schedule.repository';

export class ScheduleService {
  findAll(userId: string, date?: string) {
    return scheduleRepository.findAll(userId, date);
  }

  async findById(id: string, userId?: string) {
    const schedule = await scheduleRepository.findById(id, userId);
    if (!schedule) {
      throw new NotFoundError('Schedule not found');
    }
    return schedule;
  }

  async create(userId: string, data: ScheduleCreateInput) {
    const place = await placeRepository.findById(data.placeId, userId);
    if (!place) {
      throw new NotFoundError('Place not found');
    }
    return scheduleRepository.create(userId, data);
  }

  async update(id: string, data: ScheduleUpdateInput, userId?: string) {
    const current = await this.findById(id, userId);

    if (data.placeId) {
      const place = await placeRepository.findById(data.placeId, current.userId);
      if (!place) {
        throw new NotFoundError('Place not found');
      }
    }

    return scheduleRepository.update(id, data);
  }

  async delete(id: string, userId?: string) {
    await this.findById(id, userId);
    await scheduleRepository.delete(id);
    return { id };
  }
}

export const scheduleService = new ScheduleService();
