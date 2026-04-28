import { categoryRepository } from './category.repository';
import { CategoryCreateInput } from './category.model';

export class CategoryService {
  findAll() {
    return categoryRepository.findAll();
  }

  create(data: CategoryCreateInput) {
    return categoryRepository.create(data);
  }
}

export const categoryService = new CategoryService();
