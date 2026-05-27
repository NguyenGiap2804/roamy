import { NotFoundError, ValidationError } from '../../utils/errors';
import { placeRepository } from '../place/place.repository';
import { ScheduleCreateInput, ScheduleUpdateInput } from './schedule.model';
import { scheduleRepository } from './schedule.repository';

export class ScheduleService {
  constructor(
    private readonly schedules = scheduleRepository,
    private readonly places = placeRepository,
  ) {}

  findAll(userId: string, date?: string) {
    return this.schedules.findAll(userId, date);
  }

  async findById(id: string, userId?: string) {
    const schedule = await this.schedules.findById(id, userId);
    if (!schedule) {
      throw new NotFoundError('Schedule not found');
    }
    return schedule;
  }

  async create(userId: string, data: ScheduleCreateInput) {
    if (data.placeId) {
      const place = await this.places.findById(data.placeId, userId);
      if (!place) {
        throw new NotFoundError('Place not found');
      }
    } else {
      this.ensureQuickScheduleFields(data.title, data.mapsUrl);
    }
    return this.schedules.create(userId, data);
  }

  async update(id: string, data: ScheduleUpdateInput, userId?: string) {
    const current = await this.findById(id, userId);

    if (data.placeId) {
      const place = await this.places.findById(data.placeId, current.userId);
      if (!place) {
        throw new NotFoundError('Place not found');
      }
    }

    const finalPlaceId = data.placeId === undefined ? current.placeId : data.placeId;
    const finalTitle = data.title === undefined ? current.title : data.title;
    const finalMapsUrl = data.mapsUrl === undefined ? current.mapsUrl : data.mapsUrl;
    if (!finalPlaceId) {
      this.ensureQuickScheduleFields(finalTitle, finalMapsUrl);
    }

    return this.schedules.update(id, data);
  }

  async delete(id: string, userId?: string) {
    await this.findById(id, userId);
    await this.schedules.delete(id);
    return { id };
  }

  private ensureQuickScheduleFields(title?: string | null, mapsUrl?: string | null) {
    if (title?.trim() && mapsUrl?.trim()) return;
    throw new ValidationError('Quick schedule requires title and Google Maps link');
  }
}

export const scheduleService = new ScheduleService();
