import { prisma } from '../../config/db';
import { PlaceCreateInput, PlaceUpdateInput } from './place.model';

export class PlaceRepository {
  findAll(categoryId?: string) {
    return prisma.place.findMany({
      where: categoryId ? { categoryId } : undefined,
      orderBy: { createdAt: 'desc' },
      include: { category: true },
    });
  }

  findById(id: string) {
    return prisma.place.findUnique({
      where: { id },
      include: { category: true, schedules: true },
    });
  }

  create(data: PlaceCreateInput) {
    return prisma.place.create({
      data,
      include: { category: true },
    });
  }

  update(id: string, data: PlaceUpdateInput) {
    return prisma.place.update({
      where: { id },
      data,
      include: { category: true },
    });
  }

  delete(id: string) {
    return prisma.place.delete({ where: { id } });
  }
}

export const placeRepository = new PlaceRepository();
