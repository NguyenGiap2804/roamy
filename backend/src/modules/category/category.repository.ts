import { prisma } from '../../config/db';
import { CategoryCreateInput } from './category.model';

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

  create(data: CategoryCreateInput) {
    return prisma.category.create({ data });
  }
}

export const categoryRepository = new CategoryRepository();
