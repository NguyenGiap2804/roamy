import { prisma } from '../../config/db';
import { CategoryCreateInput, CategoryUpdateInput } from './category.model';

export class CategoryRepository {
  findAll() {
    return prisma.category.findMany({
      orderBy: { createdAt: 'asc' },
      include: {
        _count: {
          select: { places: true },
        },
      },
    });
  }

  findByName(name: string) {
    return prisma.category.findFirst({
      where: {
        name: {
          equals: name,
          mode: 'insensitive',
        },
      },
    });
  }

  findById(id: string) {
    return prisma.category.findUnique({
      where: { id },
      include: {
        _count: {
          select: { places: true },
        },
      },
    });
  }

  create(data: CategoryCreateInput) {
    return prisma.category.create({ data });
  }

  update(id: string, data: CategoryUpdateInput) {
    return prisma.category.update({
      where: { id },
      data,
      include: {
        _count: {
          select: { places: true },
        },
      },
    });
  }

  delete(id: string) {
    return prisma.category.delete({ where: { id } });
  }
}

export const categoryRepository = new CategoryRepository();
