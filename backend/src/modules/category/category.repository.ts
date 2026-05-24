import { prisma } from '../../config/db';
import { CategoryCreateInput, CategoryUpdateInput } from './category.model';

export class CategoryRepository {
  findAll(userId?: string) {
    return prisma.category.findMany({
      where: userId ? { userId } : undefined,
      orderBy: { createdAt: 'asc' },
      include: {
        _count: {
          select: { places: true },
        },
      },
    });
  }

  findByName(name: string, userId?: string) {
    return prisma.category.findFirst({
      where: {
        ...(userId ? { userId } : {}),
        name: {
          equals: name,
          mode: 'insensitive',
        },
      },
    });
  }

  findById(id: string, userId?: string) {
    return userId ? prisma.category.findFirst({
      where: { id, userId },
      include: {
        _count: {
          select: { places: true },
        },
      },
    }) : prisma.category.findUnique({
      where: { id },
      include: {
        _count: {
          select: { places: true },
        },
      },
    });
  }

  create(userId: string, data: CategoryCreateInput) {
    return prisma.category.create({ data: { ...data, userId } });
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
