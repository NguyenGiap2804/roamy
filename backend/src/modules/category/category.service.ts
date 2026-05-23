import { Prisma } from '@prisma/client';

import { ConflictError, NotFoundError } from '../../utils/errors';
import { categoryRepository, CategoryRepository } from './category.repository';
import { CategoryCreateInput, CategoryUpdateInput } from './category.model';

export class CategoryService {
  constructor(
    private readonly repository: Pick<
      CategoryRepository,
      'findAll' | 'findByName' | 'findById' | 'create' | 'update' | 'delete'
    > = categoryRepository,
  ) {}

  findAll() {
    return this.repository.findAll();
  }

  async create(data: CategoryCreateInput) {
    const existingCategory = await this.repository.findByName(data.name);
    if (existingCategory) {
      throw new ConflictError(_duplicateCategoryMessage(existingCategory.name));
    }

    try {
      return await this.repository.create(data);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictError(_duplicateCategoryMessage(data.name));
      }

      throw error;
    }
  }

  async update(id: string, data: CategoryUpdateInput) {
    const current = await this.repository.findById(id);
    if (!current) {
      throw new NotFoundError('Category not found');
    }

    if (data.name && data.name.toLowerCase() !== current.name.toLowerCase()) {
      const existingCategory = await this.repository.findByName(data.name);
      if (existingCategory && existingCategory.id !== id) {
        throw new ConflictError(_duplicateCategoryMessage(existingCategory.name));
      }
    }

    try {
      return await this.repository.update(id, data);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictError(
          _duplicateCategoryMessage(data.name ?? current.name),
        );
      }

      throw error;
    }
  }

  async delete(id: string) {
    const current = await this.repository.findById(id);
    if (!current) {
      throw new NotFoundError('Category not found');
    }

    if (current._count.places > 0) {
      throw new ConflictError(
        `Danh mục "${current.name}" còn ${current._count.places} địa điểm, không thể xóa`,
        { placeCount: current._count.places },
      );
    }

    await this.repository.delete(id);
    return { id };
  }
}

export const categoryService = new CategoryService();

function _duplicateCategoryMessage(name: string) {
  return `Danh mục "${name}" đã tồn tại`;
}
