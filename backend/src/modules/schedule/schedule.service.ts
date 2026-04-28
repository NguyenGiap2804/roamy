import { NotFoundError } from '../../utils/errors';
import { placeRepository } from '../place/place.repository';
import { ScheduleCreateInput, ScheduleUpdateInput } from './schedule.model';
import { scheduleRepository } from './schedule.repository';

export class ScheduleService {
  findAll(date?: string) {
    return scheduleRepository.findAll(date);
  }

  async findById(id: string) {
    const schedule = await scheduleRepository.findById(id);
    if (!schedule) {
      throw new NotFoundError('Schedule not found');
    }
    return schedule;
  }

  async create(data: ScheduleCreateInput) {
    const place = await placeRepository.findById(data.placeId);
    if (!place) {
      throw new NotFoundError('Place not found');
    }
    return scheduleRepository.create(data);
  }

  async update(id: string, data: ScheduleUpdateInput) {
    await this.findById(id);

    if (data.placeId) {
      const place = await placeRepository.findById(data.placeId);
      if (!place) {
        throw new NotFoundError('Place not found');
      }
    }

    return scheduleRepository.update(id, data);
  }

  async delete(id: string) {
    await this.findById(id);
    await scheduleRepository.delete(id);
    return { id };
  }
}

export const scheduleService = new ScheduleService();
