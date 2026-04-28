import { NotFoundError } from '../../utils/errors';
import { PlaceCreateInput, PlaceUpdateInput } from './place.model';
import { placeRepository } from './place.repository';

export class PlaceService {
  findAll(categoryId?: string) {
    return placeRepository.findAll(categoryId);
  }

  async findById(id: string) {
    const place = await placeRepository.findById(id);
    if (!place) {
      throw new NotFoundError('Place not found');
    }
    return place;
  }

  create(data: PlaceCreateInput) {
    return placeRepository.create(data);
  }

  async update(id: string, data: PlaceUpdateInput) {
    await this.findById(id);
    return placeRepository.update(id, data);
  }

  async delete(id: string) {
    await this.findById(id);
    await placeRepository.delete(id);
    return { id };
  }
}

export const placeService = new PlaceService();
